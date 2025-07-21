#!/bin/bash

# Query 1: All Jenkins Workers logs
# Description: Shows all logs from Jenkins workers namespace

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🔍 Query 1: All Jenkins Workers logs"
echo "======================================"
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{kubernetes_namespace_name="jenkins-workers"}'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "🔍 What this shows:"
echo "   - All logs from jenkins-workers namespace"
echo "   - Worker pod creation and lifecycle events"
echo "   - General worker activity"
