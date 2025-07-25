#!/bin/bash

# 05_install_observability.sh - Jenkins Spot Workers Monitoring
# Complete observability stack with Fluent Bit + Loki + Grafana

source .env.production
source common.sh

echo "STEP 5: JENKINS SPOT WORKERS OBSERVABILITY"
echo "=========================================="
echo ""

log "INFO" "Installing observability stack for Jenkins spot monitoring..."

# Create namespace
kubectl create namespace observability-stack --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
log "INFO" "Adding Helm repositories..."
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1
helm repo add fluent https://fluent.github.io/helm-charts >/dev/null 2>&1
helm repo update >/dev/null 2>&1

# Install Loki
log "INFO" "Installing Loki (log storage)..."
helm upgrade --install loki grafana/loki \
  --namespace observability-stack \
  --values helm/loki_helm_values.yaml \
  --wait

# Install Fluent Bit
log "INFO" "Installing Fluent Bit (log collection)..."
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace observability-stack \
  --values helm/fluent_bit_helm_values.yaml \
  --wait

# Install Grafana
log "INFO" "Installing Grafana (visualization)..."
helm upgrade --install grafana grafana/grafana \
  --namespace observability-stack \
  --values helm/grafana_helm_values.yaml \
  --wait

# Wait for components
log "INFO" "Waiting for components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n observability-stack --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=fluent-bit -n observability-stack --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n observability-stack --timeout=120s

# Get Grafana IP
GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
log "SUCCESS" "Observability stack installed successfully!"
echo ""
echo "📊 GRAFANA ACCESS:"
echo "   URL: http://$GRAFANA_IP"
echo "   User: admin"
echo "   Password: admin123"
echo ""
echo "🔧 NEXT STEPS:"
echo "   1. Run: ./07_install_prometheus_monitoring.sh"
echo "   2. Run: ./create_working_dashboard.sh"
echo "   3. Run: ./create_jenkins_alerts.sh"
echo "   4. Access Grafana to monitor Jenkins spot workers"
echo ""
echo "✅ Ready to monitor Jenkins workers on spot nodes!"
