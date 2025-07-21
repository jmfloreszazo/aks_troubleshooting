#!/bin/bash

# Advanced Jenkins Spot Workers Execution Analysis
# Description: Extract detailed Spot Workers execution and configuration information

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🎯 JENKINS SPOT WORKERS - EXECUTION ANALYSIS"
echo "============================================"
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""

echo "🚀 SPOT WORKERS EXECUTION QUERIES:"
echo ""

echo "1️⃣  JOB EXECUTION DETAILS:"
echo "──────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "Running" or "Executing" or "Build"'
echo ""

echo "2️⃣  RESOURCE ALLOCATION:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "memory" or "Memory" or "cpu" or "CPU"'
echo ""

echo "3️⃣  PIPELINE EXECUTION:"
echo "───────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "pipeline" or "Pipeline" or "stage" or "Stage"'
echo ""

echo "4️⃣  SPOT NODE ASSIGNMENT:"
echo "─────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "spot" |= "Assigned" or "scheduled" or "node"'
echo ""

echo "5️⃣  CONTAINER START/STOP:"
echo "─────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "Container" or "container" |= "started" or "stopped" or "created"'
echo ""

echo "6️⃣  BUILD WORKSPACE:"
echo "────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "workspace" or "Workspace" or "checkout"'
echo ""

echo "7️⃣  NETWORK & CONNECTIVITY:"
echo "──────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "connect" or "Connect" or "network" or "Network"'
echo ""

echo "8️⃣  ERROR & FAILURES:"
echo "─────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "ERROR" or "Error" or "FAILED" or "Failed"'
echo ""

echo "9️⃣  PERFORMANCE METRICS:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "duration" or "Duration" or "time" or "seconds"'
echo ""

echo "🔟 SPOT INTERRUPTION:"
echo "────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "interrupt" or "Interrupt" or "preempt" or "evict"'
echo ""

echo "💡 ADVANCED QUERIES:"
echo "- Combine filters: |= \"spot\" |= \"ERROR\" for spot-specific errors"
echo "- Use regex: |~ \"Build.*completed\" for build completion patterns"
echo "- Time filtering: Use 15m-1h for active jobs, 24h for historical analysis"
