# Grafana Tempo - Distributed Tracing para Jenkins Master-Pod Correlation

## 🎯 Objetivo

Este directorio contiene la implementación completa de **Grafana Tempo** para el seguimiento distribuido (distributed tracing) en el cluster AKS. El objetivo principal es **correlacionar fallos del Jenkins Master con logs de los Pods** para detectar cuándo el master falla y qué estaba pasando en los pods en ese momento.

## 📋 Componentes

### 🛠️ Scripts de Instalación
- **`install_tempo_tracing.sh`** - Script principal de instalación de Tempo y OpenTelemetry
- **`configure_grafana_tempo.sh`** - Configura Tempo como datasource en Grafana
- **`import_grafana_dashboard.sh`** - Importa el dashboard especializado para Jenkins

### ⚙️ Configuración Helm
- **`helm/tempo_helm_values_fixed.yaml`** - Configuración principal de Tempo (funcional en este cluster)
- **`helm/tempo_helm_values_simple.yaml`** - Configuración simplificada para testing
- **`helm/tempo_helm_values.yaml`** - Configuración avanzada original

### 📊 Dashboard y Datasources
- **`grafana-config/jenkins-tempo-dashboard.json`** - Dashboard especializado para trazas Jenkins Master-Pod
- **`grafana-config/tempo-datasource.yaml`** - Configuración del datasource de Tempo

### 🔧 Instrumentación
- **`jenkins-instrumentation/`** - Configuración OpenTelemetry para Jenkins
  - `jenkins-otel-config.yaml` - ConfigMap con configuración OTEL
  - `jenkins-deployment-patch.yaml` - Patch para habilitar tracing en Jenkins

### 🐍 Análisis AI-Powered
- **`jenkins_trace_analyzer.py`** - Analizador inteligente que correlaciona trazas con logs
- **`setup_port_forwards.sh`** - Script para configurar acceso a servicios

## 🚀 Instalación Rápida

### 1. Instalar Tempo
```bash
# Ejecutar script de instalación
./install_tempo_tracing.sh
```

### 2. Configurar Grafana
```bash
# Configurar datasource
./configure_grafana_tempo.sh

# Importar dashboard
./import_grafana_dashboard.sh
```

### 3. Configurar Port-Forwards
```bash
# Configurar acceso a servicios
./setup_port_forwards.sh
```

## 🔍 Uso del Sistema

### Acceso a Servicios
Una vez ejecutado `setup_port_forwards.sh`:

- **Grafana**: http://localhost:3000
  - Usuario: `admin`
  - Password: Se muestra en el script
  - Dashboard: http://localhost:3000/d/jenkins-tempo-tracing/jenkins-master-pod-distributed-tracing

- **Tempo**: http://localhost:3200
- **Loki**: http://localhost:3100
- **Prometheus**: http://localhost:9090

### Análisis AI con Python
```bash
# Instalar dependencias
pip install requests

# Ejecutar análisis
python3 jenkins_trace_analyzer.py
```

El analizador:
1. 🔍 Consulta trazas de Jenkins Master en Tempo
2. 🚨 Identifica trazas con errores o alta latencia
3. 📝 Correlaciona con logs de pods en Loki
4. 🤖 Genera análisis inteligente con severidad
5. 📄 Produce reporte detallado con recomendaciones

## 🎭 Casos de Uso Principales

### 1. Depuración de Fallos Master-Pod
Cuando Jenkins Master falla:
- Ver trazas en Grafana dashboard
- Correlacionar con logs de pods específicos
- Identificar interrupciones de spot instances
- Detectar problemas de conectividad

### 2. Análisis de Rendimiento
- Identificar operaciones lentas (>5 segundos)
- Monitorizar latencia entre master y workers
- Detectar cuellos de botella en distribución de jobs

### 3. Alertas Proactivas
- Configurar alertas basadas en trazas problemáticas
- Detectar patrones de fallos antes de que afecten usuarios
- Monitorizar health de la infraestructura distribuida

## 🔧 Configuración Avanzada

### Ajustar Ventana de Análisis
```bash
# Analizar últimas 4 horas en lugar de 2
python3 jenkins_trace_analyzer.py --hours-back 4
```

### Personalizar Servicios
Editar URLs en `jenkins_trace_analyzer.py`:
```python
tempo_url = "http://localhost:3200"
loki_url = "http://localhost:3100"
```

### Modificar Severidad
Ajustar criterios en `_calculate_severity()`:
- Duración crítica: >10 segundos
- Duración alta: >5 segundos
- Logs de error: peso en scoring

## 📊 Métricas y Alertas

### Métricas Principales
- **Latencia de trazas**: tiempo de operaciones master-pod
- **Tasa de errores**: porcentaje de trazas fallidas
- **Correlación temporal**: logs vs trazas en ventanas de tiempo
- **Distribución por severidad**: CRITICAL, HIGH, MEDIUM, LOW

### Dashboards Incluidos
1. **Distribución de Trazas por Servicio** (pie chart)
2. **Latencia Master-Pod** (time series)
3. **Lista de Trazas Recientes** (tabla)
4. **Búsqueda de Errores** (tabla filtrada)
5. **Logs Correlacionados** (logs panel)

## 🛡️ Troubleshooting

### Pod Tempo en Estado Pending
```bash
# Verificar tolerations y nodeSelector
kubectl describe pod tempo-0 -n observability-stack

# Problema común: nodepool taint
# Solución: Usar tempo_helm_values_fixed.yaml
```

### Sin Trazas Visibles
```bash
# Verificar que Jenkins esté instrumentado
kubectl get pods -n jenkins -o yaml | grep -i otel

# Verificar conectividad a Tempo
curl http://localhost:3200/ready
```

### Error en Análisis Python
```bash
# Verificar port-forwards activos
netstat -tlnp | grep -E "(3200|3100)"

# Verificar logs de servicios
kubectl logs tempo-0 -n observability-stack
kubectl logs loki-0 -n observability-stack
```

## 🎯 Estado Actual

### ✅ Completado
- [x] Tempo instalado y funcionando
- [x] Datasource configurado en Grafana
- [x] Dashboard especializado importado
- [x] Analizador Python con AI
- [x] Scripts de automatización
- [x] Configuración corregida para este cluster

### 🔄 En Progreso
- [ ] Instrumentación de Jenkins con OpenTelemetry
- [ ] Generación de trazas reales
- [ ] Alertas automáticas basadas en análisis

### 🎯 Próximos Pasos
1. Configurar Jenkins para enviar trazas a Tempo
2. Probar correlación con fallos reales de spot instances
3. Implementar alertas automáticas en Grafana
4. Integrar con sistema de notificaciones

## 📚 Referencias

- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry Instrumentation](https://opentelemetry.io/docs/instrumentation/)
- [Jenkins OpenTelemetry Plugin](https://plugins.jenkins.io/opentelemetry/)
- [Kubernetes Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

---
**Objetivo Principal**: *Correlacionar cuándo falla Jenkins Master con qué había en los pods en los logs para diagnóstico avanzado de fallos distribuidos.*
