#!/bin/bash

# Advanced Jenkins Master Configuration Analysis
# Description: Extract detailed Jenkins Master configuration information

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "👑 JENKINS MASTER - CONFIGURATION ANALYSIS"
echo "=========================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""

echo "🔧 MASTER CONFIGURATION QUERIES:"
echo ""

echo "1️⃣  MEMORY & RESOURCES:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "memory" or "Memory" or "heap" or "Heap"'
echo ""

echo "2️⃣  PLUGIN INFORMATION:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "plugin" or "Plugin"'
echo ""

echo "3️⃣  CLOUD CONFIGURATION:"
echo "─────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "cloud" or "Cloud" or "kubernetes"'
echo ""

echo "4️⃣  SCRIPT EXECUTION:"
echo "─────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "script" or "Script" or "groovy"'
echo ""

echo "5️⃣  STARTUP & INITIALIZATION:"
echo "─────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "startup" or "Startup" or "init" or "Jenkins is fully up"'
echo ""

echo "6️⃣  JVM CONFIGURATION:"
echo "──────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "java" or "Java" or "jvm" or "JVM" or "-Xmx" or "-Xms"'
echo ""

echo "7️⃣  SECURITY SETTINGS:"
echo "──────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "security" or "Security" or "auth" or "Auth"'
echo ""

echo "8️⃣  NODE REGISTRATION:"
echo "──────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "node" or "Node" or "agent" or "Agent"'
echo ""

echo "💡 USAGE TIPS:"
echo "- Use time range: Last 24 hours for startup logs"
echo "- Use time range: Last 2 hours for current activity" 
echo "- Each query targets specific configuration aspects"
echo "- Combine with filters like |= \"ERROR\" for issues"
