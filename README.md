# Kafka Broker Health Check Script

This repository contains scripts and configuration files for monitoring a Kafka cluster with SSL/SASL-SCRAM authentication.

Repository ini berisi skrip dan konfigurasi untuk monitoring cluster Kafka dengan autentikasi SSL/SASL-SCRAM.

## Health Check Script / Skrip Pengecekan Kesehatan

The main script, [`check_health_service.sh`](check_health_service.sh), monitors the health of Kafka brokers in the cluster.

Skrip utama, [`check_health_service.sh`](check_health_service.sh), digunakan untuk memonitor status broker Kafka di cluster.

### Features / Fitur

- Checks the health of Kafka brokers using `kafka-broker-api-versions`.
- Displays broker status in a table.
- Sends alerts via a webhook if any broker is unhealthy.
- Retries health checks at configurable intervals.

- Mengecek status broker Kafka menggunakan `kafka-broker-api-versions`.
- Menampilkan status broker dalam bentuk tabel.
- Mengirim alert via webhook jika ada broker yang tidak sehat.
- Melakukan retry pengecekan pada interval yang dapat dikonfigurasi.

### Usage / Cara Penggunaan

```sh
bash check_health_service.sh
```

### Configuration / Konfigurasi

- **BROKERS**: List of broker container names / Daftar nama container broker.
- **BROKER_PORT**: Kafka broker port (default: 9092) / Port broker Kafka (default: 9092).
- **COMMAND_CONFIG**: Path to Kafka client properties file / Path ke file properti client Kafka.
- **ALERT_WEBHOOK**: URL for alert notifications / URL untuk notifikasi alert.
- **RETRY_INTERVAL**: Interval (in seconds) between health checks / Interval (detik) antar pengecekan.

Edit these variables in [`check_health_service.sh`](check_health_service.sh) as needed.  
Edit variabel di [`check_health_service.sh`](check_health_service.sh) sesuai kebutuhan.

## Important Note / Catatan Penting

Sample env for kafka cluster with SSL SASL (should represent preprod and prod, 3 brokers, 3 zookeepers, extra 1 schema registry).  
**Note:** Do not update the image because Docker will switch to Kraft Mode, which is not suitable for current conditions and exporter variables will change a lot (Kafka v4 variables have many changes).

Berikut sample env untuk kafka cluster dengan SSL SASL (Harusnya sudah mewakili preprod dan prod, 3 broker, 3 zookeeper, extra 1 schema registry).  
**Catatan:** Jangan update image karena docker akan arahkan jadi Kraft Mode yang tidak sesuai dengan kondisi sekarang dan variable exporter-nya banyak berubah (variable Kafka v4 banyak perubahan).

## Related Files / File Terkait

- [`sasl-scram/docker-compose-scram.yml`](sasl-scram/docker-compose-scram.yml): Docker Compose configuration for the Kafka cluster / Konfigurasi Docker Compose untuk cluster Kafka.
- [`sasl-scram/add_kafka_accounts_in_zookeeper.sh`](sasl-scram/add_kafka_accounts_in_zookeeper.sh): Script for managing Kafka accounts in Zookeeper / Skrip untuk manajemen akun Kafka di Zookeeper.
- [`sasl-scram/kafka-consumers-producers.sh`](sasl-scram/kafka-consumers-producers.sh): Example producer/consumer commands / Contoh perintah producer/consumer.