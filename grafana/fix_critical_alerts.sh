#!/bin/bash

# Fix Critical Alerts Dashboard - Critical Error Logs and All Application Logs Panels

set -euo pipefail

# Configuration
GRAFANA_URL="http://135.236.73.36"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"

echo "=========================================="
echo "Fixing Critical Alerts Dashboard"
echo "=========================================="

# Get datasource UIDs
echo "Getting datasource UIDs..."
PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
LOKI_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null)

echo "Prometheus UID: $PROMETHEUS_UID"
echo "Loki UID: $LOKI_UID"

# Create updated Critical Alerts dashboard with working log queries
CRITICAL_ALERTS_DASHBOARD='{
    "dashboard": {
        "id": null,
        "title": "CRITICAL ALERTS - System Health & Logs",
        "tags": ["critical", "alerts", "system", "health", "prometheus-datasource", "loki-datasource", "basic-monitoring"],
        "timezone": "browser",
        "panels": [
            {
                "id": 1,
                "title": "High CPU Usage Alert",
                "type": "stat",
                "targets": [
                    {
                        "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                        "legendFormat": "CPU Usage %",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "green", "value": 0},
                                {"color": "yellow", "value": 70},
                                {"color": "red", "value": 90}
                            ]
                        },
                        "unit": "percent"
                    }
                }
            },
            {
                "id": 2,
                "title": "High Memory Usage Alert",
                "type": "stat",
                "targets": [
                    {
                        "expr": "100 - (avg(node_memory_MemAvailable_bytes) / avg(node_memory_MemTotal_bytes) * 100)",
                        "legendFormat": "Memory Usage %",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "green", "value": 0},
                                {"color": "yellow", "value": 80},
                                {"color": "red", "value": 95}
                            ]
                        },
                        "unit": "percent"
                    }
                }
            },
            {
                "id": 3,
                "title": "Pod Restart Count",
                "type": "stat",
                "targets": [
                    {
                        "expr": "sum(kube_pod_container_status_restarts_total)",
                        "legendFormat": "Total Restarts",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "green", "value": 0},
                                {"color": "orange", "value": 5},
                                {"color": "red", "value": 20}
                            ]
                        }
                    }
                }
            },
            {
                "id": 4,
                "title": "Services Down",
                "type": "stat",
                "targets": [
                    {
                        "expr": "count(up == 0)",
                        "legendFormat": "Down Services",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
                "fieldConfig": {
                    "defaults": {
                        "color": {"mode": "thresholds"},
                        "thresholds": {
                            "steps": [
                                {"color": "green", "value": 0},
                                {"color": "red", "value": 1}
                            ]
                        }
                    }
                }
            },
            {
                "id": 5,
                "title": "Critical Error Logs (FIXED)",
                "type": "logs",
                "targets": [
                    {
                        "expr": "{job=\"fluent-bit\"} |~ \"(?i)fatal|critical|panic|crash|oom|error\"",
                        "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                        "refId": "A",
                        "maxLines": 500
                    }
                ],
                "gridPos": {"h": 14, "w": 12, "x": 0, "y": 8},
                "options": {
                    "showTime": true,
                    "showLabels": true,
                    "showCommonLabels": false,
                    "sortOrder": "Descending",
                    "wrapLogMessage": true,
                    "prettifyLogMessage": false,
                    "enableLogDetails": true,
                    "dedupStrategy": "none"
                }
            },
            {
                "id": 6,
                "title": "All Application Logs (FIXED)",
                "type": "logs",
                "targets": [
                    {
                        "expr": "{job=\"fluent-bit\"}",
                        "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                        "refId": "A",
                        "maxLines": 1000
                    }
                ],
                "gridPos": {"h": 14, "w": 12, "x": 12, "y": 8},
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
                "id": 7,
                "title": "System Resources Timeline",
                "type": "timeseries",
                "targets": [
                    {
                        "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                        "legendFormat": "CPU Usage %",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    },
                    {
                        "expr": "100 - (avg(node_memory_MemAvailable_bytes) / avg(node_memory_MemTotal_bytes) * 100)",
                        "legendFormat": "Memory Usage %",
                        "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                    }
                ],
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 22}
            },
            {
                "id": 8,
                "title": "Recent Kubernetes Events",
                "type": "logs",
                "targets": [
                    {
                        "expr": "{job=\"fluent-bit\", kubernetes_namespace_name=~\"kube-system|default|jenkins-master|observability-stack\"}",
                        "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                        "refId": "A",
                        "maxLines": 300
                    }
                ],
                "gridPos": {"h": 10, "w": 24, "x": 0, "y": 30},
                "options": {
                    "showTime": true,
                    "showLabels": true,
                    "sortOrder": "Descending",
                    "wrapLogMessage": true,
                    "enableLogDetails": true
                }
            }
        ],
        "time": {"from": "now-30m", "to": "now"},
        "refresh": "10s",
        "schemaVersion": 30,
        "version": 1
    },
    "overwrite": true
}'

echo "Updating Critical Alerts dashboard with fixed log panels..."
RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "${GRAFANA_URL}/api/dashboards/db" \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -d "$CRITICAL_ALERTS_DASHBOARD")

HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

case $HTTP_CODE in
    200)
        echo "✅ Critical Alerts dashboard updated successfully!"
        DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
        if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
            echo "📊 Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/critical-alerts-system-health-logs"
        fi
        ;;
    *)
        echo "❌ Error updating dashboard. HTTP Code: $HTTP_CODE"
        echo "Response: $BODY"
        ;;
esac

echo ""
echo "🔧 FIXES APPLIED TO CRITICAL ALERTS DASHBOARD:"
echo "   - Fixed 'Critical Error Logs' panel with proper expr format"
echo "   - Fixed 'All Application Logs' panel with correct Loki query"
echo "   - Added maxLines parameter for better performance"
echo "   - Improved log display options"
echo "   - Increased panel heights for better visibility"
echo "   - Added new 'Recent Kubernetes Events' panel"
echo "   - Set refresh to 10 seconds for timely updates"
echo "   - Extended time range to 30 minutes for more context"
echo ""
echo "🚀 Critical Alerts logs should now be working!"
echo ""
echo "📝 LOG PANEL DETAILS:"
echo "   - Critical Error Logs: Shows fatal, critical, panic, crash, oom, and error messages"
echo "   - All Application Logs: Shows all logs from fluent-bit"
echo "   - Recent Kubernetes Events: Shows logs from key namespaces"
echo ""
echo "🔍 You should now see:"
echo "   ✅ Critical error logs with severity filtering"
echo "   ✅ All application logs in real-time"
echo "   ✅ System metrics and alerts"
echo "   ✅ Kubernetes events from important namespaces"
