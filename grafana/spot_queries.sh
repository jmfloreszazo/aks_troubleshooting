#!/bin/bash

# Jenkins Spot Workers - Working Loki Queries
# Use these tested queries in Grafana Explore

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "� JENKINS SPOT WORKERS - WORKING QUERIES"
echo "========================================"
echo ""
echo "�📊 Grafana: http://$GRAFANA_IP"
echo "👤 Login: admin / admin123"
echo "🔗 Dashboard: http://$GRAFANA_IP/d/d96d4d0b-f8b5-4733-b086-55acd815c938"
echo ""

echo "✅ WORKING LOKI QUERIES:"
echo ""
echo "1️⃣  All Jenkins Workers logs:"
echo '   {kubernetes_namespace_name="jenkins-workers"}'
echo ""
echo "2️⃣  Jenkins Workers on spot nodes:"
echo '   {kubernetes_namespace_name="jenkins-workers"} |= "spot"'
echo ""
echo "3️⃣  Workers assigned to spot node:"
echo '   {kubernetes_namespace_name="jenkins-workers"} |= "aks-spot-33804603-vmss000000"'
echo ""
echo "4️⃣  Jenkins Master logs:"
echo '   {kubernetes_namespace_name="jenkins-master"}'
echo ""
echo "5️⃣  Worker lifecycle events:"
echo '   {kubernetes_namespace_name="jenkins-workers"} |~ "Created|Started|Killing"'
echo ""
echo "6️⃣  Scheduling events:"
echo '   {kubernetes_namespace_name="jenkins-workers"} |= "Scheduled"'
echo ""
echo "7️⃣  All spot-related logs:"
echo '   {job="fluent-bit"} |= "spot"'
echo ""

echo "💡 COPY AND PASTE these queries into Grafana Explore tab"
echo "🎯 Time range: Last 2 hours for best results"
