#!/bin/bash

# Spot Workers Execution Deep Analysis
# Description: Detailed analysis of Spot Workers execution and performance

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🎯 SPOT WORKERS - EXECUTION DEEP ANALYSIS"
echo "=========================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""

echo "🚀 SPOT WORKERS EXECUTION QUERIES:"
echo ""

echo "1️⃣  BUILD EXECUTION FLOW:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Build.*started|Build.*running|Build.*finished|Build.*completed|Build.*result"'
echo ""

echo "2️⃣  PIPELINE STAGE EXECUTION:"
echo "────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Stage.*started|Stage.*completed|Pipeline.*started|Pipeline.*completed|step.*execution"'
echo ""

echo "3️⃣  JOB QUEUE & ASSIGNMENT:"
echo "──────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "job.*assigned|task.*received|work.*allocated|build.*queued|executor.*acquired"'
echo ""

echo "4️⃣  WORKSPACE MANAGEMENT:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "workspace.*created|workspace.*cleanup|checkout.*started|workspace.*path"'
echo ""

echo "5️⃣  CONTAINER RESOURCE ALLOCATION:"
echo "──────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "container.*created|resource.*allocated|cpu.*limit|memory.*limit|resource.*request"'
echo ""

echo "6️⃣  SPOT NODE SPECIFIC EXECUTION:"
echo "─────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |= "aks-spot-33804603-vmss000000" |~ "Build|Job|Running|Executing"'
echo ""

echo "7️⃣  WORKER PERFORMANCE METRICS:"
echo "──────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "duration.*seconds|elapsed.*time|execution.*time|build.*time|performance"'
echo ""

echo "8️⃣  WORKER COMMUNICATION:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "connect.*master|communication.*established|tunnel.*connection|agent.*connection"'
echo ""

echo "9️⃣  DOCKER/CONTAINER OPERATIONS:"
echo "───────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "docker.*pull|image.*pulled|container.*start|docker.*build|registry.*pull"'
echo ""

echo "🔟 WORKER CLEANUP & TERMINATION:"
echo "──────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "cleanup.*started|build.*cleanup|workspace.*deleted|pod.*terminating|job.*completed"'
echo ""

echo "💡 EXECUTION ANALYSIS QUERIES:"
echo ""

echo "📊 BUILD SUCCESS/FAILURE ANALYSIS:"
echo "─────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Build.*SUCCESS|Build.*FAILURE|Build.*UNSTABLE|Build.*ABORTED"'
echo ""

echo "🎯 PARALLEL EXECUTION MONITORING:"
echo "────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "parallel.*execution|concurrent.*build|multiple.*jobs|parallel.*stage"'
echo ""

echo "🔄 BUILD RETRY & RECOVERY:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "retry.*attempt|build.*retry|recovery.*action|failure.*recovery"'
echo ""

echo "📈 THROUGHPUT & CAPACITY:"
echo "───────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "throughput|capacity|concurrent.*builds|queue.*length|utilization"'
echo ""

echo "⚠️  SPOT INTERRUPTION HANDLING:"
echo "──────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "spot.*interrupt|preemption|eviction|node.*pressure|resource.*pressure"'
echo ""

echo "🔍 SPOT EXECUTION PATTERNS:"
echo ""

echo "📋 Peak Usage Times:"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Build.*started"'
echo "   → Analyze with 1h time windows to find peak usage"
echo ""

echo "📋 Average Build Duration:"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "Build.*completed.*duration"'
echo "   → Track build performance over time"
echo ""

echo "📋 Resource Efficiency:"
echo '{kubernetes_namespace_name="jenkins-workers"} |~ "cpu.*usage|memory.*usage" |= "spot"'
echo "   → Monitor spot node resource utilization"
echo ""

echo "💡 ANALYSIS TIPS:"
echo "- Use 1h time range for build pattern analysis"
echo "- Use 15m time range for real-time execution monitoring"
echo "- Use 24h time range for capacity planning"
echo "- Filter by specific job names: |= \"job-name\""
echo "- Filter by build numbers: |= \"#123\""
