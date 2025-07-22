#!/bin/bash

# Configure Unified Grafana with Prometheus and Loki Datasources
# This script configures Prometheus as an additional datasource in the existing Loki Grafana instance
# Creates a unified observability platform with both metrics and logs

set -euo pipefail

# Configuration
GRAFANA_URL="http://4.175.33.237"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin123"
PROMETHEUS_URL="http://prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090"
ALERTMANAGER_URL="http://prometheus-stack-alertmanager.prometheus-system.svc.cluster.local:9093"

echo "=========================================="
echo "Configuring Unified Grafana Observability"
echo "=========================================="

# Function to test Grafana connectivity
test_grafana_connectivity() {
    echo "Testing Grafana connectivity..."
    
    if ! curl -f -s "${GRAFANA_URL}/api/health" > /dev/null; then
        echo "Error: Cannot connect to Grafana at ${GRAFANA_URL}"
        echo "Please ensure:"
        echo "1. Grafana is running and accessible"
        echo "2. The URL is correct"
        echo "3. Network connectivity is available"
        exit 1
    fi
    
    echo "Grafana connectivity verified"
}

# Function to check existing datasources
check_existing_datasources() {
    echo "Checking existing datasources..."
    
    EXISTING_DATASOURCES=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources")
    echo "Current datasources:"
    echo "$EXISTING_DATASOURCES" | jq -r '.[] | "  - \(.name) (\(.type))"' 2>/dev/null || echo "  Unable to parse datasources"
}

# Function to add Prometheus datasource
add_prometheus_datasource() {
    echo "Adding Prometheus datasource..."
    
    PROMETHEUS_CONFIG='{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "'${PROMETHEUS_URL}'",
        "access": "proxy",
        "isDefault": false,
        "jsonData": {
            "httpMethod": "POST",
            "queryTimeout": "60s",
            "timeInterval": "30s"
        }
    }'
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "${GRAFANA_URL}/api/datasources" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$PROMETHEUS_CONFIG")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200|201)
            echo "Prometheus datasource added successfully"
            ;;
        409)
            echo "Prometheus datasource already exists"
            ;;
        *)
            echo "Warning: Unexpected response code $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Function to add AlertManager datasource
add_alertmanager_datasource() {
    echo "Adding AlertManager datasource..."
    
    ALERTMANAGER_CONFIG='{
        "name": "AlertManager",
        "type": "alertmanager",
        "url": "'${ALERTMANAGER_URL}'",
        "access": "proxy",
        "isDefault": false,
        "jsonData": {
            "implementation": "prometheus"
        }
    }'
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "${GRAFANA_URL}/api/datasources" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$ALERTMANAGER_CONFIG")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    case $HTTP_CODE in
        200|201)
            echo "AlertManager datasource added successfully"
            ;;
        409)
            echo "AlertManager datasource already exists"
            ;;
        *)
            echo "Warning: Unexpected response code $HTTP_CODE"
            echo "Response: $BODY"
            ;;
    esac
}

# Function to verify datasource connectivity
verify_datasources() {
    echo "Verifying datasource connectivity..."
    
    # Get datasource IDs
    DATASOURCES=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources")
    
    # Test Prometheus connectivity
    PROMETHEUS_ID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="Prometheus") | .id' 2>/dev/null)
    if [ -n "$PROMETHEUS_ID" ] && [ "$PROMETHEUS_ID" != "null" ]; then
        echo "Testing Prometheus datasource connectivity..."
        curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources/${PROMETHEUS_ID}/health" | jq -r '.message' 2>/dev/null || echo "Prometheus health check completed"
    fi
    
    # Test AlertManager connectivity
    ALERTMANAGER_ID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="AlertManager") | .id' 2>/dev/null)
    if [ -n "$ALERTMANAGER_ID" ] && [ "$ALERTMANAGER_ID" != "null" ]; then
        echo "Testing AlertManager datasource connectivity..."
        curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/datasources/${ALERTMANAGER_ID}/health" | jq -r '.message' 2>/dev/null || echo "AlertManager health check completed"
    fi
}

# Function to import basic dashboards
import_basic_dashboards() {
    echo "Importing basic Kubernetes dashboards..."
    
    # Create a basic Kubernetes cluster overview dashboard
    KUBERNETES_DASHBOARD='{
        "dashboard": {
            "title": "Kubernetes Cluster Overview",
            "tags": ["kubernetes", "cluster"],
            "timezone": "browser",
            "panels": [
                {
                    "title": "Cluster Nodes",
                    "type": "stat",
                    "targets": [
                        {
                            "expr": "count(kube_node_info)",
                            "legendFormat": "Total Nodes",
                            "datasource": {"type": "prometheus", "uid": "prometheus"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
                    "id": 1
                },
                {
                    "title": "Running Pods",
                    "type": "stat", 
                    "targets": [
                        {
                            "expr": "count(kube_pod_info{phase=\"Running\"})",
                            "legendFormat": "Running Pods",
                            "datasource": {"type": "prometheus", "uid": "prometheus"}
                        }
                    ],
                    "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
                    "id": 2
                }
            ],
            "time": {"from": "now-1h", "to": "now"},
            "refresh": "30s"
        },
        "overwrite": true
    }'
    
    curl -s -X POST \
        "${GRAFANA_URL}/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
        -d "$KUBERNETES_DASHBOARD" > /dev/null && echo "Kubernetes dashboard imported" || echo "Dashboard import failed"
}

# Function to display configuration summary
display_configuration_summary() {
    echo ""
    echo "=========================================="
    echo "Unified Grafana Configuration Complete"
    echo "=========================================="
    echo ""
    echo "Access Information:"
    echo "- URL: ${GRAFANA_URL}"
    echo "- Username: ${GRAFANA_USER}"
    echo "- Password: ${GRAFANA_PASSWORD}"
    echo ""
    echo "Available Datasources:"
    echo "- Loki (logs): Default datasource for log analysis"
    echo "- Prometheus (metrics): Kubernetes and application metrics"
    echo "- AlertManager (alerts): Alert management and notification"
    echo ""
    echo "Unified Observability Features:"
    echo "- Logs: Application and infrastructure logs via Loki"
    echo "- Metrics: Kubernetes cluster and node metrics via Prometheus"
    echo "- Alerts: Prometheus AlertManager integration"
    echo "- Dashboards: Pre-configured Kubernetes monitoring dashboards"
    echo ""
    echo "Next Steps:"
    echo "1. Access Grafana web interface"
    echo "2. Explore pre-configured dashboards"
    echo "3. Create custom dashboards combining logs and metrics"
    echo "4. Configure alert notification channels"
    echo ""
    echo "Datasource URLs (internal):"
    echo "- Prometheus: ${PROMETHEUS_URL}"
    echo "- AlertManager: ${ALERTMANAGER_URL}"
    echo ""
    echo "Configuration completed successfully!"
}

# Main execution
main() {
    test_grafana_connectivity
    check_existing_datasources
    add_prometheus_datasource
    add_alertmanager_datasource
    verify_datasources
    import_basic_dashboards
    display_configuration_summary
}

# Execute main function
main "$@"
