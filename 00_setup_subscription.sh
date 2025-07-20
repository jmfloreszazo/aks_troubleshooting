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

# Get list of subscriptions and display them
subscriptions=$(az account list --query '[].{Name:name, Id:id, State:state}' -o table)
echo "$subscriptions"

echo ""
echo "Current subscription:"
current_sub=$(az account show --query '{Name:name, Id:id}' -o table)
echo "$current_sub"

echo ""
read -p "Do you want to change the subscription? (y/n): " change_sub

if [[ $change_sub =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter the Subscription ID you want to use:"
    read -p "Subscription ID: " selected_subscription
    
    # Validate subscription ID format (basic check)
    if [[ ! $selected_subscription =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        echo "Error: Invalid subscription ID format"
        exit 1
    fi
    
    # Set the subscription
    echo "Setting subscription to: $selected_subscription"
    if az account set --subscription "$selected_subscription"; then
        echo "Subscription set successfully"
    else
        echo "Error: Failed to set subscription"
        exit 1
    fi
else
    # Use current subscription
    selected_subscription=$(az account show --query 'id' -o tsv)
    echo "Using current subscription: $selected_subscription"
fi

echo ""
echo "Updating configuration files..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    echo "Please ensure you are in the correct directory"
    exit 1
fi

# Create backup of .env file
backup_file=".env.backup.$(date +%Y%m%d_%H%M%S)"
cp .env "$backup_file"
echo "Created backup: $backup_file"

# Update SUBSCRIPTION_ID in .env file
echo "Updating SUBSCRIPTION_ID in .env..."
if grep -q "SUBSCRIPTION_ID=" .env; then
    # Replace existing SUBSCRIPTION_ID
    sed -i "s/SUBSCRIPTION_ID=.*/SUBSCRIPTION_ID=\"$selected_subscription\"/" .env
    echo "Updated existing SUBSCRIPTION_ID"
else
    # Add SUBSCRIPTION_ID at the beginning
    sed -i "1i SUBSCRIPTION_ID=\"$selected_subscription\"" .env
    echo "Added new SUBSCRIPTION_ID"
fi

# Update any hardcoded subscription IDs in SUBNET_ID path
echo "Updating hardcoded subscription references..."
sed -i "s|/subscriptions/[0-9a-f-]*/|/subscriptions/$selected_subscription/|g" .env

echo ""
echo "Verifying subscription access..."
subscription_name=$(az account show --query 'name' -o tsv)
tenant_id=$(az account show --query 'tenantId' -o tsv)
user_name=$(az account show --query 'user.name' -o tsv)

echo ""
echo "Subscription Details:"
echo "===================="
echo "Name: $subscription_name"
echo "ID: $selected_subscription"
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
echo "✓ Azure subscription configured: $selected_subscription"
echo "✓ Required resource providers registered"
echo "✓ .env file updated with new subscription ID"
echo "✓ Configuration backup created: $backup_file"

echo ""
echo "Updated .env variables:"
grep "SUBSCRIPTION_ID\|SUBNET_ID" .env

echo ""
echo "Setup completed successfully!"
echo ""
echo "Next Steps:"
echo "==========="
echo "1. Review and modify other settings in .env if needed"
echo "2. Execute: ./01_create_cluster.sh"
echo ""

# Display current .env SUBSCRIPTION_ID for verification
current_id=$(grep "SUBSCRIPTION_ID=" .env | cut -d'"' -f2)
echo "Current SUBSCRIPTION_ID in .env: $current_id"

if [ "$current_id" = "$selected_subscription" ]; then
    echo "✓ Subscription ID successfully updated in configuration"
else
    echo "⚠ Warning: Subscription ID mismatch detected"
    echo "Expected: $selected_subscription"
    echo "Found: $current_id"
fi
