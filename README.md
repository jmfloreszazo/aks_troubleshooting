# AKS Jenkins with Spot Instances - Complete Setup

## Overview

This repository provides a complete, production-ready solution for deploying Jenkins on Azure Kubernetes Service (AKS) with spot instance support for cost-effective CI/CD pipelines. The solution achieves 80-90% cost savings by utilizing Azure spot instances for Jenkins build workers while maintaining reliability through proper configuration and auto-scaling.

## Architecture

The solution creates a multi-node pool AKS cluster with the following components:

- **System Node Pool**: Hosts Kubernetes system components
- **Regular Node Pool**: Hosts Jenkins Master with guaranteed availability
- **Spot Node Pool**: Hosts Jenkins Workers with auto-scaling (0-N nodes)
- **Proper Tolerations**: Ensures workloads can schedule on spot instances
- **RBAC Configuration**: Secure service account permissions
- **Load Balancer**: External access to Jenkins Master

## Cost Optimization

- **Spot Instances**: 80-90% cost reduction compared to regular VMs
- **Auto-scaling**: Nodes created only when needed (min=0)
- **Efficient Resource Allocation**: Optimized CPU/memory limits
- **Automatic Cleanup**: Workers terminated after idle period

## Project Structure

```
├── 00_setup_subscription.sh      # Azure subscription selection and setup
├── 01_create_cluster.sh          # AKS cluster creation with node pools
├── 02_deploy_jenkins.sh          # Jenkins Master deployment
├── 03_configure_rbac.sh          # RBAC and service account setup
├── jenkins_spot_cloud.groovy     # Jenkins cloud configuration script
├── demo_spot_complete_pipeline.groovy  # Sample pipeline for testing
├── test-workloads.yaml           # Kubernetes test workloads
├── common.sh                     # Shared utility functions
├── .env                          # Configuration variables
└── README.md                     # This documentation
```

## Quick Start

### 1. Clone and Initial Setup

```bash
git clone <repository-url>
cd aks_troubleshooting
chmod +x *.sh
```

### 2. Configure Azure Subscription

```bash
# Step 0: Setup Azure subscription
./00_setup_subscription.sh
```

This script will:
- Display available Azure subscriptions
- Allow you to select the target subscription
- Update all subscription references in .env file
- Verify required resource providers are registered
- Check quotas and permissions

### 3. Review Configuration

Edit `.env` file to customize your deployment:

```bash
# Core Configuration
RESOURCE_GROUP="aks-jenkins-spot"
CLUSTER_NAME="aks-jenkins-cluster"
LOCATION="westeurope"

# Node Configuration  
SPOT_MAX_COUNT=3
NODE_SIZE="Standard_DS2_v2"
SPOT_NODE_SIZE="Standard_DS2_v2"
```

### 4. Execute Setup Steps

```bash
# Step 1: Create AKS cluster with node pools
./01_create_cluster.sh

# Step 2: Deploy Jenkins Master
./02_deploy_jenkins.sh

# Step 3: Configure RBAC permissions
./03_configure_rbac.sh
```## Prerequisites

### Azure Requirements
- Azure CLI installed and authenticated
- Active Azure subscription with appropriate permissions
- Permissions to create resource groups and AKS clusters
- Low Priority Cores quota (minimum 6 cores recommended)

### Local Tools
- kubectl installed
- Bash shell (Linux, macOS, or WSL)
- Internet connectivity for downloading container images

### Azure Quotas
The setup script will check these quotas automatically:
- **Total Regional vCPUs**: Minimum 10
- **Standard DSv2 Family vCPUs**: Minimum 8  
- **Low Priority vCPUs**: Minimum 6
- **Public IP Addresses**: Minimum 2

### 5. Configure Jenkins Cloud

1. Access Jenkins at the provided LoadBalancer IP
2. Navigate to Script Console (`/script`)
3. Execute the content of `jenkins_spot_cloud.groovy`
4. Verify cloud configuration in Manage Jenkins > Clouds

### 6. Test the Setup

1. Create a pipeline using the sample from `demo_spot_complete_pipeline.groovy`
2. Execute the pipeline with `agent { label 'nodepool=spot' }`
3. Monitor auto-scaling of spot nodes during execution

## Detailed Setup Guide

### Step 0: Subscription Setup

The `00_setup_subscription.sh` script provides:

- **Subscription Selection**: Interactive list of available subscriptions
- **Automatic Configuration**: Updates all subscription references in .env
- **Resource Provider Registration**: Ensures required Azure providers are enabled
- **Quota Validation**: Checks available quotas in target region
- **Permission Verification**: Validates user permissions

**Features:**
- Backup creation of existing configuration
- Validation of subscription ID format
- Automatic hardcoded reference updates
- Resource provider registration with wait
- Comprehensive quota checking

### Step 1: Cluster Creation

The `01_create_cluster.sh` script performs:

- **Resource Group Creation**: Creates Azure resource group
- **Virtual Network Setup**: Configures VNet with appropriate CIDR ranges
- **AKS Cluster Creation**: Deploys cluster with system node pool
- **Regular Node Pool**: Adds node pool for Jenkins Master
- **Spot Node Pool**: Adds auto-scaling spot node pool with proper taints
- **Kubeconfig Setup**: Configures local kubectl access

**Key Features:**
- Auto-scaling spot nodes (0 to configured maximum)
- Proper node taints and labels for workload separation
- Quota validation and error handling
- Network configuration for production use

### Step 2: Jenkins Deployment

The `02_deploy_jenkins.sh` script handles:

- **Namespace Creation**: Dedicated namespaces for Jenkins components
- **Persistent Storage**: PVC for Jenkins data persistence
- **Jenkins Master Deployment**: Configured with appropriate resources
- **Service Configuration**: LoadBalancer for external access
- **Initial Setup**: Admin user and plugin installation

**Security Features:**
- Service account with minimal required permissions
- Network policies for pod isolation
- Persistent volume claims for data protection
- Proper resource limits and requests

### Step 3: RBAC Configuration

The `03_configure_rbac.sh` script configures:

- **Service Account**: Dedicated account for Jenkins operations
- **Cluster Role**: Minimal permissions for pod management
- **Role Binding**: Links service account to required permissions
- **Token Generation**: Creates authentication tokens for Jenkins

**Permissions Granted:**
- Pod creation and deletion in jenkins-workers namespace
- Secret and ConfigMap read access
- Node information read access (for auto-scaling)
- Limited cluster-wide read permissions

## Jenkins Cloud Configuration

### Manual Configuration

The `jenkins_spot_cloud.groovy` script configures:

- **Kubernetes Cloud**: Connection to cluster
- **Pod Templates**: Definition for spot worker pods
- **Tolerations**: Proper handling of spot node taints
- **Resource Limits**: CPU and memory allocation
- **Auto-scaling**: Worker creation based on demand

### Key Configuration Elements

```groovy
// Spot node tolerations
tolerations:
- key: "kubernetes.azure.com/scalesetpriority"
  operator: "Equal"
  value: "spot"
  effect: "NoSchedule"

// Resource allocation
CPU: 100m request, 2000m limit
Memory: 256Mi request, 2Gi limit
```

## Pipeline Configuration

### Basic Pipeline Structure

```groovy
pipeline {
    agent { label 'nodepool=spot' }
    stages {
        stage('Build') {
            steps {
                // Your build steps here
            }
        }
    }
}
```

### Advanced Pipeline with Multiple Agents

```groovy
pipeline {
    stages {
        stage('Build') {
            agent { label 'nodepool=spot' }
            steps {
                // Parallel builds on spot instances
            }
        }
        stage('Deploy') {
            agent { label 'nodepool=regular' }
            steps {
                // Critical deployment on regular nodes
            }
        }
    }
}
```

## Monitoring and Troubleshooting

### Monitor Spot Node Creation

```bash
# Watch node status
kubectl get nodes -w

# Monitor pod scheduling
kubectl get pods -n jenkins-workers -w

# Check auto-scaler events
kubectl describe nodes | grep -A5 -B5 "spot"
```

### Common Issues and Solutions

**Pipeline Stuck in "Still waiting to schedule task"**
- Verify tolerations in Jenkins cloud configuration
- Check spot node pool auto-scaler status
- Confirm RBAC permissions for pod creation

**Spot Nodes Not Scaling**
- Check Azure quota for Low Priority Cores
- Verify auto-scaler configuration on node pool
- Monitor cluster-autoscaler logs

**High Spot Instance Interruptions**
- Implement pipeline restart mechanisms
- Use mixed instance types in node pool
- Configure graceful shutdown handling

### Debug Commands

```bash
# Check cluster status
kubectl cluster-info

# Verify node pool configuration
az aks nodepool show --cluster-name <cluster> --name spot --resource-group <rg>

# Monitor auto-scaler
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check Jenkins pod logs
kubectl logs -n jenkins-master deployment/jenkins-master
```

## Security Considerations

### Network Security
- Virtual network isolation
- Network policies between namespaces
- LoadBalancer with controlled access
- Private cluster endpoints (optional)

### RBAC Security
- Minimal service account permissions
- Namespace-based access control
- Regular permission auditing
- Secret management best practices

### Container Security
- Official Jenkins images from trusted registries
- Regular image updates and vulnerability scanning
- Resource limits to prevent resource exhaustion
- Non-root container execution where possible

## Maintenance and Updates

### Regular Maintenance Tasks

1. **Update Jenkins and Plugins**
   - Monitor security advisories
   - Test updates in staging environment
   - Plan maintenance windows for updates

2. **Monitor Resource Usage**
   - Review CPU and memory utilization
   - Adjust resource limits as needed
   - Monitor spot instance interruption rates

3. **Review Security Configuration**
   - Audit RBAC permissions
   - Update service account tokens
   - Review network policies

### Scaling Configuration

**Horizontal Scaling:**
- Increase `SPOT_MAX_COUNT` in configuration
- Monitor quota usage and request increases
- Consider multi-region deployment for high availability

**Vertical Scaling:**
- Adjust VM sizes for better performance
- Optimize resource requests and limits
- Consider memory-optimized instances for specific workloads

## Cost Management

### Cost Optimization Strategies

1. **Right-sizing Instances**
   - Monitor actual resource usage
   - Use smaller instances for light workloads
   - Implement resource-based scheduling

2. **Auto-scaling Optimization**
   - Fine-tune idle timeout settings
   - Optimize scale-down policies
   - Use predictive scaling for regular workloads

3. **Reserved Capacity**
   - Use regular nodes for consistent workloads
   - Reserve capacity for critical operations
   - Implement workload prioritization

### Cost Monitoring

```bash
# Monitor node costs
az consumption usage list --scope /subscriptions/<sub-id>

# Track resource group costs
az billing consumption list --resource-group <rg-name>
```

## Backup and Disaster Recovery

### Jenkins Data Backup

- Persistent volume snapshots
- Configuration backup to Azure Storage
- Plugin and job configuration export
- Database backup for enterprise installations

### Cluster Recovery

- Infrastructure as Code for cluster recreation
- Automated deployment scripts
- Configuration management
- Multi-region deployment for high availability

## Support and Contributing

### Getting Help

1. Check troubleshooting section in this README
2. Review Azure AKS documentation
3. Consult Jenkins Kubernetes plugin documentation
4. Open issues in project repository

### Contributing

1. Fork the repository
2. Create feature branch
3. Test changes thoroughly
4. Submit pull request with detailed description

### Version Compatibility

- **Kubernetes**: 1.25+
- **Jenkins**: 2.400+
- **Kubernetes Plugin**: 4000.0+
- **Azure CLI**: 2.50+

This solution is tested and maintained for the above versions. Compatibility with other versions may require additional configuration.
