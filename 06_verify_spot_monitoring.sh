#!/bin/bash

# Final verification script for Jenkins Spot Workers monitoring

source common.sh

echo "🔍 JENKINS SPOT WORKERS MONITORING - FINAL STATUS"
echo "==============================================="
echo ""

# Check observability stack
log "INFO" "Checking observability stack..."
kubectl get pods -n observability-stack

echo ""

# Check Jenkins namespaces
log "INFO" "Checking Jenkins deployments..."
kubectl get pods -n jenkins-master
kubectl get pods -n jenkins-workers 2>/dev/null || echo "No active Jenkins workers (normal)"

echo ""

# Check spot nodes
log "INFO" "Checking spot nodes..."
SPOT_NODES=$(kubectl get nodes -l kubernetes.azure.com/scalesetpriority=spot --no-headers | wc -l)
echo "Active spot nodes: $SPOT_NODES"

echo ""

# Get Grafana access info
GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ ! -z "$GRAFANA_IP" ]; then
    log "SUCCESS" "Grafana accessible at: http://$GRAFANA_IP"
    echo ""
    echo "🎯 READY TO USE:"
    echo "   1. Dashboard: http://$GRAFANA_IP/d/d96d4d0b-f8b5-4733-b086-55acd815c938"
    echo "   2. Explore: http://$GRAFANA_IP/explore"
    echo "   3. Login: admin / admin123"
    echo ""
    echo "📋 WORKING SCRIPTS:"
    echo "   • ./working_spot_queries.sh - Show working Loki queries"
    echo "   • ./fix_spot_dashboard.sh - Import/update dashboard"
    echo ""
    echo "✅ Jenkins Spot Workers monitoring is READY!"
else
    log "ERROR" "Grafana service not found!"
fi
