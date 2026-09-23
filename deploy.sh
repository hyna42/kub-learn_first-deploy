#!/bin/bash
set -e

k3d cluster create app-cluster --servers=1 --agents=2
kubectl apply -f demo-app.yaml
