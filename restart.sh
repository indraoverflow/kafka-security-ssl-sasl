#!/usr/bin/env bash
set -e

echo "Current working dir : ${PWD}"
echo "======================================="
export TARGET_CONFIG=$PWD/sasl-scram/docker-compose-scram.yml
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
# Just reload compose config
# =======================================
echo "Reloading docker compose configuration (no cleanup)"
docker volume rm message-broker_kafka-broker-1-data || true
docker volume rm message-broker_kafka-broker-2-data || true
docker volume rm message-broker_kafka-broker-3-data || true
docker compose -p "message-broker" -f "${TARGET_CONFIG}" down -v
docker compose -p "message-broker" -f "${TARGET_CONFIG}" up -d --force-recreate --remove-orphans

docker exec -it kafka-broker-1 kafka-configs \
  --bootstrap-server kafka-broker-1:29092 \
  --alter \
  --add-config 'SCRAM-SHA-512=[password=confluent]' \
  --entity-type users \
  --entity-name kafkabroker

docker exec -it kafka-broker-1 kafka-configs \
  --bootstrap-server kafka-broker-1:29092 \
  --describe \
  --entity-type users \
  --entity-name kafkabroker

echo "✅ Config reload done (no data, network, or volumes touched)."

echo "Waiting for containers to become healthy..."

# Loop until all containers are healthy
while true; do
  clear
  echo "=== Docker Container Health Status ==="
  docker ps --format "table {{.Names}}\t{{.Status}}"

  # Check if there are any containers that are not healthy yet
  unhealthy=$(docker ps --format '{{.Names}} {{.Status}}' | grep -v 'healthy' | grep -v 'Up')

  if [ -z "$unhealthy" ]; then
    echo -e "\n✅ All containers are healthy!"
    break
  fi

  sleep 5
done
