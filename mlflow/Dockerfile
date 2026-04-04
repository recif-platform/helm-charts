FROM ghcr.io/mlflow/mlflow:v3.10.0

# Pre-install PostgreSQL driver so startup doesn't depend on pip install.
RUN pip install --no-cache-dir psycopg2-binary
