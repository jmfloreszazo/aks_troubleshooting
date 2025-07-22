# Jenkins Master and Spot Workers - Loki Queries

Complete collection of Loki queries for analyzing Jenkins Master configuration and Spot Workers execution.

## Access Information

- **Grafana Explore**: `http://4.175.33.237/explore`
- **Grafana Dashboard**: `http://4.175.33.237/d/b4604794-14b8-47d9-b590-24d6d3c8817d/jenkins-master-and-spot-workers-complete-analysis`
- **Login**: admin / admin123

## Basic Queries

### 1. All Jenkins Workers Logs
```logql
{kubernetes_namespace_name="jenkins-workers"}
```
**What this shows:**
- All logs from jenkins-workers namespace
- Worker pod creation and lifecycle events
- General worker activity

### 2. Workers on Spot Nodes
```logql
{kubernetes_namespace_name="jenkins-workers"} |= "spot"
```
**What this shows:**
- Only logs from workers running on spot nodes
- Spot-specific events and activities
- Helpful for troubleshooting spot node issues

### 3. Workers on Specific Spot Node
```logql
{kubernetes_namespace_name="jenkins-workers"} |= "aks-spot-33804603-vmss000000"
```
**What this shows:**
- Logs from workers on a specific spot node
- Node-specific troubleshooting
- Useful for investigating specific node issues

**Note:** Replace `aks-spot-33804603-vmss000000` with your actual spot node name.

### 4. Jenkins Master Logs
```logql
{kubernetes_namespace_name="jenkins-master"}
```
**What this shows:**
- All logs from Jenkins master
- Master controller events
- Job scheduling and management logs
- Useful for troubleshooting master-side issues

### 5. Worker Lifecycle Events
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "Created|Started|Killing"
```
**What this shows:**
- Worker pod creation events (Created)
- Worker startup events (Started)
- Worker termination events (Killing)
- Complete lifecycle of spot workers
- Perfect for monitoring worker churn

### 6. Scheduling Events
```logql
{kubernetes_namespace_name="jenkins-workers"} |= "Scheduled"
```
**What this shows:**
- When workers are scheduled on nodes
- Which nodes workers are assigned to
- Scheduling delays or issues
- Helpful for understanding worker placement

### 7. All Spot-Related Logs
```logql
{job="fluent-bit"} |= "spot"
```
**What this shows:**
- All logs from any pod containing 'spot'
- System-wide spot node activities
- Comprehensive spot node monitoring
- Cluster events related to spot instances

## Advanced Master Configuration Analysis

### 8. Master Memory & JVM Analysis
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "memory|Memory|heap|Heap|GC|garbage|-Xmx|-Xms|OutOfMemory"
```
**What this shows:**
- JVM memory configuration and usage
- Garbage collection events
- Memory-related issues

### 9. Plugin Management
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "plugin|Plugin|PluginManager|Installing|install-plugins|download plugins"
```
**What this shows:**
- Plugin installation and loading
- Plugin-related errors
- Plugin management activities

### 10. Cloud Configuration
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "cloud|Cloud|kubernetes|KubernetesCloud|agent|Agent"
```
**What this shows:**
- Kubernetes cloud provider setup
- Agent configuration
- Cloud-specific events

### 11. Startup Sequence Analysis
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "Starting|Started|Initializing|Initialized|Jenkins is fully up|Setup Wizard"
```
**What this shows:**
- Jenkins master startup sequence
- Initialization events
- Startup-related issues

### 12. Configuration as Code (JCasC)
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "casc|JCasC|Configuration as Code|reload-configuration|jenkins.yaml"
```
**What this shows:**
- JCasC configuration loading
- Configuration reloads
- JCasC-related events

### 13. Security & Authentication
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "security|Security|auth|Auth|login|Login|user|User|permission|Permission"
```
**What this shows:**
- Security realm configuration
- Authentication events
- User login activities
- Permission-related issues

## Advanced Spot Workers Execution Analysis

### 14. Build Execution Flow
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "Build.*started|Build.*running|Build.*finished|Build.*completed|Build.*result"
```
**What this shows:**
- Complete build execution lifecycle
- Build start and completion events
- Build results and status

### 15. Pipeline Stage Execution
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "Stage.*started|Stage.*completed|Pipeline.*started|Pipeline.*completed|step.*execution"
```
**What this shows:**
- Pipeline stage execution details
- Stage-by-stage progress
- Pipeline workflow analysis

### 16. Job Queue & Assignment
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "job.*assigned|task.*received|work.*allocated|build.*queued|executor.*acquired"
```
**What this shows:**
- Job assignment to workers
- Queue management
- Work distribution patterns

### 17. Workspace Management
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "workspace.*created|workspace.*cleanup|checkout.*started|workspace.*path"
```
**What this shows:**
- Workspace creation and cleanup
- Code checkout activities
- Workspace-related operations

### 18. Resource Allocation
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "container.*created|resource.*allocated|cpu.*limit|memory.*limit|resource.*request"
```
**What this shows:**
- Container resource allocation
- CPU and memory limits
- Resource request patterns

### 19. Performance Metrics
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "duration.*seconds|elapsed.*time|execution.*time|build.*time|performance"
```
**What this shows:**
- Build duration metrics
- Execution time analysis
- Performance measurements

### 20. Build Success/Failure Analysis
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "Build.*SUCCESS|Build.*FAILURE|Build.*UNSTABLE|Build.*ABORTED"
```
**What this shows:**
- Build outcome analysis
- Success and failure patterns
- Build quality metrics

### 21. Spot Interruption Handling
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "spot.*interrupt|preemption|eviction|node.*pressure|resource.*pressure"
```
**What this shows:**
- Spot instance interruptions
- Node eviction events
- Resource pressure situations

## Error Analysis and Troubleshooting

### 22. System Errors & Warnings
```logql
{job="fluent-bit"} |= "jenkins" |~ "ERROR|Error|WARN|Warning|FATAL|Fatal|Exception|exception|Failed|failed"
```
**What this shows:**
- All error and warning messages
- Exception details
- System-wide issues

### 23. Master Error Analysis
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "ERROR|Error|FATAL|Fatal|Exception|OutOfMemoryError|StackOverflowError"
```
**What this shows:**
- Jenkins master specific errors
- Critical system failures
- Memory-related issues

### 24. Network & Connectivity Issues
```logql
{job="fluent-bit"} |= "jenkins" |~ "connect|Connect|network|Network|timeout|Timeout|connection|Connection"
```
**What this shows:**
- Network connectivity issues
- Connection timeouts
- Communication problems

## Performance and Monitoring

### 25. Master Performance Metrics
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "request.*duration|response.*time|throughput|latency|performance.*metric"
```
**What this shows:**
- Master response times
- Request processing metrics
- Performance analysis

### 26. Resource Usage Analysis
```logql
{job="fluent-bit"} |= "jenkins" |~ "memory|cpu|disk|Memory|CPU|Disk"
```
**What this shows:**
- System resource utilization
- Memory and CPU usage patterns
- Disk usage information

### 27. Master Job Orchestration
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "queue|Queue|build.*queued|executor|Executor|build.*started"
```
**What this shows:**
- Job queue management
- Executor allocation
- Build orchestration

### 28. Agent Tunnel Configuration
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "slaveAgentPort|jenkinsTunnel|agent.*port|50000|inbound.*agent"
```
**What this shows:**
- Agent tunnel configuration
- Port 50000 related events
- Inbound agent connections

### 29. Workspace & Volume Setup
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "jenkins_home|workspace|volume|mount|JENKINS_HOME"
```
**What this shows:**
- Jenkins home directory setup
- Volume mounting events
- Workspace configuration

### 30. Master Node Provisioning
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "provision|Provision|launching.*agent|creating.*pod|template.*provisioning"
```
**What this shows:**
- Agent provisioning events
- Pod creation for workers
- Template-based provisioning

### 31. Build Coordination
```logql
{kubernetes_namespace_name="jenkins-master"} |~ "build.*coordination|job.*assignment|worker.*allocation|build.*dispatch"
```
**What this shows:**
- Build coordination between master and workers
- Job assignment strategies
- Worker allocation patterns

### 32. Docker/Container Operations
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "docker.*pull|image.*pulled|container.*start|docker.*build|registry.*pull"
```
**What this shows:**
- Docker image operations
- Container lifecycle events
- Registry interactions

### 33. Worker Communication
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "connect.*master|communication.*established|tunnel.*connection|agent.*connection"
```
**What this shows:**
- Worker-master communication
- Connection establishment
- Tunnel connectivity

### 34. Build Retry & Recovery
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "retry.*attempt|build.*retry|recovery.*action|failure.*recovery"
```
**What this shows:**
- Build retry mechanisms
- Recovery actions
- Failure handling

### 35. Parallel Execution Monitoring
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "parallel.*execution|concurrent.*build|multiple.*jobs|parallel.*stage"
```
**What this shows:**
- Parallel build execution
- Concurrent job handling
- Multi-stage parallel workflows

### 36. Throughput & Capacity Analysis
```logql
{kubernetes_namespace_name="jenkins-workers"} |~ "throughput|capacity|concurrent.*builds|queue.*length|utilization"
```
**What this shows:**
- System throughput metrics
- Capacity utilization
- Queue length analysis

## Usage Tips

### Time Ranges
- **Startup analysis**: Use 24h time range
- **Current activity**: Use 2h time range
- **Real-time monitoring**: Use 15m time range
- **Historical analysis**: Use 7d time range

### Query Combinations
- Combine filters: `|= "spot" |= "ERROR"` for spot-specific errors
- Use regex: `|~ "Build.*completed"` for build completion patterns
- Filter by job names: `|= "job-name"`
- Filter by build numbers: `|= "#123"`

### Advanced Filtering
- **Error filtering**: Add `|= "ERROR"` to any query
- **Success filtering**: Add `|= "SUCCESS"` to build queries
- **Time-based filtering**: Use time range selector in Grafana
- **Node-specific**: Replace node names in queries as needed
