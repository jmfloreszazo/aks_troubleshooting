#!/bin/bash

# Query 7: All spot-related logs
# Description: Shows all logs containing "spot" from any source

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🎯 Query 7: All spot-related logs"
echo "================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{job="fluent-bit"} |= "spot"'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "🔍 What this shows:"
echo "   - All logs from any pod containing 'spot'"
echo "   - System-wide spot node activities"
echo "   - Comprehensive spot node monitoring"
echo "   - Cluster events related to spot instances"
