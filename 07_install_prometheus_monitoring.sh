#!/bin/bash

# Install Prometheus Stack for Metrics Monitoring
# Backend-only configuration for unified observability
# Prometheus services accessed via unified Grafana instance
# Includes optional dedicated monitoring node pool creation

set -euo pipefail

# Source common functions
source ./common.sh

# Configuration
NAMESPACE="prometheus-system"
CHART_NAME="prometheus-community/kube-prometheus-stack"
RELEASE_NAME="prometheus-stack"
VALUES_FILE="./helm/prometheus_helm_values.yaml"

# Node pool configuration
MONITORING_NODEPOOL_NAME="monitoring"
NODE_COUNT=1
NODE_SIZE="Standard_D4s_v3"  # 4 vCPUs, 16GB RAM - good for monitoring
NODE_DISK_SIZE=100

echo "=========================================="
echo "Installing Prometheus Stack (Backend Only)"
echo "=========================================="

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v helm &> /dev/null; then
        echo "Error: Helm is not installed"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed"
        exit 1
    fi
    
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "Error: Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    if [ ! -f "$VALUES_FILE" ]; then
        echo "Error: Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    # Load environment variables for Azure operations
    if [ -f .env.production ]; then
        source .env.production
    else
        echo "Warning: .env.production not found - node pool creation will be skipped"
    fi
    
    echo "Prerequisites check passed"
}

# Function to create monitoring node pool
create_monitoring_nodepool() {
    echo "Creating dedicated monitoring node pool..."
    
    # Check if environment variables are available
    if [ -z "${RESOURCE_GROUP:-}" ] || [ -z "${CLUSTER_NAME:-}" ]; then
        echo "Warning: RESOURCE_GROUP or CLUSTER_NAME not set. Skipping node pool creation."
        echo "To create a monitoring node pool, ensure .env.production has:"
        echo "- RESOURCE_GROUP=your-resource-group"
        echo "- CLUSTER_NAME=your-cluster-name"
        return 0
    fi
    
    # Check if already exists
    if az aks nodepool show --resource-group "${RESOURCE_GROUP}" --cluster-name "${CLUSTER_NAME}" --name "${MONITORING_NODEPOOL_NAME}" &>/dev/null; then
        echo "Monitoring node pool already exists"
        echo "Nodes in monitoring pool:"
        kubectl get nodes -l agentpool=monitoring -o wide
        return 0
    fi
    
    echo "Node pool configuration:"
    echo "- Name: ${MONITORING_NODEPOOL_NAME}"
    echo "- Size: ${NODE_SIZE} (4 vCPUs, 16GB RAM)"
    echo "- Count: ${NODE_COUNT}"
    echo "- Disk: ${NODE_DISK_SIZE}GB"
    echo ""
    
    echo "Creating monitoring node pool..."
    
    az aks nodepool add \
        --resource-group "${RESOURCE_GROUP}" \
        --cluster-name "${CLUSTER_NAME}" \
        --name "${MONITORING_NODEPOOL_NAME}" \
        --node-count ${NODE_COUNT} \
        --node-vm-size "${NODE_SIZE}" \
        --node-osdisk-size ${NODE_DISK_SIZE} \
        --mode User \
        --node-taints "monitoring=true:NoSchedule" \
        --labels agentpool=monitoring \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 2
    
    echo "Monitoring node pool created successfully"
    
    # Wait for node to be ready
    echo "Waiting for monitoring node to be ready..."
    sleep 30
    
    echo "Monitoring nodes:"
    kubectl get nodes -l agentpool=monitoring -o wide
    
    echo "Node taints:"
    kubectl get nodes -l agentpool=monitoring -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
}

# Add Prometheus Helm repository
add_helm_repo() {
    echo "Adding Prometheus community Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    echo "Helm repository added and updated"
}

# Create namespace
create_namespace() {
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    echo "Namespace created or already exists"
}

# Install Prometheus stack
install_prometheus() {
    echo "Installing Prometheus stack..."
    echo "Release: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE" 
    echo "Values file: $VALUES_FILE"
    
    helm upgrade --install $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout=10m
    
    echo "Prometheus stack installation completed"
}

# Verify installation
verify_installation() {
    echo "Verifying Prometheus stack installation..."
    
    # Wait for pods to be ready
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pods --all -n $NAMESPACE --timeout=300s
    
    # Check pod status
    echo "Checking pod status:"
    kubectl get pods -n $NAMESPACE
    
    # Check services
    echo "Checking services:"
    kubectl get services -n $NAMESPACE
    
    # Check PVCs
    echo "Checking persistent volume claims:"
    kubectl get pvc -n $NAMESPACE
    
    # Verify Prometheus is accessible
    echo "Verifying Prometheus accessibility..."
    PROMETHEUS_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$PROMETHEUS_POD" ]; then
        echo "Prometheus pod found: $PROMETHEUS_POD"
        # Test internal connectivity
        kubectl exec -n $NAMESPACE $PROMETHEUS_POD -- wget -qO- http://localhost:9090/api/v1/status/config | head -10
        echo "Prometheus is responding correctly"
    else
        echo "Warning: Prometheus pod not found"
    fi
    
    echo "Verification completed"
}

# Display access information
display_access_info() {
    echo "=========================================="
    echo "Prometheus Stack Installation Complete"
    echo "=========================================="
    echo ""
    echo "Backend Services (Internal Access Only):"
    echo "- Prometheus Server: ClusterIP service only"
    echo "- AlertManager: ClusterIP service only"
    echo "- Access via unified Grafana: http://4.175.33.237"
    echo ""
    echo "Internal Service URLs:"
    kubectl get services -n $NAMESPACE -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORT:.spec.ports[0].port"
    echo ""
    echo "Grafana Datasource Configuration:"
    echo "- Prometheus URL: http://prometheus-stack-kube-prom-prometheus.prometheus-system.svc.cluster.local:9090"
    echo "- AlertManager URL: http://prometheus-stack-kube-prom-alertmanager.prometheus-system.svc.cluster.local:9093"
    echo ""
    echo "Node Configuration:"
    echo "- monitoring nodes: Prometheus, AlertManager (if dedicated pool created)"
    echo "- regular nodes: Jenkins Master, Grafana, Loki"
    echo "- spot nodes: Jenkins Workers"
    echo "- system nodes: Kubernetes system components"
    echo ""
    echo "Next steps:"
    echo "1. Configure Prometheus datasource in unified Grafana"
    echo "2. Import Kubernetes dashboards"
    echo "3. Set up alerting rules"
    echo "4. Verify monitoring stack is collecting metrics"
}

# Ask user about node pool creation
ask_nodepool_creation() {
    if [ -z "${RESOURCE_GROUP:-}" ] || [ -z "${CLUSTER_NAME:-}" ]; then
        echo "Skipping node pool creation (environment variables not set)"
        return 1
    fi
    
    echo ""
    echo "Do you want to create a dedicated monitoring node pool? (y/N)"
    read -r response
    case $response in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            echo "Skipping dedicated node pool creation"
            return 1
            ;;
    esac
}

# Main execution
main() {
    check_prerequisites
    
    # Ask about node pool creation before installation
    if ask_nodepool_creation; then
        create_monitoring_nodepool
        echo ""
    fi
    
    add_helm_repo
    create_namespace
    install_prometheus
    verify_installation
    display_access_info
}

# Run main function
main