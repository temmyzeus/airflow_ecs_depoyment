ARG BASE_AIRFLOW_IMAGE=apache/airflow:3.3.0
ARG BUILDPLATFORM=linux/amd64
# Pin the image cpu variant of airflow image, regardless of build machine cpu architecture.
FROM --platform=${BUILDPLATFORM} ${BASE_AIRFLOW_IMAGE} AS airflow_base

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
        nano \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER airflow

COPY --chown=airflow:root ./requirements.txt /requirements.txt

RUN pip install --no-cache-dir -r /requirements.txt --constraint "${HOME}/constraints.txt"

COPY --chown=airflow:root ./plugins $AIRFLOW_HOME/plugins
COPY --chown=airflow:root ./dags $AIRFLOW_HOME/dags
COPY --chown=airflow:root ./logs $AIRFLOW_HOME/logs
COPY --chown=airflow:root ./config $AIRFLOW_HOME/config

RUN echo "Airflow Python Version: ${AIRFLOW_PYTHON_VERSION}"
