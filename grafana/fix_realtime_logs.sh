#!/bin/bash

# Fix Real-time Logs Panel in Logical Monitoring Dashboard

set -euo pipefail

# Configuration
GRAFANA_URL="http://135.236.73.36"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"

echo "=========================================="
echo "Fixing Real-time Logs Panel"
echo "=========================================="

# Get datasource UIDs
echo "Getting datasource UIDs..."
PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
LOKI_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null)

echo "Prometheus UID: $PROMETHEUS_UID"
echo "Loki UID: $LOKI_UID"

# Create updated Logical Monitoring dashboard with better log queries
LOGICAL_DASHBOARD='{
    "dashboard": {
        "id": null,
        "title": "Logical Monitoring - Logs, Spot Events, Pipeline Alerts",
        "tags": ["logical", "logs", "alerts", "jenkins", "prometheus-datasource", "loki-datasource", "kubernetes-events"],
        "timezone": "browser",
        "panels": [
            {
                "id": 1,
                "title": "Total Running Pods",
                "type": "stat",
                "targets": [
                    {
                        "expr": "count(kube_pod_status_phase{phase=\"Running\"})",
                        "legendFormat": "Running Pods",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 8, "x": 0, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "red", "value": 0},
                                {"color": "green", "value": 1}
                            ]
                        }
                    }
                }
            },
            {
                "id": 2,
                "title": "Total Pod Restarts (All Namespaces)",
                "type": "stat",
                "targets": [
                    {
                        "expr": "sum(kube_pod_container_status_restarts_total)",
                        "legendFormat": "Total Restarts",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 8, "x": 8, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "green", "value": 0},
                                {"color": "orange", "value": 5},
                                {"color": "red", "value": 10}
                            ]
                        }
                    }
                }
            },
            {
                "id": 3,
                "title": "Ready Nodes",
                "type": "stat",
                "targets": [
                    {
                        "expr": "count(kube_node_status_condition{condition=\"Ready\", status=\"true\"})",
                        "legendFormat": "Ready Nodes",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 8, "x": 16, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "red", "value": 0},
                                {"color": "green", "value": 1}
                            ]
                        }
                    }
                }
            },
            {
                "id": 4,
                "title": "ALL LOGS - Real Time Stream (Fixed)",
                "type": "logs",
                "targets": [
                    {
                        "expr": "{job=\"fluent-bit\"}",
                        "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                        "refId": "A",
                        "maxLines": 1000,
                        "resolution": 1
                    }
                ],
                "gridPos": {"h": 14, "w": 24, "x": 0, "y": 8},
                "options": {
                    "showTime": true,
                    "showLabels": true,
                    "showCommonLabels": false,
                    "sortOrder": "Descending",
                    "wrapLogMessage": false,
                    "prettifyLogMessage": false,
                    "enableLogDetails": true,
                    "dedupStrategy": "none"
                }
            },
            {
                "id": 5,
                "title": "Jenkins Logs",
                "type": "logs",
                "targets": [
                    {
                        "expr": "{job=\"fluent-bit\", kubernetes_namespace_name=\"jenkins-master\"}",
                        "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                        "refId": "A"
                    }
                ],
                "gridPos": {"h": 10, "w": 12, "x": 0, "y": 22},
                "options": {
                    "showTime": true,
                    "showLabels": true,
                    "sortOrder": "Descending",
                    "wrapLogMessage": true,
                    "enableLogDetails": true
                }
            },
            {
                "id": 6,
                "title": "Error and Warning Logs",
                "type": "logs",
                "targets": [
                    {
                        "expr": "{job=\"fluent-bit\"} |~ \"(?i)error|warning|warn|fail|exception\"",
                        "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                        "refId": "A"
                    }
                ],
                "gridPos": {"h": 10, "w": 12, "x": 12, "y": 22},
                "options": {
                    "showTime": true,
                    "showLabels": true,
                    "sortOrder": "Descending",
                    "wrapLogMessage": true,
                    "enableLogDetails": true
                }
            },
            {
                "id": 7,
                "title": "Pod Status Over Time",
                "type": "timeseries",
                "targets": [
                    {
                        "expr": "count by (phase) (kube_pod_status_phase)",
                        "legendFormat": "{{phase}}",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 32}
            }
        ],
        "time": {"from": "now-15m", "to": "now"},
        "refresh": "5s",
        "schemaVersion": 30,
        "version": 1
    },
    "overwrite": true
}'

echo "Updating Logical Monitoring dashboard with fixed real-time logs..."
RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "${GRAFANA_URL}/api/dashboards/db" \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -d "$LOGICAL_DASHBOARD")

HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

case $HTTP_CODE in
    200)
        echo "✅ Logical monitoring dashboard updated successfully!"
        DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
        if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
            echo "📊 Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/logical-monitoring-logs-spot-events-pipeline-alerts"
        fi
        ;;
    *)
        echo "❌ Error updating dashboard. HTTP Code: $HTTP_CODE"
        echo "Response: $BODY"
        ;;
esac

echo ""
echo "🔧 FIXES APPLIED:"
echo "   - Changed panel query format from 'query' to 'expr'"
echo "   - Added maxLines and resolution parameters"
echo "   - Increased panel height for better visibility"
echo "   - Set refresh to 5 seconds for real-time updates"
echo "   - Adjusted time range to last 15 minutes"
echo "   - Improved options for log display"
echo ""
echo "🚀 Real-time logs should now be working!"
