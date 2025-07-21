#!/bin/bash

# 00_setup_subscription.sh - Azure Subscription Setup
# Initial configuration script for AKS Jenkins with Spot instances

set -e

echo "Azure Subscription Setup"
echo "========================"
echo ""

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed"
    echo "Please install Azure CLI first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in to Azure
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Not logged in to Azure. Please login first..."
    az login
else
    echo "Already logged in to Azure"
fi

echo ""
echo "Available Azure Subscriptions:"
echo "=============================="

# Get list of subscriptions with numbers
subscriptions_array=($(az account list --query '[].id' -o tsv))
subscriptions_names=($(az account list --query '[].name' -o tsv))

if [ ${#subscriptions_array[@]} -eq 0 ]; then
    echo "No subscriptions found"
    exit 1
fi

# Display numbered subscriptions
for i in "${!subscriptions_array[@]}"; do
    echo "$((i+1)). ${subscriptions_names[i]} (${subscriptions_array[i]})"
done

echo ""
current_sub_id=$(az account show --query 'id' -o tsv 2>/dev/null)
current_sub_name=$(az account show --query 'name' -o tsv 2>/dev/null)

if [ ! -z "$current_sub_id" ]; then
    echo "Current subscription: $current_sub_name ($current_sub_id)"
    
    # Find current subscription in the list
    current_index=""
    for i in "${!subscriptions_array[@]}"; do
        if [ "${subscriptions_array[i]}" = "$current_sub_id" ]; then
            current_index=$((i+1))
            break
        fi
    done
    
    if [ ! -z "$current_index" ]; then
        echo ""
        read -p "Use current subscription [$current_index]? (y/n, or enter number 1-${#subscriptions_array[@]}): " choice
        
        if [[ $choice =~ ^[Yy]$ ]] || [[ -z $choice ]]; then
            production_subscription="$current_sub_id"
        elif [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subscriptions_array[@]}" ]; then
            production_subscription="${subscriptions_array[$((choice-1))]}"
        else
            echo "Invalid selection"
            exit 1
        fi
    else
        echo ""
        read -p "Select subscription (1-${#subscriptions_array[@]}): " choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subscriptions_array[@]}" ]; then
            production_subscription="${subscriptions_array[$((choice-1))]}"
        else
            echo "Invalid selection"
            exit 1
        fi
    fi
else
    echo ""
    read -p "Select subscription (1-${#subscriptions_array[@]}): " choice
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subscriptions_array[@]}" ]; then
        production_subscription="${subscriptions_array[$((choice-1))]}"
    else
        echo "Invalid selection"
        exit 1
    fi
fi

echo "Selected subscription: $production_subscription"

# Set the subscription
echo "Setting subscription to: $production_subscription"
if az account set --subscription "$production_subscription"; then
    echo "Subscription set successfully"
else
    echo "Error: Failed to set subscription"
    exit 1
fi

echo ""
echo "Creating production configuration with your subscription..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    echo "Please ensure you are in the correct directory"
    exit 1
fi

# Create production environment file
production_file=".env.production"

# Remove existing production file if it exists
if [ -f "$production_file" ]; then
    echo "Removing existing production file: $production_file"
    rm "$production_file"
fi

cp .env "$production_file"
echo "Created production file: $production_file"

# Ask for resource naming base
echo ""
echo "Resource Naming Configuration:"
echo "=============================="
echo "Enter the base name for your resources (e.g., 'mycompany-jenkins', 'project-aks'):"
echo "This will be used to generate all resource names like:"
echo "  - Resource Group: [base-name]-rg"
echo "  - Cluster: [base-name]-cluster"
echo "  - VNet: [base-name]-vnet"
echo "  - Subnet: [base-name]-subnet"
echo ""
read -p "Base resource name [aks-jenkins-test]: " base_resource_name

# Use default if empty
if [ -z "$base_resource_name" ]; then
    base_resource_name="aks-jenkins-test"
    echo "Using default base name: $base_resource_name"
fi

# Replace TO_BE_ASKED with the base name in all resource names
echo "Updating resource names in production file..."
sed -i "s/TO_BE_ASKED/$base_resource_name/g" "$production_file"
echo "Updated all resource names with base: $base_resource_name"

# Update SUBSCRIPTION_ID in production file
echo "Updating SUBSCRIPTION_ID in production file..."
if grep -q "SUBSCRIPTION_ID=" "$production_file"; then
    # Replace existing SUBSCRIPTION_ID in production
    sed -i "s/SUBSCRIPTION_ID=.*/SUBSCRIPTION_ID=\"$production_subscription\"/" "$production_file"
    echo "Updated SUBSCRIPTION_ID in production file"
else
    # Add SUBSCRIPTION_ID at the beginning of production
    sed -i "1i SUBSCRIPTION_ID=\"$production_subscription\"" "$production_file"
    echo "Added SUBSCRIPTION_ID to production file"
fi

# Update any hardcoded subscription IDs in SUBNET_ID path in production file
echo "Updating hardcoded subscription references in production..."
sed -i "s|/subscriptions/[0-9a-f-]*/|/subscriptions/$production_subscription/|g" "$production_file"

# Update SUBNET_ID with real value in production file
echo "Updating SUBNET_ID in production file..."
resource_group=$(grep "RESOURCE_GROUP=" "$production_file" | cut -d'"' -f2)
vnet_name=$(grep "VNET_NAME=" "$production_file" | cut -d'"' -f2)
subnet_name=$(grep "SUBNET_NAME=" "$production_file" | cut -d'"' -f2)

if [ ! -z "$resource_group" ] && [ ! -z "$vnet_name" ] && [ ! -z "$subnet_name" ]; then
    real_subnet_id="/subscriptions/$production_subscription/resourceGroups/$resource_group/providers/Microsoft.Network/virtualNetworks/$vnet_name/subnets/$subnet_name"
    sed -i "s|SUBNET_ID=.*|SUBNET_ID=\"$real_subnet_id\"|" "$production_file"
    echo "Updated SUBNET_ID in production with real value"
else
    echo "Warning: Could not construct SUBNET_ID - keeping placeholder"
fi

echo ""
echo ".env file preserved as demo template (no changes made)"
echo "Production configuration created in .env.production"

echo ""
echo "Verifying subscription access..."
subscription_name=$(az account show --query 'name' -o tsv)
tenant_id=$(az account show --query 'tenantId' -o tsv)
user_name=$(az account show --query 'user.name' -o tsv)

echo ""
echo "Subscription Details:"
echo "===================="
echo "Name: $subscription_name"
echo "ID: $production_subscription"
echo "Tenant: $tenant_id"
echo "User: $user_name"

echo ""
echo "Checking resource providers..."
# Check if required resource providers are registered
required_providers=(
    "Microsoft.ContainerService"
    "Microsoft.Network"
    "Microsoft.Compute"
    "Microsoft.Storage"
)

for provider in "${required_providers[@]}"; do
    status=$(az provider show --namespace "$provider" --query 'registrationState' -o tsv 2>/dev/null || echo "NotRegistered")
    if [ "$status" = "Registered" ]; then
        echo "✓ $provider: $status"
    else
        echo "⚠ $provider: $status - Registering..."
        az provider register --namespace "$provider" --wait
        echo "✓ $provider: Registered"
    fi
done

echo ""
echo "Checking quotas in region: westeurope"
echo "====================================="

# Check key quotas
echo "Checking compute quotas..."
quotas=$(az vm list-usage --location westeurope --query '[?contains(name.value, `cores`) || contains(name.value, `Priority`)].{Name:name.localizedValue, Current:currentValue, Limit:limit}' -o table 2>/dev/null || echo "Unable to check quotas")
echo "$quotas"

echo ""
echo "Configuration Summary:"
echo "====================="
echo "✓ Azure subscription configured: $production_subscription"
echo "✓ Required resource providers registered"
echo "✓ Production file created with your subscription: $production_file"
echo "✓ Resource names configured with base: $base_resource_name"
echo ""
echo "Generated Resource Names:"
echo "========================"
echo "Resource Group: $base_resource_name-rg"
echo "Cluster Name: $base_resource_name-cluster"
echo "VNet Name: $base_resource_name-vnet"
echo "Subnet Name: $base_resource_name-subnet"

echo ""
echo "Files created/updated:"
echo "====================="
echo "Production file: $production_file (with your subscription: $production_subscription)"
echo "Demo .env: Preserved as template with placeholders"

echo ""
echo "Setup completed successfully!"
echo ""
echo "Next Steps:"
echo "==========="
echo "1. Use production file ($production_file) for your real deployment"
echo "2. Current .env remains for demo purposes"
echo "3. Execute: ./01_create_cluster.sh"
echo ""
