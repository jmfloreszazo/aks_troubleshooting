#!/bin/bash

# Query 5: Worker lifecycle events
# Description: Shows worker creation, start, and termination events

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🔄 Query 5: Worker lifecycle events"
echo "===================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Created|Started|Killing"'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "🔍 What this shows:"
echo "   - Worker pod creation events (Created)"
echo "   - Worker startup events (Started)"
echo "   - Worker termination events (Killing)"
echo "   - Complete lifecycle of spot workers"
echo "   - Perfect for monitoring worker churn"
