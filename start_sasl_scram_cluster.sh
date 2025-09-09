#!/usr/bin/env bash
echo "Current working dir : ${PWD}"
echo "======================================="
export KAFKA_SSL_SECRETS_DIR=$PWD/secrets
export KAFKA_SASL_SCRAM_SECRETS_DIR=$PWD/sasl-scram/secrets
export KAFKA_SASL_SCRAM_CONFIG_DIR=$PWD/sasl-scram/config
export JMX_EXPORTER=$PWD/sasl-scram/jmx_exporter
echo "KAFKA SSL SECRET    : ${KAFKA_SSL_SECRETS_DIR}"
echo "KAFKA SASL SECRET   : ${KAFKA_SASL_SCRAM_SECRETS_DIR}"
echo "KAFKA JMX EXPORTER  : ${JMX_EXPORTER}"
echo "======================================="
cd $PWD/sasl-scram/

echo "Cleaning used ports"
for port in 19094 19095 19096 9093 9101 9102 9103 19084 29084 39084 8080 8081; do
  pid=$(lsof -t -i:$port 2>/dev/null)
  [ -n "$pid" ] && echo "Killing PID $pid using port $port" && kill -9 $pid
done


sleep 2

echo "Starting Service Group"
docker-compose -p "message-broker" -f docker-compose-scram.yml up -d --remove-orphans
sleep 2

echo "Formatting Kafka Storage"
docker exec kafka-broker-1 kafka-storage format --config /etc/kafka/kafka.properties --cluster-id i_rM8ni4Q6K2ZmYYDDtPRA --ignore-formatted
docker exec kafka-broker-2 kafka-storage format --config /etc/kafka/kafka.properties --cluster-id i_rM8ni4Q6K2ZmYYDDtPRA --ignore-formatted
docker exec kafka-broker-3 kafka-storage format --config /etc/kafka/kafka.properties --cluster-id i_rM8ni4Q6K2ZmYYDDtPRA --ignore-formatted
sleep 2

echo "JMX Preparation"
# docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.zookeeper.yml $(docker ps -aqf "name=zookeeper-1"):/etc/kafka/secrets/
# docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.zookeeper.yml $(docker ps -aqf "name=zookeeper-2"):/etc/kafka/secrets/
# docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.zookeeper.yml $(docker ps -aqf "name=zookeeper-3"):/etc/kafka/secrets/

# docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar $(docker ps -aqf "name=zookeeper-1"):/etc/kafka/secrets/
# docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar $(docker ps -aqf "name=zookeeper-2"):/etc/kafka/secrets/
# docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar $(docker ps -aqf "name=zookeeper-3"):/etc/kafka/secrets/

docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.kafka.yml $(docker ps -aqf "name=kafka-broker-1"):/etc/kafka/secrets/
docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.kafka.yml $(docker ps -aqf "name=kafka-broker-2"):/etc/kafka/secrets/
docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx.kafka.yml $(docker ps -aqf "name=kafka-broker-3"):/etc/kafka/secrets/

docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar $(docker ps -aqf "name=kafka-broker-1"):/etc/kafka/secrets/
docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar $(docker ps -aqf "name=kafka-broker-2"):/etc/kafka/secrets/
docker cp ~/grafana/kafka/kafka-security-ssl-sasl/sasl-scram/secrets/jmx_prometheus_javaagent-0.20.0.jar $(docker ps -aqf "name=kafka-broker-3"):/etc/kafka/secrets/

echo "Done"
