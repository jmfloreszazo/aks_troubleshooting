#!/bin/bash

# Complete Jenkins System Information Extraction
# Description: One-stop script for all Jenkins configuration and operational data

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🔍 COMPLETE JENKINS SYSTEM ANALYSIS"
echo "==================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""

echo "📋 COMPREHENSIVE SYSTEM QUERIES:"
echo ""

echo "🏗️  COMPLETE SYSTEM OVERVIEW:"
echo "─────────────────────────────"
echo '{job="fluent-bit"} |= "jenkins"'
echo ""

echo "🔧 JENKINS MASTER FULL CONFIG:"
echo "──────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ ".*"'
echo ""

echo "⚙️  MASTER STARTUP SEQUENCE:"
echo "───────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "Starting" or "Started" or "Initialized"'
echo ""

echo "🔌 PLUGIN MANAGEMENT:"
echo "────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "PluginManager" or "plugin.xml" or "Installing plugin"'
echo ""

echo "☁️  CLOUD PROVIDER CONFIG:"
echo "─────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "KubernetesCloud" or "Cloud configuration"'
echo ""

echo "💾 JVM & MEMORY DETAILS:"
echo "───────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "-Xmx[0-9]+[mg]|-Xms[0-9]+[mg]|heap|garbage|GC"'
echo ""

echo "🔐 SECURITY CONFIGURATION:"
echo "─────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |= "SecurityRealm" or "AuthorizationStrategy" or "CSRF"'
echo ""

echo "🎯 SPOT WORKERS COMPLETE:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ ".*"'
echo ""

echo "🚀 JOB EXECUTION FLOW:"
echo "─────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "Build" |= "started" or "finished" or "completed"'
echo ""

echo "📊 RESOURCE MONITORING:"
echo "──────────────────────"
echo '{job="fluent-bit"} |= "jenkins" |~ "memory|cpu|disk|Memory|CPU|Disk"'
echo ""

echo "⚠️  ERROR & WARNING ANALYSIS:"
echo "────────────────────────────"
echo '{job="fluent-bit"} |= "jenkins" |~ "ERROR|WARN|FATAL|Exception|exception"'
echo ""

echo "🔄 NODE LIFECYCLE COMPLETE:"
echo "──────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Created|Started|Scheduled|Assigned|Killing|Deleted"'
echo ""

echo "📈 PERFORMANCE METRICS:"
echo "──────────────────────"
echo '{job="fluent-bit"} |= "jenkins" |~ "duration|time|seconds|ms|performance"'
echo ""

echo "🛠️  TROUBLESHOOTING HELPERS:"
echo ""
echo "🔍 Last 10 minutes activity:"
echo '   {job="fluent-bit"} |= "jenkins" (use Last 10 minutes time range)'
echo ""
echo "🔍 Startup logs (use Last 24 hours):"
echo '   {kubernetes_namespace_name="jenkins-master"} |= "Jenkins is fully up"'
echo ""
echo "🔍 Current active jobs:"
echo '   {kubernetes_namespace_name="jenkins-workers"} |= "Running"'
echo ""
echo "🔍 Spot node events:"
echo '   {job="fluent-bit"} |= "spot" |= "jenkins"'
echo ""

echo "💡 EXPERT TIPS:"
echo "- Start with time range: Last 2 hours"
echo "- For startup issues: Last 24 hours"
echo "- For active monitoring: Last 15 minutes"
echo "- Use |= \"ERROR\" to filter only errors"
echo "- Use |~ \"pattern.*regex\" for complex patterns"
