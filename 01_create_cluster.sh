#!/bin/bash

# STEP 1: CREATE AKS CLUSTER WITH SPOT AND REGULAR NODES

set -e

# Load common functions
source ./common.sh

echo "Creating AKS cluster with spot node support"
echo "============================================"

# Check prerequisites
check_prerequisites || exit 1
check_azure_login || exit 1

# Load configuration
load_env

# Initial configuration if required
if ! check_env "RESOURCE_GROUP" || ! check_env "CLUSTER_NAME"; then
    echo "Initial configuration required..."
    setup_initial_config
    load_env
fi

# Validate configuration for this step
validate_step "cluster" || exit 1

log "INFO" "Starting AKS cluster creation..."

# Create configuration backup
backup_env

# === STEP 1.1: CREATE RESOURCE GROUP ===
log "INFO" "Creating Resource Group: $RESOURCE_GROUP"

if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "WARNING" "Resource Group $RESOURCE_GROUP already exists"
else
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION"
    
    log "SUCCESS" "Resource Group created: $RESOURCE_GROUP"
fi

# === STEP 1.2: CREATE VIRTUAL NETWORK ===
log "INFO" "Creating virtual network: $VNET_NAME"

if az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" >/dev/null 2>&1; then
    log "WARNING" "VNet $VNET_NAME already exists"
else
    az network vnet create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        --address-prefixes "$VNET_CIDR" \
        --subnet-name "$SUBNET_NAME" \
        --subnet-prefixes "$SUBNET_CIDR"
    
    log "SUCCESS" "Virtual network created: $VNET_NAME"
fi

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query id -o tsv)

update_env "SUBNET_ID" "$SUBNET_ID"
log "INFO" "Subnet ID obtained: $SUBNET_ID"

# === STEP 1.3: CREATE AKS CLUSTER ===
log "INFO" "Creating AKS cluster: $CLUSTER_NAME"

if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    log "WARNING" "AKS cluster $CLUSTER_NAME already exists"
else
    # Create cluster with system node pool
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --node-count "$SYSTEM_NODE_COUNT" \
        --node-vm-size "$NODE_SIZE" \
        --vnet-subnet-id "$SUBNET_ID" \
        --nodepool-name "system" \
        --nodepool-labels "nodepool=system" \
        --enable-managed-identity \
        --enable-addons monitoring \
        --generate-ssh-keys \
        --node-osdisk-type Managed \
        --node-osdisk-size 50 \
        --max-pods 50 \
        --network-plugin azure \
        --service-cidr 10.2.0.0/24 \
        --dns-service-ip 10.2.0.10 \
        --yes
    
    log "SUCCESS" "AKS cluster created: $CLUSTER_NAME"
fi

# === STEP 1.4: CONFIGURE KUBECONFIG ===
log "INFO" "Configuring kubeconfig..."

az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing

# Verify connection
if kubectl cluster-info >/dev/null 2>&1; then
    log "SUCCESS" "AKS connection established"
    
    # Get cluster endpoint
    CLUSTER_ENDPOINT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    update_env "CLUSTER_ENDPOINT" "$CLUSTER_ENDPOINT"
    update_env "KUBECONFIG_PATH" "$HOME/.kube/config"
else
    log "ERROR" "Could not connect to AKS cluster"
    exit 1
fi

# === STEP 1.5: ADD REGULAR NODE POOL ===
log "INFO" "Adding regular node pool..."

if az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name "regular" >/dev/null 2>&1; then
    log "WARNING" "Node pool 'regular' already exists"
else
    az aks nodepool add \
        --resource-group "$RESOURCE_GROUP" \
        --cluster-name "$CLUSTER_NAME" \
        --name "regular" \
        --node-count "$REGULAR_NODE_COUNT" \
        --node-vm-size "$NODE_SIZE" \
        --vnet-subnet-id "$SUBNET_ID" \
        --labels "nodepool=regular" \
        --node-taints "nodepool=regular:NoSchedule" \
        --max-pods 50 \
        --node-osdisk-type Managed \
        --node-osdisk-size 50
    
    log "SUCCESS" "Regular node pool added"
fi

# === STEP 1.6: ADD SPOT NODE POOL ===
log "INFO" "Adding spot node pool..."

if az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name "spot" >/dev/null 2>&1; then
    log "WARNING" "Node pool 'spot' already exists"
else
    # Check quota before creating
    log "INFO" "Checking Low Priority Cores quota..."
    echo "NOTE: This cluster will use 0-$SPOT_MAX_COUNT spot node(s) with auto-scaling"
    echo "   Maximum spot cores required: $((SPOT_MAX_COUNT * 2)) (available quota: 3)"
    echo "   If quota error occurs, adjust SPOT_MAX_COUNT in .env"
    
    # Use min-count=0 for spot nodes (scale from zero)
    az aks nodepool add \
        --resource-group "$RESOURCE_GROUP" \
        --cluster-name "$CLUSTER_NAME" \
        --name "spot" \
        --priority Spot \
        --eviction-policy Delete \
        --spot-max-price -1 \
        --enable-cluster-autoscaler \
        --min-count 0 \
        --max-count "$SPOT_MAX_COUNT" \
        --node-count 0 \
        --node-vm-size "$SPOT_NODE_SIZE" \
        --vnet-subnet-id "$SUBNET_ID" \
        --labels "nodepool=spot" \
        --node-taints "kubernetes.azure.com/scalesetpriority=spot:NoSchedule" \
        --max-pods 50 \
        --node-osdisk-type Managed \
        --node-osdisk-size 30
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Spot node pool added"
    else
        log "ERROR" "Error creating spot node pool - possible quota issue"
        echo ""
        echo "QUOTA ERROR SOLUTIONS:"
        echo "====================="
        echo "1. Reduce SPOT_MAX_COUNT in .env (current: $SPOT_MAX_COUNT)"
        echo "2. Change to smaller VM (e.g., Standard_B2s = 2 cores)"
        echo "3. Request quota increase in Azure Portal"
        echo ""
        echo "To continue without spot nodes, system will work with regular nodes only."
        read -p "Continue without spot nodes? (y/n): " continue_without_spot
        if [[ ! $continue_without_spot =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# === STEP 1.7: VERIFY NODES ===
log "INFO" "Verifying cluster nodes..."

echo ""
echo "NODE STATUS:"
echo "============"
kubectl get nodes -o wide

echo ""
echo "NODE LABELS:"
echo "============"
kubectl get nodes --show-labels

echo ""
echo "CLUSTER SUMMARY:"
echo "================"
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
SYSTEM_NODES=$(kubectl get nodes -l nodepool=system --no-headers | wc -l)
REGULAR_NODES=$(kubectl get nodes -l nodepool=regular --no-headers | wc -l)
SPOT_NODES=$(kubectl get nodes -l nodepool=spot --no-headers | wc -l)

echo "Total nodes: $TOTAL_NODES"
echo "System nodes: $SYSTEM_NODES"
echo "Regular nodes: $REGULAR_NODES (for Jenkins Master)"
echo "Spot nodes: $SPOT_NODES (for Jenkins Workers - 90% cost savings)"

# === STEP 1.8: UPDATE CONFIGURATION ===
update_env "CLUSTER_CREATED" "true"
update_env "TOTAL_NODES" "$TOTAL_NODES"
update_env "SYSTEM_NODES" "$SYSTEM_NODES"
update_env "REGULAR_NODES" "$REGULAR_NODES"
update_env "SPOT_NODES" "$SPOT_NODES"

log "SUCCESS" "AKS cluster created successfully"

echo ""
echo "NEXT STEP:"
echo "=========="
echo "Execute: ./02_deploy_jenkins.sh"
echo ""
