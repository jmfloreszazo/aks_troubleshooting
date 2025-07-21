# AKS Jenkins Spot Workers - Troubleshooting v2

Este proyecto configura un cluster AKS con Jenkins Master y Workers en nodos spot, incluyendo un stack completo de observabilidad.

## 📁 Estructura del Proyecto

```
aks_troubleshooting_v2/
├── 00_setup_subscription.sh          # Configuración inicial de Azure
├── 01_create_cluster.sh               # Creación del cluster AKS
├── 02_deploy_jenkins.sh               # Despliegue de Jenkins Master
├── 03_configure_jenkins_spot.sh       # Configuración de workers spot
├── 04_aks_diagnostic_report_full.sh   # Diagnósticos del cluster
├── 05_install_observability.sh        # Stack de observabilidad
├── 06_verify_spot_monitoring.sh       # Verificación de monitoreo
├── fix_spot_dashboard.sh              # Dashboard de Grafana
├── working_spot_queries.sh            # Consultas de prueba Loki
├── common.sh                          # Funciones comunes
├── .env.production                    # Variables de entorno
├── helm/                              # Configuraciones Helm
│   ├── jenkins_helm_values.yaml       # → Jenkins Master
│   ├── loki_helm_values.yaml          # → Loki (logs)
│   ├── fluent_bit_helm_values.yaml    # → Fluent Bit (recolección)
│   └── grafana_helm_values.yaml       # → Grafana (visualización)
└── jenkins_scripts/                   # Scripts Groovy
    ├── jenkins_spot_cloud.groovy      # → Configuración cloud
    ├── demo_spot_complete_pipeline.groovy      # → Pipeline demo
    └── monitor_spot_workers_pipeline.groovy    # → Pipeline monitoreo
```

## 🚀 Ejecución Secuencial

### 1. Configuración inicial
```bash
./00_setup_subscription.sh
```

### 2. Creación del cluster
```bash
./01_create_cluster.sh
```

### 3. Despliegue de Jenkins Master
```bash
./02_deploy_jenkins.sh
```

### 4. Configuración de workers spot
```bash
./03_configure_jenkins_spot.sh
```

### 5. Stack de observabilidad
```bash
./05_install_observability.sh
```

### 6. Dashboard y consultas
```bash
./fix_spot_dashboard.sh
./working_spot_queries.sh
```

## 📊 Componentes del Stack de Observabilidad

- **Loki**: Almacenamiento de logs (nodos regulares)
- **Fluent Bit**: Recolección de logs (todos los nodos)
- **Grafana**: Visualización y dashboards (nodos regulares)

## 🔧 Configuración de Nodos

- **Sistema**: Componentes del cluster
- **Regular**: Jenkins Master, Loki, Grafana
- **Spot**: Jenkins Workers (con tolerations)

## 📝 Archivos de Configuración

### Helm Values
- `helm/jenkins_helm_values.yaml`: Configuración Jenkins con LoadBalancer
- `helm/loki_helm_values.yaml`: Loki SingleBinary para nodos regulares
- `helm/fluent_bit_helm_values.yaml`: Recolección con tolerations para todos los nodos
- `helm/grafana_helm_values.yaml`: Grafana con datasource Loki preconfigurado

### Jenkins Scripts
- `jenkins_scripts/jenkins_spot_cloud.groovy`: Configuración automática de cloud spot
- `jenkins_scripts/demo_spot_complete_pipeline.groovy`: Pipeline demo profesional
- `jenkins_scripts/monitor_spot_workers_pipeline.groovy`: Pipeline de monitoreo avanzado

## 🎯 Monitoreo de Spot Workers

El sistema incluye:
- Logs centralizados en Loki
- Dashboards específicos para workers spot
- Consultas predefinidas para troubleshooting
- Monitoreo de lifecycle de nodos spot

## 🔗 Accesos

Después de la instalación:
- **Jenkins**: IP externa del LoadBalancer
- **Grafana**: IP externa del LoadBalancer (admin/admin123)

## 🧪 Verificación

```bash
# Verificar cluster
kubectl get nodes

# Verificar pods
kubectl get pods -A

# Verificar observabilidad
kubectl get pods -n observability-stack

# Probar consultas
./working_spot_queries.sh
```

## 📋 Troubleshooting

Para diagnósticos completos:
```bash
./04_aks_diagnostic_report_full.sh
```

Para verificar monitoreo:
```bash
./06_verify_spot_monitoring.sh
```
