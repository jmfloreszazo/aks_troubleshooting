#!/bin/bash

# Jenkins Configuration Extractor via Kubernetes API
# Description: Extract Jenkins configuration directly from Kubernetes resources

echo "🔍 JENKINS CONFIGURATION EXTRACTOR"
echo "==================================="
echo ""

# Get Grafana IP for reference
GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")
echo "📊 Grafana Dashboard: http://$GRAFANA_IP"
echo ""

echo "🎯 EXTRACTING JENKINS CONFIGURATION..."
echo ""

echo "1️⃣  JENKINS MASTER POD DETAILS:"
echo "──────────────────────────────"
kubectl get pods -n jenkins-master -o wide
echo ""

echo "2️⃣  JENKINS MASTER RESOURCE LIMITS:"
echo "──────────────────────────────────"
kubectl describe pods -n jenkins-master | grep -A 10 -B 2 "Limits\|Requests"
echo ""

echo "3️⃣  JENKINS MASTER ENVIRONMENT VARIABLES:"
echo "─────────────────────────────────────────"
kubectl get pods -n jenkins-master -o jsonpath='{.items[*].spec.containers[*].env[*]}' | jq
echo ""

echo "4️⃣  JENKINS MASTER JVM OPTIONS:"
echo "──────────────────────────────"
kubectl logs -n jenkins-master deployment/jenkins-master | grep -i "java\|jvm\|heap\|-Xm" | head -20
echo ""

echo "5️⃣  JENKINS WORKERS POD STATUS:"
echo "──────────────────────────────"
kubectl get pods -n jenkins-workers -o wide
echo ""

echo "6️⃣  SPOT NODES INFORMATION:"
echo "──────────────────────────"
kubectl get nodes -l node.kubernetes.io/instance-type | grep spot
echo ""

echo "7️⃣  JENKINS MASTER CONFIG MAP:"
echo "─────────────────────────────"
kubectl get configmaps -n jenkins-master -o yaml
echo ""

echo "8️⃣  JENKINS MASTER SECRETS:"
echo "──────────────────────────"
kubectl get secrets -n jenkins-master
echo ""

echo "9️⃣  JENKINS SPOT WORKERS EVENTS:"
echo "───────────────────────────────"
kubectl get events -n jenkins-workers --sort-by=.metadata.creationTimestamp | tail -20
echo ""

echo "🔟 CURRENT RUNNING JOBS:"
echo "───────────────────────"
kubectl logs -n jenkins-workers --tail=50 -l app=jenkins-worker | grep -i "build\|job\|running" | tail -10
echo ""

echo "📊 RESOURCE USAGE:"
echo "─────────────────"
echo "Master namespace resource usage:"
kubectl top pods -n jenkins-master 2>/dev/null || echo "Metrics server not available"
echo ""
echo "Workers namespace resource usage:"
kubectl top pods -n jenkins-workers 2>/dev/null || echo "Metrics server not available"
echo ""

echo "🔧 HELM RELEASE INFO:"
echo "────────────────────"
helm list -n jenkins-master
echo ""

echo "📋 LOKI QUERIES FOR DETAILED ANALYSIS:"
echo "─────────────────────────────────────"
echo ""
echo "For complete Jenkins Master configuration:"
echo "  {kubernetes_namespace_name=\"jenkins-master\"} |= \"Configuration\" or \"config\""
echo ""
echo "For Jenkins plugin information:"
echo "  {kubernetes_namespace_name=\"jenkins-master\"} |= \"plugin\" |= \"installed\" or \"loading\""
echo ""
echo "For Spot workers job execution:"
echo "  {kubernetes_namespace_name=\"jenkins-workers\"} |= \"Build\" or \"Job\""
echo ""
echo "For resource allocation:"
echo "  {job=\"fluent-bit\"} |= \"jenkins\" |= \"memory\" or \"cpu\""
echo ""

echo "💡 NEXT STEPS:"
echo "1. Use the Loki queries above in Grafana: http://$GRAFANA_IP/explore"
echo "2. Check the extracted configuration above"
echo "3. For detailed logs, run: ./queries/10_complete_system_analysis.sh"
echo "4. For specific issues, run: ./queries/08_master_config_analysis.sh"
