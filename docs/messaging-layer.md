# Messaging Layer: Redpanda

## Why Redpanda

The demo needs a real Kafka-compatible messaging layer to showcase Airflow 3 Assets and event-driven scheduling as actual features. Redpanda is a single-binary, Kafka-compatible broker.

| Criterion | Redpanda | Apache Kafka |
|---|---|---|
| Containers needed | 1 | 2-3 (broker + ZooKeeper/KRaft) |
| Startup time | ~2 seconds | ~30 seconds |
| RAM footprint | ~150MB | ~1GB+ |
| Kafka protocol compatible | Yes (drop-in) | It *is* Kafka |
| Airflow Kafka provider works | Yes, unchanged | Yes |
| 4-day timeline risk | Low | Medium |

Redpanda speaks the real Kafka protocol. Airflow's `KafkaMessageQueueTrigger` connects to it with zero code changes — the demo shows a real Kafka integration, not a mock.

## Kafka Topic

- **Topic name**: `zoom-status`
- **Message format**: JSON
  ```json
  {"status": "in_meeting", "timestamp": "2026-03-21T10:30:00Z"}
  {"status": "available", "timestamp": "2026-03-21T11:00:00Z"}
  ```

## Airflow Integration

The Airflow Kafka provider (`apache-airflow-providers-apache-kafka`) works against Redpanda out of the box. The connection (`kafka_default`) just points to the Redpanda broker address.

### DAG Pattern: Asset + AssetWatcher + KafkaMessageQueueTrigger

```python
from airflow.providers.apache.kafka.triggers.msg_queue import KafkaMessageQueueTrigger
from airflow.sdk import DAG, Asset, AssetWatcher

trigger = KafkaMessageQueueTrigger(
    topics=["zoom-status"],
    apply_function="dags.led_sign_dag.process_zoom_message",
    kafka_config_id="kafka_default",
    poll_timeout=1,
    poll_interval=5,
)

asset = Asset(
    "zoom-meeting-status",
    watchers=[AssetWatcher(name="zoom-status-watcher", trigger=trigger)],
)

with DAG(dag_id="led_sign_update", schedule=[asset]) as dag:
    # tasks here
    ...
```

This is the core Airflow 3 feature being demoed: the triggerer runs the `KafkaMessageQueueTrigger` continuously, and when a message arrives, the asset is updated, which triggers the DAG — no cron, no sensor polling in the DAG itself.
