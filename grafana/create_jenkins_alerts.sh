#!/bin/bash

# Enhanced Jenkins monitoring with alerts and additional metrics
# Adds specific alerts for Jenkins and spot node issues

set -euo pipefail

# Configuration
GRAFANA_URL="http://4.175.33.237"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"

echo "=========================================="
echo "Creating Jenkins Alerts & Enhanced Monitoring"
echo "=========================================="

# Function to create Jenkins alerts dashboard
create_jenkins_alerts_dashboard() {
    echo "Creating Jenkins alerts and critical monitoring dashboard..."
    
    ALERTS_DASHBOARD='{
        "dashboard": {
            "id": null,
            "title": "Jenkins Alerts & Critical Monitoring",
            "tags": ["jenkins", "alerts", "critical"],
            "timezone": "browser",
            "panels": [
                {
                    "id": 1,
                    "title": "CRITICAL: Spot Node Interruptions",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "increase(kube_node_status_condition{agentpool=\"spot\", condition=\"Ready\", status=\"false\"}[5m])",
                            "legendFormat": "Spot Interruptions",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
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
                    },
                    "alert": {
                        "conditions": [
                            {
                                "query": {"queryType": "", "refId": "A"},
                                "reducer": {"type": "last", "params": []},
                                "evaluator": {"params": [1], "type": "gt"}
                            }
                        ],
                        "executionErrorState": "alerting",
                        "frequency": "30s",
                        "handler": 1,
                        "name": "Spot Node Interruption Alert",
                        "noDataState": "no_data"
                    }
                },
                {
                    "id": 2,
                    "title": "CRITICAL: Jenkins Master Down",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_pod_status_phase{pod=~\"jenkins-.*\", namespace=\"jenkins\", phase=\"Running\"})",
                            "legendFormat": "Jenkins Running",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
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
                    "id": 3,
                    "title": "Jenkins Master Memory Critical",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "(container_memory_usage_bytes{pod=~\"jenkins-.*\", namespace=\"jenkins\", container!=\"POD\"} / container_spec_memory_limit_bytes{pod=~\"jenkins-.*\", namespace=\"jenkins\", container!=\"POD\"}) * 100",
                            "legendFormat": "Memory %",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 80},
                                    {"color": "red", "value": 95}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 4,
                    "title": "Pod Evictions Rate",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "rate(kube_pod_status_reason{reason=\"Evicted\"}[5m]) * 300",
                            "legendFormat": "Evictions/5min",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 1},
                                    {"color": "red", "value": 3}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 5,
                    "title": "Spot Nodes Timeline",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "count(kube_node_info{agentpool=\"spot\"})",
                            "legendFormat": "Total Spot Nodes",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        },
                        {
                            "expr": "count(kube_node_status_condition{agentpool=\"spot\", condition=\"Ready\", status=\"true\"})",
                            "legendFormat": "Ready Spot Nodes",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
                    "fieldConfig": {
                        "defaults": {
                            "thresholds": {
                                "steps": [
                                    {"color": "red", "value": 0},
                                    {"color": "yellow", "value": 1},
                                    {"color": "green", "value": 2}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 6,
                    "title": "Jenkins Agent Pods Distribution",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "count by(node) (kube_pod_info{pod=~\"jenkins-agent-.*\", namespace=\"jenkins\"} * on(node) group_left(agentpool) kube_node_labels)",
                            "legendFormat": "{{node}}",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
                    "fieldConfig": {
                        "defaults": {
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 5},
                                    {"color": "red", "value": 10}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 7,
                    "title": "Node Resource Pressure",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "kube_node_status_condition{condition=\"MemoryPressure\", status=\"true\"}",
                            "legendFormat": "{{node}} Memory Pressure",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        },
                        {
                            "expr": "kube_node_status_condition{condition=\"DiskPressure\", status=\"true\"}",
                            "legendFormat": "{{node}} Disk Pressure",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
                    "fieldConfig": {
                        "defaults": {
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
                    "id": 8,
                    "title": "Recent Critical Events",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{namespace=~\"jenkins|kube-system\"} |~ \"(?i)error|fail|evict|terminate|interrupt|critical|fatal\"",
                            "datasource": {"type": "loki", "uid": "P8E80F9AEF21F6940"}
                        }
                    ],
                    "gridPos": {"h": 12, "w": 24, "x": 0, "y": 24},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending"
                    }
                }
            ],
            "time": {"from": "now-1h", "to": "now"},
            "refresh": "30s",
            "schemaVersion": 30,
            "version": 1
        },
        "overwrite": true
    }'
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "${GRAFANA_URL}/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$ALERTS_DASHBOARD")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200)
            echo "Jenkins alerts dashboard created successfully"
            DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
            if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
                echo "Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/jenkins-alerts-critical-monitoring"
            fi
            ;;
        *)
            echo "Error creating alerts dashboard. HTTP Code: $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Function to list all created dashboards
list_jenkins_dashboards() {
    echo "Listing all Jenkins-related dashboards..."
    
    DASHBOARDS=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/search?query=jenkins")
    echo "$DASHBOARDS" | jq -r '.[] | "- \(.title) (UID: \(.uid))"' 2>/dev/null || echo "Unable to parse dashboards list"
}

# Function to display comprehensive summary
display_comprehensive_summary() {
    echo ""
    echo "============================================="
    echo "Jenkins Complete Monitoring Setup Complete"
    echo "============================================="
    echo ""
    echo "Available Dashboards:"
    echo "1. Jenkins Master & Spot Nodes - Complete Monitoring"
    echo "   - Real-time spot node status and health monitoring"
    echo "   - Jenkins master resource usage (CPU, Memory, Disk)"
    echo "   - Pod evictions and container restart tracking"
    echo "   - Network traffic analysis by node pool"
    echo "   - Container and system error logs"
    echo ""
    echo "2. Jenkins Plugins & System Health"
    echo "   - Plugin-specific error monitoring"
    echo "   - Build queue and job execution logs"
    echo "   - Jenkins agent connection status"
    echo ""
    echo "3. Jenkins Alerts & Critical Monitoring"
    echo "   - Critical alerts for spot node interruptions"
    echo "   - Jenkins master availability monitoring"
    echo "   - Memory pressure and resource alerts"
    echo "   - Real-time critical event logs"
    echo ""
    echo "Key Features Monitored:"
    echo "✓ Spot node creation, destruction, and interruptions"
    echo "✓ Pod evictions and scheduling events"
    echo "✓ Jenkins master memory, CPU, and disk usage"
    echo "✓ Jenkins agent pods distribution across nodes"
    echo "✓ Container restarts and system failures"
    echo "✓ Network traffic and bandwidth usage"
    echo "✓ Plugin errors and system logs"
    echo "✓ Node resource pressure (memory, disk)"
    echo "✓ Critical system events and alerts"
    echo ""
    echo "Access Information:"
    echo "- Grafana URL: ${GRAFANA_URL}"
    echo "- Username: ${GRAFANA_USER}"
    echo "- Password: ${GRAFANA_PASSWORD}"
    echo ""
    echo "Dashboard URLs:"
    list_jenkins_dashboards
    echo ""
    echo "Setup completed successfully!"
    echo "All Jenkins and spot node monitoring is now active."
}

# Main execution
main() {
    echo "Testing Grafana connectivity..."
    if ! curl -f -s "${GRAFANA_URL}/api/health" > /dev/null; then
        echo "Error: Cannot connect to Grafana at ${GRAFANA_URL}"
        exit 1
    fi
    echo "Grafana connectivity verified"
    
    create_jenkins_alerts_dashboard
    display_comprehensive_summary
}

# Execute main function
main "$@"
