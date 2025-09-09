#!/bin/bash
# ---------------------------
# Configuration
# ---------------------------
BROKERS=("kafka-broker-1" "kafka-broker-2" "kafka-broker-3")
BROKER_PORT=9092
COMMAND_CONFIG="/etc/kafka/secrets/conf/client.properties"
ALERT_WEBHOOK="http://bisa-diubah-ke-url-smsgw"
RETRY_INTERVAL=5  # seconds

# ---------------------------
# Functions
# ---------------------------
clear_screen() {
    clear
}

print_status_table() {
    printf "%-20s %-10s\n" "BROKER" "STATUS"
    printf "%-20s %-10s\n" "------" "------"
    for broker in "${BROKERS[@]}"; do
        if docker exec "$broker" kafka-broker-api-versions --bootstrap-server "${broker}:${BROKER_PORT}" --command-config "$COMMAND_CONFIG" >/dev/null 2>&1; then
            status="HEALTHY"
        else
            status="UNHEALTHY"
        fi
        printf "%-20s %-10s\n" "$broker" "$status"
    done
}

send_alert() {
    local broker=$1
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"text\": \"Kafka broker $broker is UNHEALTHY!\"}" \
            "$ALERT_WEBHOOK"
    fi
}

check_health() {
    all_healthy=true
    for broker in "${BROKERS[@]}"; do
        if ! docker exec "$broker" kafka-broker-api-versions --bootstrap-server "${broker}:${BROKER_PORT}" --command-config "$COMMAND_CONFIG" >/dev/null 2>&1; then
            all_healthy=false
            send_alert "$broker"
        fi
    done
    if [ "$all_healthy" = true ]; then
        return 0
    else
        return 1
    fi
}

# ---------------------------
# Main Execution
# ---------------------------
while true; do
    clear_screen
    print_status_table
    if check_health; then
        echo -e "\nAll Kafka brokers are healthy."
        exit 0
    else
        echo -e "\nSome brokers are unhealthy. Retrying in $RETRY_INTERVAL seconds..."
        sleep $RETRY_INTERVAL
    fi
done
