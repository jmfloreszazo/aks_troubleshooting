#!/bin/bash

# Dashboard de Troubleshooting de Disco, Inodos y Memoria
# Especializado en diagnosticar problemas cuando el espacio en disco está al 70% pero los inodos al 100%

set -euo pipefail

# Configuration
GRAFANA_URL="http://135.236.73.36"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"

echo "=========================================="
echo "Creating Disk & Inode Troubleshooting Dashboard"
echo "=========================================="

# Function to add Prometheus datasource if not exists
add_prometheus_datasource() {
    echo "Checking Prometheus datasource..."
    
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
                PROMETHEUS_UID=$(echo "$BODY" | jq -r '.datasource.uid // .uid' 2>/dev/null)
                echo "Prometheus UID: $PROMETHEUS_UID"
                ;;
            *)
                echo "Warning: Could not add Prometheus datasource. HTTP Code: $HTTP_CODE"
                PROMETHEUS_UID="prometheus-uid"
                ;;
        esac
    else
        echo "Prometheus datasource already exists with UID: $PROMETHEUS_DS"
        PROMETHEUS_UID="$PROMETHEUS_DS"
    fi
}

# Function to create Disk & Inode Troubleshooting dashboard
create_disk_troubleshooting_dashboard() {
    echo "Creating Disk & Inode Troubleshooting dashboard..."
    
    # Get Prometheus datasource UID
    PROMETHEUS_UID=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources" | jq -r '.[] | select(.type=="prometheus") | .uid' 2>/dev/null)
    if [ -z "$PROMETHEUS_UID" ] || [ "$PROMETHEUS_UID" = "null" ]; then
        PROMETHEUS_UID="prometheus-uid"
    fi
    
    DISK_TROUBLESHOOTING_DASHBOARD='{
        "dashboard": {
            "id": null,
            "title": "DISK & INODE TROUBLESHOOTING - Memory, Space & Inode Analysis",
            "tags": ["troubleshooting", "disk", "inodes", "memory", "forensics", "prometheus-datasource"],
            "timezone": "browser",
            "panels": [
                {
                    "id": 1,
                    "title": "🚨 CRITICAL - Disk Space vs Inodes Usage",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "((node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "{{instance}} - Disk Space %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        },
                        {
                            "expr": "((node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_files_free{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "{{instance}} - Inodes %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}
                        }
                    ],
                    "gridPos": {"h": 10, "w": 24, "x": 0, "y": 0},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 70},
                                    {"color": "orange", "value": 85},
                                    {"color": "red", "value": 95}
                                ]
                            }
                        }
                    },
                    "alert": {
                        "alertRuleTags": {},
                        "conditions": [
                            {
                                "evaluator": {
                                    "params": [95],
                                    "type": "gt"
                                },
                                "operator": {
                                    "type": "and"
                                },
                                "query": {
                                    "params": ["A", "5m", "now"]
                                },
                                "reducer": {
                                    "params": [],
                                    "type": "last"
                                },
                                "type": "query"
                            }
                        ],
                        "executionErrorState": "alerting",
                        "for": "5m",
                        "frequency": "10s",
                        "handler": 1,
                        "name": "Critical Inode Usage",
                        "noDataState": "no_data",
                        "notifications": []
                    }
                },
                {
                    "id": 2,
                    "title": "📊 Current Status - Space vs Inodes",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "((node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "Disk Space Used %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 0, "y": 10},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 70},
                                    {"color": "orange", "value": 85},
                                    {"color": "red", "value": 95}
                                ]
                            },
                            "unit": "percent",
                            "min": 0,
                            "max": 100
                        }
                    },
                    "options": {
                        "orientation": "auto",
                        "reduceOptions": {
                            "values": false,
                            "calcs": ["lastNotNull"],
                            "fields": ""
                        },
                        "textMode": "auto"
                    }
                },
                {
                    "id": 3,
                    "title": "⚠️ Inodes Usage %",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "((node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_files_free{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "Inodes Used %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 6, "y": 10},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 80},
                                    {"color": "orange", "value": 90},
                                    {"color": "red", "value": 95}
                                ]
                            },
                            "unit": "percent",
                            "min": 0,
                            "max": 100
                        }
                    }
                },
                {
                    "id": 4,
                    "title": "💾 Memory Usage %",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100",
                            "legendFormat": "Memory Used %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "C"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 12, "y": 10},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 80},
                                    {"color": "orange", "value": 90},
                                    {"color": "red", "value": 95}
                                ]
                            },
                            "unit": "percent",
                            "min": 0,
                            "max": 100
                        }
                    }
                },
                {
                    "id": 5,
                    "title": "🔥 Container Restarts (May indicate resource issues)",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "sum(increase(kube_pod_container_status_restarts_total[1h]))",
                            "legendFormat": "Restarts Last Hour",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "D"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 18, "y": 10},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 3},
                                    {"color": "red", "value": 10}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 6,
                    "title": "🔍 DIAGNOSTIC - Detailed Inode Analysis by Filesystem",
                    "type": "table",
                    "targets": [
                        {
                            "expr": "node_filesystem_files{fstype!=\"tmpfs\"}",
                            "legendFormat": "{{instance}} {{mountpoint}} Total",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        },
                        {
                            "expr": "node_filesystem_files_free{fstype!=\"tmpfs\"}",
                            "legendFormat": "{{instance}} {{mountpoint}} Free",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        },
                        {
                            "expr": "((node_filesystem_files{fstype!=\"tmpfs\"} - node_filesystem_files_free{fstype!=\"tmpfs\"}) / node_filesystem_files{fstype!=\"tmpfs\"}) * 100",
                            "legendFormat": "{{instance}} {{mountpoint}} Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "C"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 18},
                    "options": {
                        "showHeader": true
                    },
                    "fieldConfig": {
                        "defaults": {
                            "custom": {
                                "align": "auto",
                                "displayMode": "auto"
                            },
                            "mappings": [],
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
                    "id": 7,
                    "title": "📁 DIAGNOSTIC - Detailed Disk Space Analysis by Filesystem",
                    "type": "table",
                    "targets": [
                        {
                            "expr": "node_filesystem_size_bytes{fstype!=\"tmpfs\"} / 1024 / 1024 / 1024",
                            "legendFormat": "{{instance}} {{mountpoint}} Size GB",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        },
                        {
                            "expr": "node_filesystem_free_bytes{fstype!=\"tmpfs\"} / 1024 / 1024 / 1024",
                            "legendFormat": "{{instance}} {{mountpoint}} Free GB",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        },
                        {
                            "expr": "((node_filesystem_size_bytes{fstype!=\"tmpfs\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\"}) * 100",
                            "legendFormat": "{{instance}} {{mountpoint}} Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "C"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 18},
                    "options": {
                        "showHeader": true
                    },
                    "fieldConfig": {
                        "defaults": {
                            "custom": {
                                "align": "auto",
                                "displayMode": "auto"
                            },
                            "mappings": [],
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 70},
                                    {"color": "red", "value": 85}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 8,
                    "title": "⚡ CORRELATION - Memory Pressure vs Disk I/O",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100",
                            "legendFormat": "{{instance}} Memory Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        },
                        {
                            "expr": "rate(node_disk_writes_completed_total[5m]) * 10",
                            "legendFormat": "{{instance}} Disk Writes/sec x10",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        },
                        {
                            "expr": "rate(node_disk_reads_completed_total[5m]) * 10",
                            "legendFormat": "{{instance}} Disk Reads/sec x10",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "C"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 26},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent"
                        }
                    }
                },
                {
                    "id": 9,
                    "title": "🐳 KUBERNETES CONTAINERS - Resource Usage vs Limits",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "sum by (namespace, pod) (container_memory_usage_bytes{container!=\"POD\",container!=\"\"}) / 1024 / 1024",
                            "legendFormat": "{{namespace}}/{{pod}} Memory MB",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        },
                        {
                            "expr": "sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=\"POD\",container!=\"\"}[5m])) * 1000",
                            "legendFormat": "{{namespace}}/{{pod}} CPU millicores",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 34}
                },
                {
                    "id": 10,
                    "title": "📈 TREND ANALYSIS - Resource Usage Over Time",
                    "type": "timeseries",
                    "targets": [
                        {
                            "expr": "((node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_files_free{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "{{instance}} Inode Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        },
                        {
                            "expr": "((node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100",
                            "legendFormat": "{{instance}} Disk Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        },
                        {
                            "expr": "((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100",
                            "legendFormat": "{{instance}} Memory Usage %",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "C"
                        }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 42},
                    "fieldConfig": {
                        "defaults": {
                            "unit": "percent",
                            "custom": {
                                "drawStyle": "line",
                                "lineInterpolation": "linear",
                                "lineWidth": 2,
                                "fillOpacity": 10
                            }
                        }
                    }
                },
                {
                    "id": 11,
                    "title": "🚨 ALERT CONDITIONS - Critical Thresholds",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(((node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_files_free{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_files{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100 > 95)",
                            "legendFormat": "Nodes with Inodes > 95%",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "A"
                        }
                    ],
                    "gridPos": {"h": 6, "w": 6, "x": 0, "y": 50},
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
                    "id": 12,
                    "title": "⚠️ Nodes with Disk > 70%",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(((node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"} - node_filesystem_free_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) / node_filesystem_size_bytes{fstype!=\"tmpfs\",mountpoint=\"/\"}) * 100 > 70)",
                            "legendFormat": "Nodes with Disk > 70%",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "B"
                        }
                    ],
                    "gridPos": {"h": 6, "w": 6, "x": 6, "y": 50},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 1},
                                    {"color": "red", "value": 2}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 13,
                    "title": "💾 Nodes with Memory > 90%",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100 > 90)",
                            "legendFormat": "Nodes with Memory > 90%",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "C"
                        }
                    ],
                    "gridPos": {"h": 6, "w": 6, "x": 12, "y": 50},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "orange", "value": 1},
                                    {"color": "red", "value": 2}
                                ]
                            }
                        }
                    }
                },
                {
                    "id": 14,
                    "title": "🔄 Pod Restarts in Last 4h",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "sum(increase(kube_pod_container_status_restarts_total[4h]))",
                            "legendFormat": "Total Restarts 4h",
                            "datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"},
                            "refId": "D"
                        }
                    ],
                    "gridPos": {"h": 6, "w": 6, "x": 18, "y": 50},
                    "fieldConfig": {
                        "defaults": {
                            "color": {"mode": "thresholds"},
                            "thresholds": {
                                "steps": [
                                    {"color": "green", "value": 0},
                                    {"color": "yellow", "value": 5},
                                    {"color": "red", "value": 20}
                                ]
                            }
                        }
                    }
                }
            ],
            "time": {"from": "now-6h", "to": "now"},
            "refresh": "30s",
            "schemaVersion": 30,
            "version": 1,
            "annotations": {
                "list": [
                    {
                        "builtIn": 1,
                        "datasource": "-- Grafana --",
                        "enable": true,
                        "hide": true,
                        "iconColor": "rgba(0, 211, 255, 1)",
                        "name": "Annotations & Alerts",
                        "type": "dashboard"
                    }
                ]
            }
        },
        "overwrite": true
    }'
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "${GRAFANA_URL}/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$DISK_TROUBLESHOOTING_DASHBOARD")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200)
            echo "Disk & Inode Troubleshooting dashboard created successfully"
            DASHBOARD_UID=$(echo "$BODY" | jq -r '.uid' 2>/dev/null)
            if [ -n "$DASHBOARD_UID" ] && [ "$DASHBOARD_UID" != "null" ]; then
                echo "Dashboard URL: ${GRAFANA_URL}/d/${DASHBOARD_UID}/disk-inode-troubleshooting"
            fi
            ;;
        *)
            echo "Error creating disk troubleshooting dashboard. HTTP Code: $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Function to display summary and troubleshooting tips
display_troubleshooting_summary() {
    echo ""
    echo "============================================="
    echo "Disk & Inode Troubleshooting Dashboard Created"
    echo "============================================="
    echo ""
    echo "🎯 DASHBOARD FEATURES:"
    echo "   - Real-time comparison: Disk Space vs Inodes"
    echo "   - Critical alerts when inodes reach 100%"
    echo "   - Memory correlation analysis"
    echo "   - Container resource monitoring"
    echo "   - Detailed filesystem breakdown"
    echo "   - Trend analysis over time"
    echo ""
    echo "🔍 PROBLEM DIAGNOSIS:"
    echo "   Scenario: Disk 70% but Inodes 100%"
    echo "   ├── Many small files created (logs, cache, temp files)"
    echo "   ├── Container image layers accumulation"
    echo "   ├── Kubernetes ephemeral storage issues"
    echo "   └── Application creating too many small files"
    echo ""
    echo "🚨 CRITICAL SCENARIOS MONITORED:"
    echo "   ✅ Inode usage > 95% (RED ALERT)"
    echo "   ⚠️  Disk usage > 70% (WARNING)"
    echo "   💾 Memory usage > 90% (CAUTION)"
    echo "   🔄 Excessive pod restarts (CORRELATION)"
    echo ""
    echo "🛠️ TROUBLESHOOTING ACTIONS:"
    echo "   1. Check container logs accumulation"
    echo "   2. Verify /tmp directory cleanup"
    echo "   3. Monitor Docker image layer cleanup"
    echo "   4. Check Kubernetes ephemeral storage"
    echo "   5. Analyze application file creation patterns"
    echo ""
    echo "📊 KEY METRICS TO WATCH:"
    echo "   - Inodes vs Disk Space correlation"
    echo "   - Memory pressure vs I/O operations"
    echo "   - Container restart patterns"
    echo "   - Filesystem-specific usage details"
    echo ""
    echo "Access Information:"
    echo "- Grafana URL: ${GRAFANA_URL}"
    echo "- Username: ${GRAFANA_USER}"
    echo "- Password: ${GRAFANA_PASSWORD}"
    echo ""
    echo "Setup completed successfully!"
    echo "Use this dashboard to diagnose disk/inode correlation issues."
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
    echo "Creating Disk & Inode Troubleshooting Dashboard..."
    create_disk_troubleshooting_dashboard
    
    display_troubleshooting_summary
}

# Execute main function
main "$@"
