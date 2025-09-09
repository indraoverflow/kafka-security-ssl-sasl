#!/usr/bin/env bash
set -e

echo "Current working dir : ${PWD}"
echo "======================================="
export TARGET_CONFIG=docker-compose-scram.yml
export KAFKA_SSL_SECRETS_DIR=$PWD/secrets
export KAFKA_SASL_SCRAM_SECRETS_DIR=$PWD/sasl-scram/secrets
export KAFKA_SASL_SCRAM_CONFIG_DIR=$PWD/sasl-scram/config
export JMX_EXPORTER=$PWD/sasl-scram/jmx_exporter
echo "KAFKA TARGET CONF   : ${TARGET_CONFIG}"
echo "KAFKA SSL SECRET    : ${KAFKA_SSL_SECRETS_DIR}"
echo "KAFKA SASL SECRET   : ${KAFKA_SASL_SCRAM_SECRETS_DIR}"
echo "KAFKA JMX EXPORTER  : ${JMX_EXPORTER}"
echo "======================================="

cd "$PWD/sasl-scram/"

# =======================================
# Kill any process using known Kafka ports
# =======================================
echo "Cleaning used ports"
for port in 19092 19093 19094 19095 19096 9092 9093 9101 9102 9103 9581 9582 9583; do
  pid=$(lsof -t -i:$port 2>/dev/null || true)
  if [ -n "$pid" ]; then
    echo "Killing PID $pid using port $port"
    kill -9 "$pid" 2>/dev/null || echo "PID $pid already gone"
  fi
done

sleep 2

# =======================================
# Full cleanup of message-broker group
# =======================================
echo "Cleaning up message-broker project"
docker-compose -p message-broker -f "${TARGET_CONFIG}" down --volumes --remove-orphans || true
docker ps -aq --filter "name=message-broker" | xargs -r docker rm -f || true
docker volume ls -q --filter "name=message-broker" | xargs -r docker volume rm || true
docker network ls -q --filter "name=message-broker" | xargs -r docker network rm || true

sleep 2

# =======================================
# Generate SAN-enabled SSL certificates & truststores
# =======================================
echo "Generating SAN-enabled SSL certificates..."
BROKERS=(1 2 3)
BROKER_HOSTS=(kafka-broker-1 kafka-broker-2 kafka-broker-3)
BROKER_IPS=(172.22.0.3 172.22.0.4 172.22.0.5)  # Replace with actual Docker IPs if needed

# Remove old directories
for broker in "${BROKERS[@]}"; do
  rm -rf $KAFKA_SSL_SECRETS_DIR/broker-$broker
done

# Step 1: Create keystore + export cert with SANs
for i in ${!BROKERS[@]}; do
  broker_id=${BROKERS[$i]}
  broker_host=${BROKER_HOSTS[$i]}
  broker_ip=${BROKER_IPS[$i]}
  BROKER_DIR=$KAFKA_SSL_SECRETS_DIR/broker-$broker_id
  mkdir -p $BROKER_DIR

  KEYSTORE=$BROKER_DIR/kafka.broker-$broker_id.keystore.jks
  CERT=$BROKER_DIR/broker-$broker_id.cer
  KEY_CREDS=$BROKER_DIR/broker-${broker_id}_sslkey_creds
  STORE_CREDS=$BROKER_DIR/broker-${broker_id}_keystore_creds

  # Generate keypair with SAN
  keytool -genkeypair -alias broker-$broker_id -keyalg RSA -keysize 2048 \
    -dname "CN=$broker_host" \
    -ext "SAN=dns:$broker_host,dns:localhost,ip:$broker_ip" \
    -keystore $KEYSTORE -storepass confluent -keypass confluent -validity 3650

  # Export certificate
  keytool -export -alias broker-$broker_id -keystore $KEYSTORE -storepass confluent -file $CERT

  # Create credential files
  echo "confluent" > $KEY_CREDS
  echo "confluent" > $STORE_CREDS
done

# Step 2: Create truststores containing all broker certs
for broker_id in "${BROKERS[@]}"; do
  BROKER_DIR=$KAFKA_SSL_SECRETS_DIR/broker-$broker_id
  TRUSTSTORE=$BROKER_DIR/kafka.broker-$broker_id.truststore.jks
  TRUST_CREDS=$BROKER_DIR/broker-${broker_id}_truststore_creds

  rm -f $TRUSTSTORE $TRUST_CREDS
  echo "confluent" > $TRUST_CREDS

  # Import all broker certs
  for import_id in "${BROKERS[@]}"; do
    CERT_FILE=$KAFKA_SSL_SECRETS_DIR/broker-$import_id/broker-$import_id.cer
    keytool -import -noprompt -alias broker-$import_id -file $CERT_FILE \
      -keystore $TRUSTSTORE -storepass confluent
  done
done

# Fix permissions for creds
for broker_id in "${BROKERS[@]}"; do
  chmod 400 $KAFKA_SSL_SECRETS_DIR/broker-$broker_id/*_creds
done

sleep 2

# =======================================
# Start fresh
# =======================================
echo "Starting Service Group"
docker-compose -p "message-broker" -f "${TARGET_CONFIG}" up -d --remove-orphans --build
sleep 5

# =======================================
# Format Kafka Storage (KRaft)
# =======================================
echo "Formatting Kafka Storage"
for broker_id in "${BROKERS[@]}"; do
  echo "Formatting broker $broker_id"
  docker exec "kafka-broker-$broker_id" rm -rf /var/lib/kafka/data/*
  docker exec "kafka-broker-$broker_id" kafka-storage format \
    --config /etc/kafka/kafka.properties \
    --cluster-id xwKCEeWJToei3os4N3JYfQ \
    --ignore-formatted || echo "Broker $broker_id already formatted"
  # docker exec -it "kafka-broker-$broker_id" cat /var/lib/kafka/data/meta.properties
done

sleep 2

# =======================================
# Patch configs to allow everyone if no ACLs
# =======================================
echo "Patching broker configs to allow everyone if no ACL found (for clean cluster start)"
for broker_config in kafka-broker-1.properties kafka-broker-2.properties kafka-broker-3.properties; do
  if grep -q "allow.everyone.if.no.acl.found=" $broker_config; then
    sed -i 's/allow.everyone.if.no.acl.found=false/allow.everyone.if.no.acl.found=true/' $broker_config
  else
    echo "allow.everyone.if.no.acl.found=true" >> $broker_config
  fi
done

# =======================================
# JMX Preparation
# =======================================
echo "JMX Preparation"
for broker_id in "${BROKERS[@]}"; do
  docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.kafka.yml "kafka-broker-$broker_id":/etc/kafka/secrets/ || true
  docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar "kafka-broker-$broker_id":/etc/kafka/secrets/ || true
done

echo "✅ Done."
