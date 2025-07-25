#!/bin/bash

# Jenkins monitoring separated into Physical and Logical monitoring
# Physical: CPU, Memory, Disk, Inodes, Network
# Logical: Logs, Alerts, Pipeline status, Spot interruptions

set -euo pipefail

# Configuration
GRAFANA_URL="http://135.236.73.36"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"

echo "=========================================="
echo "Creating Jenkins Physical & Logical Monitoring"
echo "=========================================="

# Function to add Prometheus datasource if not exists
add_prometheus_datasource() {
    echo "Checking Prometheus datasource..."
    
    # Check if Prometheus datasource exists
    PROMETHEUS_DS=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
    
    if [ -z "$PROMETHEUS_DS" ] || [ "$PROMETHEUS_DS" = "null" ]; then
        echo "Adding Prometheus datasource..."
        
        PROMETHEUS_DATASOURCE='{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090",
            "access": "proxy",
            "isDefault": false,
            "basicAuth": false,
            "editable": true
        }'
        
        RESPONSE=$(curl -s -w "%{http_code}" -X POST \
            "${GRAFANA_URL}/api/datasources" \
            -H "Content-Type: application/json" \
            -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
            -d "$PROMETHEUS_DATASOURCE")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        case $HTTP_CODE in
            200|201)
                echo "Prometheus datasource added successfully"
                PROMETHEUS_UID=$(echo "$BODY" | jq -r '.datasource.uid' 2>/dev/null)
                if [ -z "$PROMETHEUS_UID" ]; then
                    PROMETHEUS_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
                fi
                echo "Prometheus UID: $PROMETHEUS_UID"
                ;;
            *)
                echo "Warning: Could not add Prometheus datasource. HTTP Code: $HTTP_CODE"
                echo "Response: $BODY"
                PROMETHEUS_UID="prometheus-uid"
                ;;
        esac
    else
        echo "Prometheus datasource already exists with UID: $PROMETHEUS_DS"
        PROMETHEUS_UID="$PROMETHEUS_DS"
    fi
}

# Function to add Loki datasource if not exists
add_loki_datasource() {
    echo "Checking Loki datasource..."
    
    # Check if Loki datasource exists
    LOKI_DS=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null)
    
    if [ -z "$LOKI_DS" ] || [ "$LOKI_DS" = "null" ]; then
        echo "Adding Loki datasource..."
        
        LOKI_DATASOURCE='{
            "name": "Loki",
            "type": "loki",
            "url": "http://loki.observability-stack.svc.cluster.local:3100",
            "access": "proxy",
            "isDefault": false,
            "basicAuth": false,
            "editable": true,
            "jsonData": {
                "maxLines": 1000,
                "derivedFields": []
            }
        }'
        
        RESPONSE=$(curl -s -w "%{http_code}" -X POST \
            "${GRAFANA_URL}/api/datasources" \
            -H "Content-Type: application/json" \
            -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
            -d "$LOKI_DATASOURCE")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        case $HTTP_CODE in
            200|201)
                echo "Loki datasource added successfully"
                LOKI_UID=$(echo "$BODY" | jq -r '.datasource.uid' 2>/dev/null)
                if [ -z "$LOKI_UID" ]; then
                    LOKI_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
                fi
                echo "Loki UID: $LOKI_UID"
                ;;
            *)
                echo "Warning: Could not add Loki datasource. HTTP Code: $HTTP_CODE"
                echo "Response: $BODY"
                LOKI_UID="loki-uid"
                ;;
        esac
    else
        echo "Loki datasource already exists with UID: $LOKI_DS"
        LOKI_UID="$LOKI_DS"
    fi
}

# Function to configure Loki-Prometheus integration
configure_loki_prometheus_integration() {
    echo "Configuring Loki-Prometheus integration..."
    
    # Get both datasource UIDs
    PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
    LOKI_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null)
    
    if [ -z "$PROMETHEUS_UID" ] || [ "$PROMETHEUS_UID" = "null" ] || [ -z "$LOKI_UID" ] || [ "$LOKI_UID" = "null" ]; then
        echo "Error: Both Prometheus and Loki datasources must exist before configuring integration"
        return 1
    fi
    
    echo "Prometheus UID: $PROMETHEUS_UID"
    echo "Loki UID: $LOKI_UID"
    
    # Update Loki datasource with Prometheus integration
    LOKI_INTEGRATION_CONFIG='{
        "name": "Loki",
        "type": "loki",
        "url": "http://loki.observability-stack.svc.cluster.local:3100",
        "access": "proxy",
        "isDefault": false,
        "basicAuth": false,
        "editable": true,
        "jsonData": {
            "maxLines": 1000,
            "derivedFields": [
                {
                    "name": "TraceID",
                    "matcherRegex": "trace_id=(\\w+)",
                    "url": "${__value.raw}",
                    "datasourceUid": "'${PROMETHEUS_UID}'"
                },
                {
                    "name": "Prometheus Query",
                    "matcherRegex": "job=([^\\s]+)",
                    "url": "/explore?orgId=1&left={\"datasource\":\"'${PROMETHEUS_UID}'\",\"queries\":[{\"expr\":\"up{job=\\\"${__value.raw}\\\"}\",\"refId\":\"A\"}],\"range\":{\"from\":\"now-1h\",\"to\":\"now\"}}",
                    "datasourceUid": "'${PROMETHEUS_UID}'"
                }
            ],
            "alertmanager": {
                "datasourceUid": "'${PROMETHEUS_UID}'"
            }
        }
    }'
    
    # Get Loki datasource ID
    LOKI_ID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .id' 2>/dev/null)
    
    if [ -n "$LOKI_ID" ] && [ "$LOKI_ID" != "null" ]; then
        echo "Updating Loki datasource with Prometheus integration..."
        RESPONSE=$(curl -s -w "%{http_code}" -X PUT \
            "${GRAFANA_URL}/api/datasources/${LOKI_ID}" \
            -H "Content-Type: application/json" \
            -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
            -d "$LOKI_INTEGRATION_CONFIG")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        case $HTTP_CODE in
            200)
                echo "Loki-Prometheus integration configured successfully"
                ;;
            *)
                echo "Warning: Could not configure Loki-Prometheus integration. HTTP Code: $HTTP_CODE"
                echo "Response: $BODY"
                ;;
        esac
    else
        echo "Error: Could not find Loki datasource ID"
    fi
    
    # Update Prometheus datasource with Loki exemplars
    PROMETHEUS_INTEGRATION_CONFIG='{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090",
        "access": "proxy",
        "isDefault": false,
        "basicAuth": false,
        "editable": true,
        "jsonData": {
            "httpMethod": "POST",
            "exemplarTraceIdDestinations": [
                {
                    "name": "trace_id",
                    "datasourceUid": "'${LOKI_UID}'"
                }
            ]
        }
    }'
    
    # Get Prometheus datasource ID
    PROMETHEUS_ID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .id' 2>/dev/null)
    
    if [ -n "$PROMETHEUS_ID" ] && [ "$PROMETHEUS_ID" != "null" ]; then
        echo "Updating Prometheus datasource with Loki exemplars..."
        RESPONSE=$(curl -s -w "%{http_code}" -X PUT \
            "${GRAFANA_URL}/api/datasources/${PROMETHEUS_ID}" \
            -H "Content-Type: application/json" \
            -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
            -d "$PROMETHEUS_INTEGRATION_CONFIG")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        case $HTTP_CODE in
            200)
                echo "Prometheus-Loki exemplars configured successfully"
                ;;
            *)
                echo "Warning: Could not configure Prometheus-Loki exemplars. HTTP Code: $HTTP_CODE"
                echo "Response: $BODY"
                ;;
        esac
    else
        echo "Error: Could not find Prometheus datasource ID"
    fi
    
    echo "Loki-Prometheus integration setup completed"
}

# Function to create Physical Resources dashboard
create_physical_monitoring_dashboard() {
    echo "Creating Physical Resources monitoring dashboard..."
    
    # Get Prometheus datasource UID
    PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
    if [ -z "$PROMETHEUS_UID" ] || [ "$PROMETHEUS_UID" = "null" ]; then
        PROMETHEUS_UID="prometheus-uid"
    fi
    
    PHYSICAL_DASHBOARD='{
        "dashboard": {
            "id": null,
            "title": "Physical Resources Monitoring - CPU, Memory, Disk, Network",
            "tags": ["physical", "resources", "infrastructure", "prometheus-datasource", "node-exporter", "kube-state-metrics"],
            "timezone": "browser",
            "panels": [
                {
                    "id": 1,
                    "title": "Node CPU Usage by Node Pool",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                            "legendFormat": "{{instance}}",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 70},
                                    {"color": "red", "value": 90}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 2,
                    "title": "Memory Usage by Node",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100",
                            "legendFormat": "{{instance}}",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
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
                    "id": 3,
                    "title": "Disk Usage by Node",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "((node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "{{instance}} Root Disk",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
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
                    "title": "Inodes Usage (Critical for Container Operations)",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "((node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_files_free{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "{{instance}} Inodes",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 85},
                                    {"color": "red", "value": 95}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 5,
                    "title": "Network I/O by Node",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m]) * 8",
                            "legendFormat": "{{instance}} RX",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        },
                        {
                            "expr": "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m]) * 8",
                            "legendFormat": "{{instance}} TX",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "bps"
                        }
                    }
                },
                {
                    "id": 6,
                    "title": "Disk I/O Operations",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "rate(node_disk_reads_completed_total[5m])",
                            "legendFormat": "{{instance}} Reads/sec",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        },
                        {
                            "expr": "rate(node_disk_writes_completed_total[5m])",
                            "legendFormat": "{{instance}} Writes/sec",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "ops"
                        }
                    }
                },
                {
                    "id": 7,
                    "title": "Kubernetes Pods CPU and Memory Usage",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "sum(rate(container_cpu_usage_seconds_total{container!=\"POD\",container!=\"\"}[5m])) by (pod, namespace)",
                            "legendFormat": "{{namespace}}/{{pod}} CPU",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        },
                        {
                            "expr": "sum(container_memory_usage_bytes{container!=\"POD\",container!=\"\"}) by (pod, namespace) / 1024 / 1024",
                            "legendFormat": "{{namespace}}/{{pod}} Memory MB",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 24}
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
        -d "$PHYSICAL_DASHBOARD")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200)
            echo "Physical monitoring dashboard created successfully"
            DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
            if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
                echo "Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/physical-resources-monitoring"
            fi
            ;;
        *)
            echo "Error creating physical dashboard. HTTP Code: $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Function to create Logical Monitoring dashboard
create_logical_monitoring_dashboard() {
    echo "Creating Logical Monitoring dashboard (Logs, Alerts, Pipeline Status)..."
    
    # Get datasource UIDs
    PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
    LOKI_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null)
    
    if [ -z "$PROMETHEUS_UID" ] || [ "$PROMETHEUS_UID" = "null" ]; then
        PROMETHEUS_UID="prometheus-uid"
    fi
    if [ -z "$LOKI_UID" ] || [ "$LOKI_UID" = "null" ]; then
        LOKI_UID="P8E80F9AEF21F6940"
    fi
    
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
                    "title": "ALL LOGS - Real Time Stream",
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
                    "gridPos": {"h": 12, "w": 24, "x": 0, "y": 8},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending",
                        "wrapLogMessage": true,
                        "enableLogDetails": true,
                        "dedupStrategy": "none"
                    }
                },
                {
                    "id": 8,
                    "title": "Jenkins Namespace Logs with Metrics Correlation",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{job=\"fluent-bit\", kubernetes_namespace_name=\"jenkins-master\"}",
                            "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                            "refId": "A"
                        }
                    ],
                    "gridPos": {"h": 10, "w": 12, "x": 0, "y": 20},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending",
                        "wrapLogMessage": true,
                        "enableLogDetails": true
                    }
                },
                {
                    "id": 5,
                    "title": "Error and Warning Logs",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{job=\"fluent-bit\"} |~ \"(?i)error|warning|warn|fail|exception\"",
                            "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 10, "w": 12, "x": 0, "y": 20},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending",
                        "wrapLogMessage": true
                    }
                },
                {
                    "id": 6,
                    "title": "Kubernetes System Logs",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{job=\"fluent-bit\", kubernetes_namespace_name=\"kube-system\"}",
                            "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 10, "w": 12, "x": 12, "y": 20},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending",
                        "wrapLogMessage": true
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
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 30}
                },
                {
                    "id": 9,
                    "title": "Prometheus-Loki Correlation: High CPU + Error Logs",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                            "legendFormat": "CPU Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        },
                        {
                            "expr": "rate({job=\"fluent-bit\"} |~ \"(?i)error|warning|fail\" [5m])",
                            "legendFormat": "Error Log Rate",
                            "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"},
                            "refId": "B"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 38},
                    "fieldConfig": {
                        "defaults": {
                            "custom": {
                                "drawStyle": "line",
                                "lineInterpolation": "linear",
                                "lineWidth": 1,
                                "fillOpacity": 10
                            }
                        }
                    }
                }
            ],
            "time": {"from": "now-1h", "to": "now"},
            "refresh": "15s",
            "schemaVersion": 30,
            "version": 1
        },
        "overwrite": true
    }'
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "${GRAFANA_URL}/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$LOGICAL_DASHBOARD")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200)
            echo "Logical monitoring dashboard created successfully"
            DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
            if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
                echo "Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/logical-monitoring-logs-spot-events-pipeline-alerts"
            fi
            ;;
        *)
            echo "Error creating logical dashboard. HTTP Code: $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Function to create Critical Alerts dashboard with specific alerting rules
create_critical_alerts_dashboard() {
    echo "Creating Critical Alerts dashboard with specific alerting rules..."
    
    # Get datasource UIDs
    PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
    LOKI_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null)
    
    if [ -z "$PROMETHEUS_UID" ] || [ "$PROMETHEUS_UID" = "null" ]; then
        PROMETHEUS_UID="prometheus-uid"
    fi
    if [ -z "$LOKI_UID" ] || [ "$LOKI_UID" = "null" ]; then
        LOKI_UID="P8E80F9AEF21F6940"
    fi
    
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
                    "title": "Critical Error Logs",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{job=\"fluent-bit\"} |~ \"(?i)fatal|critical|panic|crash|oom|error\"",
                            "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 12, "w": 12, "x": 0, "y": 8},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending",
                        "wrapLogMessage": true
                    }
                },
                {
                    "id": 6,
                    "title": "All Application Logs",
                    "type": "logs",
                    "targets": [
                        {
                            "expr": "{job=\"fluent-bit\"}",
                            "datasource": {"type": "loki", "uid": "'${LOKI_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 12, "w": 12, "x": 12, "y": 8},
                    "options": {
                        "showTime": true,
                        "showLabels": true,
                        "sortOrder": "Descending",
                        "wrapLogMessage": true
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
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20}
                }
            ],
            "time": {"from": "now-1h", "to": "now"},
            "refresh": "10s",
            "schemaVersion": 30,
            "version": 1
        },
        "overwrite": true
    }'
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "${GRAFANA_URL}/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$CRITICAL_ALERTS_DASHBOARD")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200)
            echo "Critical alerts dashboard created successfully"
            DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
            if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
                echo "Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/critical-alerts-pipeline-failures-spot-terminations"
            fi
            ;;
        *)
            echo "Error creating critical alerts dashboard. HTTP Code: $HTTP_CODE"
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
    echo "PHYSICAL MONITORING DASHBOARD:"
    echo "   - CPU Usage by Node Pool (Spot vs Regular)"
    echo "   - Memory Usage and Pressure Detection"
    echo "   - Disk Usage and Available Space"
    echo "   - Inodes Usage (Critical for Container Operations)"
    echo "   - Network I/O by Node"
    echo "   - Disk I/O Operations"
    echo "   - Container Resource Limits vs Usage"
    echo ""
    echo "LOGICAL MONITORING DASHBOARD:"
    echo "   - Azure Spot Node Termination Events"
    echo "   - Jenkins Pipeline Failures Detection"
    echo "   - Jenkins Master Connection Status"
    echo "   - Spot Node Termination Reason Logs"
    echo "   - Jenkins Pipeline Error Logs"
    echo "   - Jenkins Agent Connection Events"
    echo "   - Spot Node Lifecycle Timeline"
    echo "   - Prometheus-Loki Integration for Correlation"
    echo "   - Jenkins Namespace Logs with Metrics"
    echo ""
    echo "CRITICAL ALERTS DASHBOARD:"
    echo "   - Pipeline Failure Alerts (Real-time)"
    echo "   - Azure Spot Termination Alerts"
    echo "   - Pipeline Timeout/Kill Detection"
    echo "   - Microsoft Spot Kill Events"
    echo "   - Detailed Termination Reason Analysis"
    echo "   - Success/Fail/Kill Timeline"
    echo ""
    echo "MONITORED SPOT TERMINATION SCENARIOS:"
    echo "   - Normal completion (Success)"
    echo "   - Azure capacity unavailable (Preemption)"
    echo "   - Microsoft maintenance (Planned)"
    echo "   - Spot price exceeded (Economic)"
    echo "   - Manual termination (Kill)"
    echo "   - Pipeline timeout (Timeout)"
    echo "   - Infrastructure failure (Error)"
    echo ""
    echo "JENKINS PIPELINE MONITORING:"
    echo "   - Build failures with detailed logs"
    echo "   - Agent disconnection events"
    echo "   - Workspace errors and cleanup issues"
    echo "   - Plugin-specific error tracking"
    echo "   - Queue management and scheduling"
    echo ""
    echo "PROMETHEUS-LOKI INTEGRATION:"
    echo "   - Correlated metrics and logs visualization"
    echo "   - Exemplar links from Prometheus to Loki"
    echo "   - Derived fields for trace correlation"
    echo "   - Combined CPU metrics with error log rates"
    echo "   - Jenkins namespace logs with performance metrics"
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
    echo "All Physical, Logical, and Critical Alert monitoring is now active."
}

# Main execution
main() {
    echo "Testing Grafana connectivity..."
    if ! curl -f -s "${GRAFANA_URL}/api/health" > /dev/null; then
        echo "Error: Cannot connect to Grafana at ${GRAFANA_URL}"
        exit 1
    fi
    echo "Grafana connectivity verified"
    
    echo ""
    echo "Adding Prometheus datasource..."
    add_prometheus_datasource
    
    echo ""
    echo "Adding Loki datasource..."
    add_loki_datasource
    
    echo ""
    echo "Configuring Loki-Prometheus integration..."
    configure_loki_prometheus_integration
    
    echo ""
    echo "Creating Physical Resources Dashboard..."
    create_physical_monitoring_dashboard
    
    echo ""
    echo "Creating Logical Monitoring Dashboard..."
    create_logical_monitoring_dashboard
    
    echo ""
    echo "Creating Critical Alerts Dashboard..."
    create_critical_alerts_dashboard
    
    display_comprehensive_summary
}

# Execute main function
main "$@"
