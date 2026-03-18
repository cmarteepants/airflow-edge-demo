FROM apache/airflow:3.1.8

RUN pip install --no-cache-dir \
    apache-airflow-providers-edge3==3.2.0 \
    apache-airflow-providers-apache-kafka==1.13.0
