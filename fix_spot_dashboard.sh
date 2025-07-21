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
    "title": "AKS Spot Nodes Monitoring - FIXED",
    "tags": ["kubernetes", "spot", "nodes", "jenkins"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "All Spot Related Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"fluent-bit\"} |= \"spot\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Jenkins Master Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-master\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 3,
        "title": "Jenkins Workers Logs (with spot)",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |= \"spot\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      },
      {
        "id": 4,
        "title": "All Jenkins Workers Events",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16}
      },
      {
        "id": 5,
        "title": "Spot Node Assignments",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"jenkins-workers\"} |= \"aks-spot-33804603-vmss000000\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 24}
      },
      {
        "id": 6,
        "title": "Kube-system Spot Events",
        "type": "logs",
        "targets": [
          {
            "expr": "{kubernetes_namespace_name=\"kube-system\"} |= \"spot\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 24}
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
echo "🔍 Probando consultas corregidas:"
echo ""

# Test jenkins-workers query
echo "📋 Jenkins Workers logs:"
CURRENT_TIME=$(date +%s)
START_TIME=$((CURRENT_TIME - 7200))

curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-workers\"}" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${CURRENT_TIME}" \
  2>/dev/null | jq -r '.data.result | length' && echo " series encontradas"

# Test spot-specific query
echo "📋 Jenkins Workers con 'spot':"
curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={kubernetes_namespace_name=\"jenkins-workers\"} |= \"spot\"" \
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
