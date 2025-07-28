# Jenkins Scripts Documentation

This directory contains various Jenkins pipeline scripts and utilities designed for testing, monitoring, and demonstrating Jenkins functionality with AKS spot instances.

## Script Overview

### Core Pipeline Scripts

#### `demo_spot_complete_pipeline.groovy`

**Purpose**: Comprehensive demonstration pipeline for spot worker functionality  
**Use Case**: Production-ready pipeline template showcasing spot instance capabilities  
**Features**:

- Complete system validation and testing
- Performance benchmarking on spot workers
- Resource utilization analysis
- Cost optimization demonstration
- Production-ready error handling and cleanup

**Execution**: Creates a Jenkins job named "Spot-Worker-Demo-Pipeline"  
**Duration**: ~3-5 minutes  
**Target**: Spot nodepool workers

---

#### `monitor_spot_workers_pipeline.groovy`

**Purpose**: Automated monitoring and health checking for spot workers  
**Use Case**: Continuous monitoring of spot instance stability and performance  
**Features**:

- Automated health checks every 5 minutes
- Pod lifecycle detection (new/reused/long-running)
- Memory and disk pressure monitoring
- Network connectivity testing
- Azure spot instance verification
- Performance stress testing (every 30 minutes)

**Execution**: Creates a Jenkins job named "Spot-Workers-Monitor"  
**Schedule**: Automatic execution every 5 minutes via cron  
**Duration**: ~2 minutes per execution

---

#### `jenkins_spot_cloud.groovy`

**Purpose**: Jenkins cloud configuration for spot workers  
**Use Case**: Automated setup and configuration of Jenkins Kubernetes cloud for spot instances  
**Features**:

- Dynamic spot worker provisioning
- Cloud configuration automation
- Kubernetes integration setup
- Spot instance optimization

**Execution**: Run in Jenkins Script Console  
**Duration**: Configuration setup

---

### Simple Testing Scripts

#### `simple_spot_monitor.groovy`

**Purpose**: Simple monitoring pipeline for spot workers  
**Use Case**: Basic health checking with minimal overhead  
**Features**:

- Basic system health checks
- Memory and disk monitoring
- Simple cron-based execution (every 5 minutes)
- Lightweight monitoring solution

**Execution**: Copy/paste as Pipeline Script  
**Schedule**: Every 5 minutes via cron trigger  
**Duration**: ~1 minute

---

#### `test_spot_worker.groovy`

**Purpose**: Manual testing pipeline for spot worker functionality  
**Use Case**: Manual validation and testing of spot instances  
**Features**:

- Manual execution only (no cron)
- System information collection
- Network connectivity testing
- Work simulation with file operations
- Comprehensive test reporting

**Execution**: Copy/paste as Pipeline Script (manual execution)  
**Duration**: ~2-3 minutes

---

#### `ultra_simple_spot_test.groovy`

**Purpose**: Ultra-simplified spot worker test  
**Use Case**: Quick validation of spot worker connectivity  
**Features**:

- Minimal test footprint
- Basic connectivity verification
- Instant feedback
- Quick troubleshooting tool

**Execution**: Copy/paste as Pipeline Script  
**Duration**: ~30 seconds

---

### Throttling and Control Scripts

#### `pipeline_throttled_regular.groovy`

**Purpose**: Throttled pipeline for regular nodes with resource control  
**Use Case**: Controlled execution on regular nodes with resource locking  
**Features**:

- Regular node targeting
- Throttling categories implementation
- Resource locking mechanisms
- Controlled concurrency

**Execution**: Copy/paste as Pipeline Script  
**Target**: Regular nodepool workers

---

#### `pipeline_throttled_spot.groovy`

**Purpose**: Throttled pipeline specifically for spot workers  
**Use Case**: Controlled execution on spot instances with throttling  
**Features**:

- Spot node targeting with tolerations
- Throttling controls
- Spot-specific optimizations
- Controlled resource usage

**Execution**: Copy/paste as Pipeline Script  
**Target**: Spot nodepool workers

---

### Executor Management

#### `executor_blocker_simple.groovy`

**Purpose**: Simple executor blocking for testing Jenkins queue behavior  
**Use Case**: Creating executor blocking scenarios for testing purposes  
**Features**:

- Configurable blocking duration
- Simple workload simulation
- Executor saturation testing
- Queue behavior analysis

**Execution**: Creates "Executor-Blocker-Simple" job  
**Parameters**: Block time in minutes, worker ID  
**Duration**: User-configurable

---

## Usage Patterns

### For Production Monitoring

1. **Deploy**: `monitor_spot_workers_pipeline.groovy`
2. **Configure**: Automatic 5-minute monitoring schedule
3. **Monitor**: Jenkins dashboard for continuous health status

### For Quick Testing

1. **Ultra Simple**: Use `ultra_simple_spot_test.groovy` for immediate validation
2. **Basic Testing**: Use `test_spot_worker.groovy` for manual comprehensive tests
3. **Monitoring**: Use `simple_spot_monitor.groovy` for lightweight continuous monitoring

### For Production Workloads

1. **Demo Pipeline**: Use `demo_spot_complete_pipeline.groovy` for comprehensive demonstrations
2. **Throttled Execution**: Use throttled pipelines for controlled resource usage
3. **Cloud Setup**: Use `jenkins_spot_cloud.groovy` for initial configuration

## Configuration Requirements

### Prerequisites

- AKS cluster with spot nodepool configured
- Jenkins with Kubernetes plugin installed
- Proper RBAC permissions for spot worker creation
- Azure spot instance availability in target region

### Spot Nodepool Configuration

All spot-targeting pipelines use:

```yaml
nodeSelector:
  nodepool: spot
tolerations:
- key: "kubernetes.azure.com/scalesetpriority"
  operator: "Equal"
  value: "spot"
  effect: "NoSchedule"
```

### Container Configuration

All scripts use Alpine Linux containers with:

- Persistent process (`command: ['cat']`, `tty: true`)
- Resource limits for stability
- Proper container lifecycle management

## Expected Outcomes

### Monitoring Pipelines

- **Success**: Continuous health validation of spot workers
- **Alerts**: Early detection of spot instance issues
- **Cost Savings**: 80-90% reduction compared to regular instances

### Testing Pipelines

- **Validation**: Complete spot worker functionality verification
- **Performance**: Optimal resource utilization testing
- **Reliability**: Production-readiness validation

## Troubleshooting

### Common Issues

1. **Container Termination**: Ensure `command: ['cat']` and `tty: true`
2. **Node Selection**: Verify spot nodepool labels and tolerations
3. **RBAC Permissions**: Check pod creation permissions in jenkins-workers namespace
4. **Resource Limits**: Monitor memory and CPU allocation

### Debug Steps

1. Check Jenkins logs for pod creation errors
2. Verify AKS node availability: `kubectl get nodes -l nodepool=spot`
3. Review pod events: `kubectl describe pod <pod-name> -n jenkins-workers`
4. Validate spot instance availability in Azure region

## Maintenance

### Regular Tasks

- Monitor spot worker performance metrics
- Review pipeline execution patterns
- Update resource limits based on workload requirements
- Validate cost optimization achievements

### Scaling Considerations

- Adjust concurrent execution limits based on cluster capacity
- Configure auto-scaling for spot nodepool
- Implement resource quotas for cost control
- Monitor Azure spot instance pricing and availability

---

**Note**: These scripts are designed for testing and demonstration purposes. For production deployments, consider implementing additional security, monitoring, and error handling mechanisms.
