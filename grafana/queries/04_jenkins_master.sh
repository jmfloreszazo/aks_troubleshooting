#!/bin/bash

# Query 4: Jenkins Master logs
# Description: Shows logs from Jenkins master namespace

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "👑 Query 4: Jenkins Master logs"
echo "==============================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""
echo "📋 LOKI QUERY TO USE:"
echo ""
echo '{kubernetes_namespace_name="jenkins-master"}'
echo ""
echo "💡 Copy this query and paste it into Grafana Explore"
echo "🎯 Recommended time range: Last 2 hours"
echo ""
echo "🔍 What this shows:"
echo "   - All logs from Jenkins master"
echo "   - Master controller events"
echo "   - Job scheduling and management logs"
echo "   - Useful for troubleshooting master-side issues"
