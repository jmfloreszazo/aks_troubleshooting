#!/bin/bash

# Corrected Jenkins Dashboard with Proper Queries
# Uses correct label selectors based on actual node configuration

set -euo pipefail

# Configuration
GRAFANA_URL="http://4.175.33.237"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"

echo "=========================================="
echo "Creating CORRECTED Jenkins Dashboard"
echo "=========================================="

# Function to create corrected dashboard
create_corrected_dashboard() {
    echo "Creating corrected Jenkins dashboard with proper label selectors..."
    
    CORRECTED_DASHBOARD='{
        "dashboard": {
            "id": null,
            "title": "Jenkins & AKS Nodes",
            "tags": ["jenkins", "aks", "nodes", "working"],
            "timezone": "browser",
            "panels": [
                {
                    "id": 1,
                    "title": "Total Nodes by Pool",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count by (label_agentpool) (kube_node_labels)",
                            "legendFormat": "{{label_agentpool}}",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "palette-classic"}
                        }
                    }
                },
                {
                    "id": 2,
                    "title": "Spot Nodes Count",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_node_labels{label_agentpool=\"spot\"})",
                            "legendFormat": "Spot Nodes",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
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
                    "title": "Regular Nodes Count",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_node_labels{label_agentpool=\"regular\"})",
                            "legendFormat": "Regular Nodes",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
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
                    "title": "All Running Pods",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_pod_status_phase{phase=\"Running\"})",
                            "legendFormat": "Running Pods",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 0, "y": 8},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "red", "value": 0},
                                    {"color": "yellow", "value": 10},
                                    {"color": "green", "value": 20}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 5,
                    "title": "Jenkins Namespace Pods",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_pod_info{namespace=\"jenkins\"})",
                            "legendFormat": "Jenkins Pods",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 6, "y": 8},
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
                    "id": 6,
                    "title": "Prometheus Namespace Pods",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_pod_info{namespace=\"prometheus-system\"})",
                            "legendFormat": "Prometheus Pods",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 12, "y": 8},
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
                    "id": 7,
                    "title": "Loki Namespace Pods",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_pod_info{namespace=\"loki\"})",
                            "legendFormat": "Loki Pods",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 18, "y": 8},
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
                    "id": 8,
                    "title": "Node Memory Usage by Pool",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                            "legendFormat": "{{instance}} Memory %",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "max": 100,
                            "min": 0
                        }
                    }
                },
                {
                    "id": 9,
                    "title": "Node CPU Usage by Pool",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                            "legendFormat": "{{instance}} CPU %",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "max": 100,
                            "min": 0
                        }
                    }
                },
                {
                    "id": 10,
                    "title": "Pod Distribution by Node",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "count by (node) (kube_pod_info)",
                            "legendFormat": "{{node}}",
                            "datasource": {"type": "prometheus", "uid": "besosx4c5cm4ga"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 24},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "short"
                        }
                    }
                },
                {
                    "id": 11,
                    "title": "Jenkins System Logs",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{namespace=\"jenkins\"} |~ \"(?i)error|warn|info\"",
                            "datasource": {"type": "loki", "uid": "P8E80F9AEF21F6940"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 32},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending"
                    }
                },
                {
                    "id": 12,
                    "title": "System Events",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{namespace=~\"kube-system|prometheus-system\"} |~ \"(?i)error|warn\"",
                            "datasource": {"type": "loki", "uid": "P8E80F9AEF21F6940"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 32},
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
        -d "$CORRECTED_DASHBOARD")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200)
            echo "Corrected dashboard created successfully"
            DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
            if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
                echo "Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/jenkins-aks-nodes-working-dashboard"
            fi
            ;;
        *)
            echo "Error creating dashboard. HTTP Code: $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Test our queries first
echo "Testing our queries before creating dashboard..."

echo "1. Node count by pool:"
curl -s -u admin:admin123 "http://4.175.33.237/api/datasources/proxy/2/api/v1/query?query=count%20by%20(label_agentpool)%20(kube_node_labels)" | jq -r '.data.result[] | "\(.metric.label_agentpool): \(.value[1])"'

echo -e "\n2. Spot nodes:"
curl -s -u admin:admin123 "http://4.175.33.237/api/datasources/proxy/2/api/v1/query?query=count(kube_node_labels{label_agentpool=\"spot\"})" | jq -r '.data.result[0].value[1]' && echo " spot nodes"

echo -e "\n3. Running pods:"
curl -s -u admin:admin123 "http://4.175.33.237/api/datasources/proxy/2/api/v1/query?query=count(kube_pod_status_phase{phase=\"Running\"})" | jq -r '.data.result[0].value[1]' && echo " running pods"

echo -e "\n4. Jenkins namespace pods:"
curl -s -u admin:admin123 "http://4.175.33.237/api/datasources/proxy/2/api/v1/query?query=count(kube_pod_info{namespace=\"jenkins\"})" | jq -r '.data.result[0].value[1]' && echo " Jenkins pods"

# Create the dashboard
echo -e "\nCreating dashboard with working queries..."
create_corrected_dashboard

echo ""
echo "=========================================="
echo "Dashboard with WORKING metrics created!"
echo "=========================================="
echo ""
echo "This dashboard uses:"
echo "Correct node pool labels (label_agentpool)"
echo "Working pod metrics (kube_pod_info, kube_pod_status_phase)"
echo "Memory and CPU metrics from node_exporter"
echo "Jenkins and system logs from Loki"
echo ""
echo "The dashboard should now show real data!"
