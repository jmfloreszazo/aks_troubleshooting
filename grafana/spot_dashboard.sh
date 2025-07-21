#!/bin/bash

echo "🎯 Actualizando Dashboard con consultas corregidas..."

# Get Grafana IP
GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "📊 Grafana IP: $GRAFANA_IP"

# Create corrected dashboard with proper label queries
cat << 'EOF' > /tmp/spot_dashboard_fixed.json
{
  "dashboard": {
    "id": null,
    "title": "Jenkins Master & Spot Workers - Complete Analysis",
    "tags": ["kubernetes", "spot", "nodes", "jenkins", "master", "config"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🔍 All Spot Related Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"fluent-bit\"} |= \"spot\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 6, "w": 24, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "👑 Jenkins Master - Configuration & Startup",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"} |~ \"JAVA_OPTS|plugin|config|Configuration|Started|Initialized\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 6}
      },
      {
        "id": 3,
        "title": "🎯 Spot Workers - Job Execution",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |~ \"Build|Job|Running|Executing|Pipeline|Stage\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 6}
      },
      {
        "id": 4,
        "title": "💾 Master - Memory & JVM Analysis",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"} |~ \"memory|Memory|heap|Heap|GC|garbage|-Xmx|-Xms|OutOfMemory\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 14}
      },
      {
        "id": 5,
        "title": "🔌 Master - Plugin Management",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"} |~ \"plugin|Plugin|PluginManager|Installing|Loaded\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 14}
      },
      {
        "id": 6,
        "title": "☁️ Master - Cloud Configuration",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"} |~ \"cloud|Cloud|kubernetes|KubernetesCloud|agent|Agent\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 22}
      },
      {
        "id": 7,
        "title": "🚀 Spot Workers - Resource Allocation",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |~ \"memory|Memory|cpu|CPU|resource|Resource|allocated|Allocated\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 22}
      },
      {
        "id": 8,
        "title": "🔄 Spot Workers - Lifecycle Events",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |~ \"Created|Started|Scheduled|Assigned|Killing|Deleted|Terminated\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 30}
      },
      {
        "id": 9,
        "title": "📊 Spot Workers - Performance Metrics",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |~ \"duration|Duration|time|seconds|ms|performance|Performance|completed|finished\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 30}
      },
      {
        "id": 10,
        "title": "🏷️ Specific Spot Node: aks-spot-33804603-vmss000000",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |= \"aks-spot-33804603-vmss000000\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 38}
      },
      {
        "id": 11,
        "title": "⚠️ System Errors & Warnings",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"fluent-bit\"} |= \"jenkins\" |~ \"ERROR|Error|WARN|Warning|FATAL|Fatal|Exception|exception|Failed|failed\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 38}
      },
      {
        "id": 12,
        "title": "🔐 Master - Security & Authentication",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"} |~ \"security|Security|auth|Auth|login|Login|user|User|permission|Permission\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 46}
      },
      {
        "id": 13,
        "title": "🌐 Network & Connectivity",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"fluent-bit\"} |= \"jenkins\" |~ \"connect|Connect|network|Network|timeout|Timeout|connection|Connection\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 46}
      },
      {
        "id": 14,
        "title": "📋 All Jenkins Workers Events (Complete)",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 54}
      },
      {
        "id": 15,
        "title": "🏛️ Master - Complete Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 54}
      }
    ],
    "time": {
      "from": "now-2h",
      "to": "now"
    },
    "refresh": "30s"
  },
  "overwrite": true
}
EOF

# Import corrected dashboard
echo "📤 Importando dashboard corregido..."
RESPONSE=$(curl -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/spot_dashboard_fixed.json \
  "http://admin:admin123@${GRAFANA_IP}/api/dashboards/db" \
  2>/dev/null)

echo "$RESPONSE" | jq '.'

echo ""
echo "✅ Dashboard corregido importado!"
echo ""

# Test queries
echo "🔍 Probando consultas del dashboard completo:"
echo ""

# Test jenkins-workers query
echo "📋 1. Jenkins Workers logs:"
CURRENT_TIME=$(date +%s)
START_TIME=$((CURRENT_TIME - 7200))

curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-workers\"}" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${CURRENT_TIME}" \
  2>/dev/null | jq -r '.data.result | length' && echo " series encontradas"

# Test master configuration query
echo "📋 2. Master Configuration:"
curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-master\"} |~ \"JAVA_OPTS|plugin|config\"" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${CURRENT_TIME}" \
  2>/dev/null | jq -r '.data.result | length' && echo " series encontradas"

# Test spot execution query
echo "📋 3. Spot Job Execution:"
curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-workers\"} |~ \"Build|Job|Running\"" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${CURRENT_TIME}" \
  2>/dev/null | jq -r '.data.result | length' && echo " series encontradas"

# Test memory analysis query
echo "📋 4. Master Memory Analysis:"
curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-master\"} |~ \"memory|heap|GC\"" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${CURRENT_TIME}" \
  2>/dev/null | jq -r '.data.result | length' && echo " series encontradas"

# Test plugin management query
echo "📋 5. Plugin Management:"
curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-master\"} |~ \"plugin|Plugin|PluginManager\"" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${CURRENT_TIME}" \
  2>/dev/null | jq -r '.data.result | length' && echo " series encontradas"

echo ""
echo "🔗 Nuevo Dashboard:"
DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url // "/dashboards"')
echo "   http://$GRAFANA_IP$DASHBOARD_URL"
echo ""

# Clean up
rm -f /tmp/spot_dashboard_fixed.json
