#!/bin/bash

# Query 2: Jenkins Workers on spot nodes
# Description: Shows logs from workers specifically running on spot nodes

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🎯 Query 2: Jenkins Workers on spot nodes"
echo "=========================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{kubernetes_namespace_name="jenkins-workers"} |= "spot"'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "🔍 What this shows:"
echo "   - Only logs from workers running on spot nodes"
echo "   - Spot-specific events and activities"
echo "   - Helpful for troubleshooting spot node issues"
