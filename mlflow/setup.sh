#!/bin/bash
set -e
echo "Deploying MLflow server..."
kubectl apply -f deployment.yaml
echo "Waiting for MLflow pod..."
kubectl wait --for=condition=ready pod -l app=mlflow -n mlflow-system --timeout=120s
echo "MLflow deployed. Port-forward with:"
echo "  kubectl port-forward svc/mlflow 5000:5000 -n mlflow-system"
