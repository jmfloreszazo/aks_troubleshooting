#!/bin/bash

# Master Configuration Deep Analysis
# Description: Detailed analysis of Jenkins Master configuration and execution

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "👑 JENKINS MASTER - CONFIGURATION DEEP ANALYSIS"
echo "==============================================="
echo ""
echo "📊 Grafana Explore: http://$GRAFANA_IP/explore"
echo "👤 Login: admin / admin123"
echo ""

echo "🔧 MASTER CONFIGURATION QUERIES:"
echo ""

echo "1️⃣  STARTUP SEQUENCE ANALYSIS:"
echo "──────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "Starting|Started|Initializing|Initialized|Jenkins is fully up|Setup Wizard"'
echo ""

echo "2️⃣  JVM MEMORY CONFIGURATION:"
echo "─────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "JAVA_OPTS|-Xmx|-Xms|heap|Heap|UseG1GC|garbage|GC"'
echo ""

echo "3️⃣  PLUGIN INSTALLATION & LOADING:"
echo "──────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "plugin|Plugin|PluginManager|Installing|install-plugins|download plugins"'
echo ""

echo "4️⃣  CONFIGURATION AS CODE (JCasC):"
echo "──────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "casc|JCasC|Configuration as Code|reload-configuration|jenkins.yaml"'
echo ""

echo "5️⃣  CLOUD PROVIDER SETUP:"
echo "─────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "KubernetesCloud|cloud configuration|kubernetes.*template|containerTemplate"'
echo ""

echo "6️⃣  SECURITY REALM & AUTHORIZATION:"
echo "───────────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "SecurityRealm|AuthorizationStrategy|authentication|authorization|CSRF|apiToken"'
echo ""

echo "7️⃣  AGENT TUNNEL CONFIGURATION:"
echo "──────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "slaveAgentPort|jenkinsTunnel|agent.*port|50000|inbound.*agent"'
echo ""

echo "8️⃣  WORKSPACE & VOLUME SETUP:"
echo "─────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "jenkins_home|workspace|volume|mount|JENKINS_HOME"'
echo ""

echo "9️⃣  MASTER RESOURCE UTILIZATION:"
echo "───────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "memory.*usage|cpu.*usage|disk.*usage|load.*average|performance"'
echo ""

echo "🔟 MASTER ERROR ANALYSIS:"
echo "────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "ERROR|Error|FATAL|Fatal|Exception|OutOfMemoryError|StackOverflowError"'
echo ""

echo "💡 EXECUTION SPECIFIC QUERIES:"
echo ""

echo "📊 MASTER JOB ORCHESTRATION:"
echo "───────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "queue|Queue|build.*queued|executor|Executor|build.*started"'
echo ""

echo "🎯 MASTER NODE PROVISIONING:"
echo "───────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "provision|Provision|launching.*agent|creating.*pod|template.*provisioning"'
echo ""

echo "🔄 MASTER BUILD COORDINATION:"
echo "────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "build.*coordination|job.*assignment|worker.*allocation|build.*dispatch"'
echo ""

echo "📈 MASTER PERFORMANCE METRICS:"
echo "─────────────────────────────"
echo '{kubernetes_namespace_name="jenkins-master"} |~ "request.*duration|response.*time|throughput|latency|performance.*metric"'
echo ""

echo "💡 TROUBLESHOOTING TIPS:"
echo "- Use 24h time range for startup sequence analysis"
echo "- Use 2h time range for current execution analysis"
echo "- Use 15m time range for real-time monitoring"
echo "- Combine with |= \"ERROR\" for issue identification"
