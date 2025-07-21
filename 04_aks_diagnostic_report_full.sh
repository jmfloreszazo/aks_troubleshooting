#!/bin/bash

# Interactive AKS Diagnostic Report Generator
# This script generates a comprehensive diagnostic report for AKS clusters
# Version: 2.0 - Enhanced with security and best practices

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
QUIET_MODE=false
JSON_OUTPUT=false
ANONYMIZE=true
START_TIME=$(date +%s)

# Function to print colored output
print_status() {
    [[ "$QUIET_MODE" == "false" ]] && echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    [[ "$QUIET_MODE" == "false" ]] && echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    [[ "$QUIET_MODE" == "false" ]] && echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    [[ "$QUIET_MODE" == "false" ]] && echo -e "${RED}❌ $1${NC}"
}

# Function to anonymize sensitive data
anonymize_output() {
    if [[ "$ANONYMIZE" == "true" ]]; then
        sed -E 's/"name": "[^"]*@[^"]*"/"name": "***@***.***"/g' | \
        sed -E 's/"tenantId": "[^"]*"/"tenantId": "***-***-***"/g' | \
        sed -E 's/"subscriptionId": "[^"]*"/"subscriptionId": "***-***-***"/g' | \
        sed -E 's/"id": "\/subscriptions\/[^"]*"/"id": "\/subscriptions\/***"/g'
    else
        cat
    fi
}

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --quiet, -q       Quiet mode (minimal output)"
    echo "  --json, -j        Output in JSON format"
    echo "  --no-anonymize    Don't anonymize sensitive information"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --quiet --json > report.json"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet|-q)
            QUIET_MODE=true
            shift
            ;;
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --no-anonymize)
            ANONYMIZE=false
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Default configuration (can be overridden by user input)
DEFAULT_RESOURCE_GROUP="aks-jenkins-test-rg"
DEFAULT_CLUSTER_NAME="aks-jenkins-test-cluster"
DEFAULT_LOCATION="westeurope"

# Function to get cluster configuration
get_cluster_info() {
    if [[ "$QUIET_MODE" == "true" ]]; then
        # Use defaults in quiet mode
        RESOURCE_GROUP="$DEFAULT_RESOURCE_GROUP"
        CLUSTER_NAME="$DEFAULT_CLUSTER_NAME"
        LOCATION="$DEFAULT_LOCATION"
        return
    fi
    
    echo ""
    print_status "AKS Diagnostic Report Generator v2.0"
    echo "====================================="
    echo ""
    
    # Resource Group
    echo -n "Enter resource group name [$DEFAULT_RESOURCE_GROUP]: "
    read -r rg_input
    RESOURCE_GROUP=${rg_input:-$DEFAULT_RESOURCE_GROUP}
    
    # Cluster Name
    echo -n "Enter cluster name [$DEFAULT_CLUSTER_NAME]: "
    read -r cluster_input
    CLUSTER_NAME=${cluster_input:-$DEFAULT_CLUSTER_NAME}
    
    # Location
    echo -n "Enter Azure region [$DEFAULT_LOCATION]: "
    read -r location_input
    LOCATION=${location_input:-$DEFAULT_LOCATION}
    
    echo ""
    print_status "Configuration:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Cluster Name: $CLUSTER_NAME"
    echo "  Location: $LOCATION"
    echo "  Anonymize: $ANONYMIZE"
    echo ""
    
    echo -n "Proceed with diagnostic report generation? (y/n): "
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Report generation cancelled"
        exit 0
    fi
}

# Get cluster configuration
get_cluster_info

# Set output file based on mode
if [[ "$JSON_OUTPUT" == "true" ]]; then
    OUTFILE="aks_diagnostic_report_$(date +%Y%m%d_%H%M%S).json"
else
    OUTFILE="aks_diagnostic_report_$(date +%Y%m%d_%H%M%S).md"
fi

print_status "Generating diagnostic report..."
print_status "Start time: $(date)"

# Initialize output based on format
if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "{" > $OUTFILE
    echo "  \"aks_diagnostic_report\": {" >> $OUTFILE
    echo "    \"cluster_name\": \"$CLUSTER_NAME\"," >> $OUTFILE
    echo "    \"resource_group\": \"$RESOURCE_GROUP\"," >> $OUTFILE
    echo "    \"location\": \"$LOCATION\"," >> $OUTFILE
    echo "    \"generated_at\": \"$(date -Iseconds)\"," >> $OUTFILE
    echo "    \"start_time\": \"$(date -Iseconds)\"," >> $OUTFILE
    echo "    \"sections\": {" >> $OUTFILE
else
    echo "# 🧠 AKS Troubleshooting Report (Azure) v2.0" > $OUTFILE
    echo "**Cluster:** $CLUSTER_NAME" >> $OUTFILE
    echo "**Resource Group:** $RESOURCE_GROUP" >> $OUTFILE
    echo "**Location:** $LOCATION" >> $OUTFILE
    echo "**Generated:** $(date)" >> $OUTFILE
    echo "**Start Time:** $(date -Iseconds)" >> $OUTFILE
    [[ "$ANONYMIZE" == "true" ]] && echo "**Note:** Sensitive information has been anonymized" >> $OUTFILE
    echo -e "\n---\n" >> $OUTFILE
fi

section() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "      \"$1\": {" >> $OUTFILE
    else
        echo -e "\n## 🔍 $1\n" | tee -a $OUTFILE
    fi
}

command_block() {
    local cmd="$1"
    local section_key="$2"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "        \"command\": \"$cmd\"," >> $OUTFILE
        echo "        \"output\": [" >> $OUTFILE
        eval $cmd 2>&1 | anonymize_output | sed 's/"/\\"/g' | sed 's/^/          "/' | sed 's/$/",/' >> $OUTFILE
        sed -i '$ s/,$//' $OUTFILE  # Remove last comma
        echo "        ]" >> $OUTFILE
        echo "      }," >> $OUTFILE
    else
        echo -e "\n\`\`\`bash\n$cmd\n\`\`\`\n" | tee -a $OUTFILE
        eval $cmd 2>&1 | anonymize_output | tee -a $OUTFILE
    fi
}

# Authentication and context
section "🔐 Login and context"
command_block "az account show"
command_block "az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing"

# General infrastructure
section "1. AKS cluster status and node pools"
command_block "az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --output table"
command_block "az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --output table"

section "2. Nodes and resource consumption"
command_block "kubectl get nodes -o wide"
command_block "kubectl top nodes"
command_block "kubectl describe nodes | grep -A5 Allocated"

# Pod and workload diagnostics
section "3. Pod status (CrashLoop, Pending, OOM)"
command_block "kubectl get pods -A | grep -E 'CrashLoopBackOff|OOMKilled|Pending|ImagePullBackOff|Error|Terminating' || echo '✅ No pods in anomalous state visible'"

section "4. Detailed description of a pod in error"
POD=$(kubectl get pods -A | grep CrashLoopBackOff | head -n 1 | awk '{print $2}')
NS=$(kubectl get pods -A | grep CrashLoopBackOff | head -n 1 | awk '{print $1}')
[[ -n "$POD" ]] && command_block "kubectl describe pod $POD -n $NS" || echo "*No current CrashLoopBackOff pods*" >> $OUTFILE

# Scheduling and affinities
section "5. Pending pods / Scheduling failures"
command_block "kubectl get pods -A | grep Pending || echo '✅ No pending pods found'"
command_block "kubectl describe pods -A | grep -E 'tolerations|affinity' | head -n 20 || echo '✅ No scheduling constraints found'"

# Networking and DNS - IMPROVED
section "6. Networking and DNS"
command_block "kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20 | grep -i error || echo '✅ No DNS errors in recent logs'"
command_block "kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=20 | grep -i error || echo '✅ No proxy errors in recent logs'"
command_block "kubectl get events -A | grep -i dns || echo '✅ No DNS-related events'"
command_block "kubectl get svc -A -o wide"
command_block "kubectl get ep -A | grep '<none>' || echo '✅ All services have endpoints'"

# Scaling and performance
section "7. Scaling (HPA) and load"
command_block "kubectl get hpa -A || echo '✅ No HPA configured'"
command_block "kubectl describe hpa -A || echo '✅ No HPA details available'"
command_block "kubectl top pods -A --containers | sort -k6 -hr | head -n 10 || echo '⚠️ Metrics server not available'"

# Probes and container configuration
section "8. Liveness / Readiness Probes"
command_block "kubectl get pods -A -o=jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.spec.containers[*].livenessProbe.httpGet.path}{\"\\n\"}{end}' | grep -v '^$' || echo '✅ No HTTP liveness probes configured'"

# IMPROVED: Pods without requests/limits - fixed duplicates
section "9. Pods without requests/limits"
command_block "kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers | map(.resources.requests == null or .resources.limits == null) | any) | .metadata.name' | sort -u || echo '✅ All pods have resource limits configured'"

# Critical logs and runtime failures
section "10. Runtime Containerd (logs)"
command_block "kubectl logs -n kube-system -l k8s-app=containerd --tail=20 | grep -i error || echo '✅ No containerd errors in recent logs'"

# Evictions, Spot Nodes and OOM
section "11. Evictions and Spot nodes"
command_block "kubectl get events -A | grep -i Evicted | sort | uniq -c | sort -nr | head -n 10 || echo '✅ No eviction events found'"
command_block "kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels[\"kubernetes.azure.com/mode\"] == \"User\") | [.metadata.name, .metadata.labels[\"kubernetes.azure.com/agentpool\"]] | @tsv' || echo '✅ No user mode nodes found'"
command_block "kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels[\"kubernetes.azure.com/scalesetpriority\"] == \"spot\") | [.metadata.name, .metadata.labels[\"kubernetes.azure.com/scalesetpriority\"]] | @tsv' || echo '✅ No spot nodes found'"

# Networking and ingress
section "12. Ingress and external services"
command_block "kubectl get ingress -A || echo '✅ No ingress controllers configured'"
command_block "kubectl get svc -A | grep LoadBalancer || echo '✅ No LoadBalancer services configured'"

# Storage
section "13. Persistent volumes (PVCs)"
command_block "kubectl get pvc -A || echo '✅ No persistent volume claims'"
command_block "kubectl get pv || echo '✅ No persistent volumes'"

# API Server and control plane - IMPROVED
section "14. Control plane components"
command_block "kubectl get --raw='/readyz?verbose' || kubectl get componentstatuses || echo '⚠️ Control plane status unavailable'"
command_block "kubectl get events -A | grep -i 'control-plane\\|api-server' | head -n 10 || echo '✅ No control plane events'"

# ConfigMaps and Secrets
section "15. ConfigMaps / Secrets"
command_block "echo 'ConfigMaps count:' && kubectl get configmaps -A | wc -l"
command_block "echo 'Secrets count:' && kubectl get secrets -A | wc -l"

# Jobs / CronJobs
section "16. Jobs and CronJobs in bad state"
command_block "kubectl get jobs -A || echo '✅ No jobs configured'"
command_block "kubectl get cronjobs -A || echo '✅ No cronjobs configured'"

# Objects blocked by finalizers
section "17. Active finalizers"
command_block "kubectl get all -A -o json | jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers | length > 0)) | .metadata.name' || echo '✅ No objects with active finalizers'"

# IMPROVED: Azure Monitor
section "18. Azure Monitor and Node Metrics"
command_block "az monitor metrics list --resource \$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) --metric 'node_cpu_usage_percentage' --interval PT1H --output table || echo 'ℹ️ Azure Monitor not enabled or no recent CPU metrics'"
command_block "az monitor metrics list --resource \$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) --metric 'node_memory_working_set_percentage' --interval PT1H --output table || echo 'ℹ️ Azure Monitor not enabled or no recent memory metrics'"

# Finalize output and calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
END_TIMESTAMP=$(date -Iseconds)

if [[ "$JSON_OUTPUT" == "true" ]]; then
    # Remove last comma and close JSON
    sed -i '$ s/,$//' $OUTFILE
    echo "    }," >> $OUTFILE
    echo "    \"end_time\": \"$END_TIMESTAMP\"," >> $OUTFILE
    echo "    \"duration_seconds\": $DURATION," >> $OUTFILE
    echo "    \"generation_info\": {" >> $OUTFILE
    echo "      \"script_version\": \"2.0\"," >> $OUTFILE
    echo "      \"anonymized\": $ANONYMIZE," >> $OUTFILE
    echo "      \"quiet_mode\": $QUIET_MODE" >> $OUTFILE
    echo "    }" >> $OUTFILE
    echo "  }" >> $OUTFILE
    echo "}" >> $OUTFILE
else
    echo -e "\n---\n" >> $OUTFILE
    echo "**End Time:** $END_TIMESTAMP" >> $OUTFILE
    echo "**Total Duration:** ${DURATION} seconds" >> $OUTFILE
    echo "**Script Version:** 2.0" >> $OUTFILE
fi

echo -e "\n"
print_success "Complete report generated: $OUTFILE"
print_status "Report duration: ${DURATION} seconds"
if [[ "$JSON_OUTPUT" == "true" ]]; then
    print_status "JSON format - can be processed with: jq . $OUTFILE"
else
    print_status "Markdown format - view with: cat $OUTFILE"
fi

[[ "$ANONYMIZE" == "true" ]] && print_warning "Sensitive information has been anonymized"
