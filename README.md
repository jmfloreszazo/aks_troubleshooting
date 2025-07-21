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
│   └── spot_queries.sh                # → Loki test queries
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
