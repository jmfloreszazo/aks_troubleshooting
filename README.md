# AKS Jenkins Spot Workers - Troubleshooting v2

This project sets up an AKS cluster with Jenkins Master and Workers on spot nodes, including a complete observability stack.

## 📁 Project Structure

```
aks_troubleshooting_v2/
├── 00_setup_subscription.sh          # Azure initial setup
├── 01_create_cluster.sh               # AKS cluster creation
├── 02_deploy_jenkins.sh               # Jenkins Master deployment
├── 03_configure_jenkins_spot.sh       # Spot workers configuration
├── 04_aks_diagnostic_report_full.sh   # Cluster diagnostics
├── 05_install_observability.sh        # Observability stack
├── 06_verify_spot_monitoring.sh       # Monitoring verification
├── common.sh                          # Common functions
├── .env.production                    # Environment variables
├── grafana/                           # Grafana and Loki scripts
│   ├── spot_dashboard.sh              # → Spot monitoring dashboard
│   ├── spot_queries.sh                # → Loki test queries
│   └── queries/                       # Individual query scripts
│       ├── menu.sh                    # → Query selection menu
│       ├── 01_all_jenkins_workers.sh  # → All workers logs
│       ├── 02_workers_on_spot.sh      # → Spot workers only
│       ├── 03_workers_specific_node.sh # → Specific node workers
│       ├── 04_jenkins_master.sh       # → Master logs
│       ├── 05_lifecycle_events.sh     # → Worker lifecycle
│       ├── 06_scheduling_events.sh    # → Scheduling events
│       ├── 07_all_spot_logs.sh        # → All spot logs
│       ├── 08_master_config_analysis.sh # → Master config analysis
│       ├── 09_spot_execution_analysis.sh # → Spot execution details
│       ├── 10_complete_system_analysis.sh # → Complete system overview
│       ├── 11_extract_live_config.sh  # → Live Kubernetes config extraction
│       ├── 12_master_deep_config.sh   # → Master configuration deep dive
│       ├── 13_spot_execution_deep.sh  # → Spot execution deep analysis
│       └── SUMMARY_jenkins_config.sh  # → Complete configuration summary
├── helm/                              # Helm configurations
│   ├── jenkins_helm_values.yaml       # → Jenkins Master
│   ├── loki_helm_values.yaml          # → Loki (logs)
│   ├── fluent_bit_helm_values.yaml    # → Fluent Bit (collection)
│   └── grafana_helm_values.yaml       # → Grafana (visualization)
└── jenkins_scripts/                   # Groovy scripts
    ├── jenkins_spot_cloud.groovy      # → Cloud configuration
    ├── demo_spot_complete_pipeline.groovy      # → Demo pipeline
    └── monitor_spot_workers_pipeline.groovy    # → Monitoring pipeline
```

## 🚀 Sequential Execution

### 1. Initial setup
```bash
./00_setup_subscription.sh
```

### 2. Cluster creation
```bash
./01_create_cluster.sh
```

### 3. Jenkins Master deployment
```bash
./02_deploy_jenkins.sh
```

### 4. Spot workers configuration
```bash
./03_configure_jenkins_spot.sh
```

### 5. Observability stack
```bash
./05_install_observability.sh
```

### 6. Dashboard and queries

```bash
./grafana/spot_dashboard.sh
./grafana/spot_queries.sh
```

### 7. Individual Loki queries

```bash
# Interactive menu with all queries
./grafana/queries/menu.sh

# Or run individual queries directly:
./grafana/queries/01_all_jenkins_workers.sh
./grafana/queries/02_workers_on_spot.sh
./grafana/queries/03_workers_specific_node.sh
./grafana/queries/04_jenkins_master.sh
./grafana/queries/05_lifecycle_events.sh
./grafana/queries/06_scheduling_events.sh
./grafana/queries/07_all_spot_logs.sh
```

## 📊 Observability Stack Components

- **Loki**: Log storage (regular nodes)
- **Fluent Bit**: Log collection (all nodes)
- **Grafana**: Visualization and dashboards (regular nodes)

## 🔧 Node Configuration

- **System**: Cluster components
- **Regular**: Jenkins Master, Loki, Grafana
- **Spot**: Jenkins Workers (with tolerations)

## 📝 Configuration Files

### Helm Values
- `helm/jenkins_helm_values.yaml`: Jenkins configuration with LoadBalancer
- `helm/loki_helm_values.yaml`: Loki SingleBinary for regular nodes
- `helm/fluent_bit_helm_values.yaml`: Collection with tolerations for all nodes
- `helm/grafana_helm_values.yaml`: Grafana with pre-configured Loki datasource

### Jenkins Scripts

- `jenkins_scripts/jenkins_spot_cloud.groovy`: Automatic spot cloud configuration
- `jenkins_scripts/demo_spot_complete_pipeline.groovy`: Professional demo pipeline
- `jenkins_scripts/monitor_spot_workers_pipeline.groovy`: Advanced monitoring pipeline

### Grafana Scripts

- `grafana/spot_dashboard.sh`: Spot workers specific monitoring dashboard
- `grafana/spot_queries.sh`: Test and troubleshooting queries for Loki

### Advanced Query Scripts

- `grafana/queries/menu.sh`: Interactive query selection menu
- `grafana/queries/08_master_config_analysis.sh`: Master configuration analysis (memory, plugins, JVM)
- `grafana/queries/09_spot_execution_analysis.sh`: Spot workers execution details
- `grafana/queries/10_complete_system_analysis.sh`: Complete system overview
- `grafana/queries/11_extract_live_config.sh`: Live Kubernetes configuration extraction

### Deep Analysis Scripts

- `grafana/queries/12_master_deep_config.sh`: Master configuration deep dive (startup, JCasC, security)
- `grafana/queries/13_spot_execution_deep.sh`: Spot execution deep analysis (builds, performance, resources)
- `grafana/queries/SUMMARY_jenkins_config.sh`: Complete configuration summary report

## 🎯 Spot Workers Monitoring

The system includes:
- Centralized logs in Loki
- Spot workers specific dashboards
- Pre-defined queries for troubleshooting
- Spot node lifecycle monitoring

## 🔗 Access

After installation:
- **Jenkins**: LoadBalancer external IP
- **Grafana**: LoadBalancer external IP (admin/admin123)

## 🧪 Verification

```bash
# Verify cluster
kubectl get nodes

# Verify pods
kubectl get pods -A

# Verify observability
kubectl get pods -n observability-stack

# Test queries
./grafana/spot_queries.sh
```

## 📋 Troubleshooting

For complete diagnostics:
```bash
./04_aks_diagnostic_report_full.sh
```

To verify monitoring:
```bash
./06_verify_spot_monitoring.sh
```
