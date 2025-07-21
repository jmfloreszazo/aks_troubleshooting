#!/bin/bash

# Query 3: Workers assigned to specific spot node
# Description: Shows logs from workers on a specific spot node

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🏷️  Query 3: Workers on specific spot node"
echo "=========================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{kubernetes_namespace_name="jenkins-workers"} |= "aks-spot-33804603-vmss000000"'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "ℹ️  NOTE: Replace 'aks-spot-33804603-vmss000000' with your actual spot node name"
echo ""
echo "🔍 What this shows:"
echo "   - Logs from workers on a specific spot node"
echo "   - Node-specific troubleshooting"
echo "   - Useful for investigating specific node issues"
echo ""
echo "🛠️  To get current spot node names:"
echo "   kubectl get nodes | grep spot"
