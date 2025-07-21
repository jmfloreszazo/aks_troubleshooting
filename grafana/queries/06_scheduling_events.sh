#!/bin/bash

# Query 6: Scheduling events
# Description: Shows pod scheduling events for workers

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "📅 Query 6: Scheduling events"
echo "============================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{kubernetes_namespace_name="jenkins-workers"} |= "Scheduled"'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "🔍 What this shows:"
echo "   - When workers are scheduled on nodes"
echo "   - Which nodes workers are assigned to"
echo "   - Scheduling delays or issues"
echo "   - Helpful for understanding worker placement"
