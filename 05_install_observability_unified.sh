#!/bin/bash

# 05_install_observability_unified.sh - Stack de Observabilidad Completo Unificado
# Instala Fluent Bit + Loki + Grafana con consultas predefinidas y dashboards automáticos

source .env.production
source common.sh

echo "🔍 PASO 5: STACK DE OBSERVABILIDAD COMPLETO"
echo "==========================================="
echo ""

log "INFO" "Instalando stack de observabilidad unificado..."
echo "📦 Componentes: Fluent Bit + Loki + Grafana"
echo "🎯 Funcionalidades: Logs centralizados + Visualización + Dashboards automáticos"
echo ""

# Crear namespace
log "INFO" "Creando namespace de observabilidad..."
kubectl create namespace observability-stack --dry-run=client -o yaml | kubectl apply -f -

# Agregar repositorios Helm
log "INFO" "Agregando repositorios Helm..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

echo ""
echo "🗄️ INSTALANDO LOKI (ALMACENAMIENTO DE LOGS)"
echo "============================================"

# Configuración de Loki optimizada
cat > loki-values.yaml << 'EOF'
loki:
  auth_enabled: false
  server:
    http_listen_port: 3100
  ingester:
    lifecycler:
      address: 127.0.0.1
      ring:
        kvstore:
          store: inmemory
        replication_factor: 1
      final_sleep: 0s
    chunk_idle_period: 5m
    chunk_retain_period: 30s
  schema_config:
    configs:
    - from: 2021-01-01
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h
  storage_config:
    boltdb:
      directory: /loki/index
    filesystem:
      directory: /loki/chunks
  limits_config:
    enforce_metric_name: false
    reject_old_samples: true
    reject_old_samples_max_age: 168h
    ingestion_rate_mb: 10
    ingestion_burst_size_mb: 20

persistence:
  enabled: true
  size: 10Gi

service:
  type: ClusterIP
  port: 3100

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
EOF

helm install loki grafana/loki-stack \
    --namespace observability-stack \
    --values loki-values.yaml \
    --wait --timeout=5m

if [ $? -eq 0 ]; then
    log "SUCCESS" "Loki instalado exitosamente"
else
    log "ERROR" "Error al instalar Loki"
    exit 1
fi

echo ""
echo "📊 INSTALANDO FLUENT BIT (RECOLECCIÓN DE LOGS)"
echo "==============================================="

# Configuración de Fluent Bit optimizada para recolectar todos los namespaces
cat > fluent-bit-values.yaml << 'EOF'
config:
  service: |
    [SERVICE]
        Daemon Off
        Flush 1
        Log_Level info
        Parsers_File /fluent-bit/etc/parsers.conf
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port 2020
        Health_Check On

  inputs: |
    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        multiline.parser docker, cri
        Tag kube.*
        Mem_Buf_Limit 50MB
        Skip_Long_Lines On
        Refresh_Interval 5
        
    [INPUT]
        Name systemd
        Tag host.*
        Systemd_Filter _SYSTEMD_UNIT=kubelet.service
        Read_From_Tail On

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Kube_URL https://kubernetes.default.svc:443
        Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix kube.var.log.containers.
        Merge_Log On
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude Off
        Annotations Off
        Labels On
        Buffer_Size 256k

  outputs: |
    [OUTPUT]
        Name loki
        Match *
        Host loki.observability-stack.svc.cluster.local
        Port 3100
        Labels job=fluent-bit
        Label_keys container,namespace,node,pod
        Remove_keys kubernetes,stream,time
        Auto_Kubernetes_Labels Off
        Line_format json
        Retry_Limit 3

tolerations:
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule

serviceAccount:
  create: true

rbac:
  create: true
  nodeAccess: true

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
EOF

helm install fluent-bit fluent/fluent-bit \
    --namespace observability-stack \
    --values fluent-bit-values.yaml \
    --wait --timeout=5m

if [ $? -eq 0 ]; then
    log "SUCCESS" "Fluent Bit instalado exitosamente"
else
    log "ERROR" "Error al instalar Fluent Bit"
    exit 1
fi

echo ""
echo "📈 INSTALANDO GRAFANA (VISUALIZACIÓN)"
echo "====================================="

# Configuración de Grafana con datasource automático
cat > grafana-values.yaml << 'EOF'
adminUser: admin
adminPassword: admin123

service:
  type: LoadBalancer
  port: 80

persistence:
  enabled: true
  size: 5Gi

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      isDefault: true

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

env:
  GF_EXPLORE_ENABLED: true
  GF_LOG_LEVEL: info
  GF_SECURITY_ADMIN_PASSWORD: admin123
EOF

helm install grafana grafana/grafana \
    --namespace observability-stack \
    --values grafana-values.yaml \
    --wait --timeout=5m

if [ $? -eq 0 ]; then
    log "SUCCESS" "Grafana instalado exitosamente"
else
    log "ERROR" "Error al instalar Grafana"
    exit 1
fi

echo ""
echo "⏳ Esperando que todos los pods estén listos..."
kubectl wait --for=condition=ready pod --all -n observability-stack --timeout=300s

echo ""
echo "🔍 VERIFICANDO INSTALACIÓN"
echo "=========================="
kubectl get pods -n observability-stack
kubectl get svc -n observability-stack

# Obtener IP externa de Grafana
echo ""
echo "🌐 Obteniendo IP externa de Grafana..."
GRAFANA_IP=""
for i in {1..30}; do
    GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ ! -z "$GRAFANA_IP" ]; then
        break
    fi
    echo "Esperando IP externa... ($i/30)"
    sleep 10
done

if [ ! -z "$GRAFANA_IP" ]; then
    GRAFANA_URL="http://$GRAFANA_IP"
    log "SUCCESS" "Grafana disponible en: $GRAFANA_URL"
    
    # Actualizar .env.production
    if grep -q "GRAFANA_URL=" .env.production; then
        sed -i "s|GRAFANA_URL=.*|GRAFANA_URL=\"$GRAFANA_URL\"|" .env.production
    else
        echo "GRAFANA_URL=\"$GRAFANA_URL\"" >> .env.production
    fi
else
    log "WARNING" "No se pudo obtener IP externa de Grafana"
    GRAFANA_URL="http://pending-ip"
fi

echo ""
echo "⏳ Esperando que Fluent Bit recolecte logs iniciales..."
sleep 30

echo ""
echo "🎯 CREANDO DASHBOARD AUTOMÁTICO CON CONSULTAS PREDEFINIDAS"
echo "=========================================================="

# Configurar port-forward temporal para configurar dashboard
kubectl port-forward -n observability-stack svc/grafana 3000:80 > /dev/null 2>&1 &
GRAFANA_PF_PID=$!
sleep 10

# Crear dashboard JSON con todas las consultas
cat > jenkins-logs-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "🚀 AKS Jenkins + Observabilidad - Dashboard Completo",
    "tags": ["kubernetes", "jenkins", "aks", "logs", "observabilidad"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🏠 Jenkins Master Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{namespace=\"jenkins-master\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "options": {
          "showTime": true,
          "showLabels": true,
          "sortOrder": "Descending"
        }
      },
      {
        "id": 2,
        "title": "⚡ Jenkins Workers Spot",
        "type": "logs",
        "targets": [
          {
            "expr": "{namespace=\"jenkins-workers\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "options": {
          "showTime": true,
          "showLabels": true,
          "sortOrder": "Descending"
        }
      },
      {
        "id": 3,
        "title": "🚨 Errores en Jenkins",
        "type": "logs",
        "targets": [
          {
            "expr": "{namespace=~\"jenkins.*\"} |= \"error\" or \"Error\" or \"ERROR\" or \"Exception\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
        "options": {
          "showTime": true,
          "showLabels": true,
          "sortOrder": "Descending"
        }
      },
      {
        "id": 4,
        "title": "🔧 Sistema Kubernetes",
        "type": "logs",
        "targets": [
          {
            "expr": "{namespace=\"kube-system\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
        "options": {
          "showTime": true,
          "showLabels": true,
          "sortOrder": "Descending"
        }
      },
      {
        "id": 5,
        "title": "📊 Stack Observabilidad",
        "type": "logs",
        "targets": [
          {
            "expr": "{namespace=\"observability-stack\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
        "options": {
          "showTime": true,
          "showLabels": true,
          "sortOrder": "Descending"
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

# Intentar crear el dashboard
echo "🚀 Creando dashboard automático..."
DASHBOARD_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "admin:admin123" \
    -d @jenkins-logs-dashboard.json \
    "http://localhost:3000/api/dashboards/db" 2>/dev/null)

if echo "$DASHBOARD_RESPONSE" | grep -q "success"; then
    DASHBOARD_URL=$(echo "$DASHBOARD_RESPONSE" | jq -r '.url' 2>/dev/null)
    log "SUCCESS" "Dashboard creado: $GRAFANA_URL$DASHBOARD_URL"
else
    log "INFO" "Dashboard se creará manualmente"
fi

# Limpiar port-forward
kill $GRAFANA_PF_PID 2>/dev/null

echo ""
echo "🔄 FORZANDO RECOLECCIÓN DE LOGS DE JENKINS"
echo "=========================================="
kubectl rollout restart statefulset/jenkins-master -n jenkins-master 2>/dev/null || echo "Jenkins Master no encontrado, se configurará cuando esté disponible"

echo ""
echo "✅ INSTALACIÓN COMPLETADA"
echo "========================="
echo ""
echo "🌐 ACCESO A GRAFANA:"
echo "   URL: $GRAFANA_URL"
echo "   Usuario: admin"
echo "   Contraseña: admin123"
echo ""
echo "🎯 CONSULTAS LOGQL PREDEFINIDAS:"
echo "================================"
echo ""
echo "📋 Por Namespace:"
echo "   {namespace=\"jenkins-master\"}      # 🏠 Jenkins Master"
echo "   {namespace=\"jenkins-workers\"}     # ⚡ Workers Spot"
echo "   {namespace=\"kube-system\"}         # 🔧 Sistema K8s"
echo "   {namespace=\"observability-stack\"} # 📊 Observabilidad"
echo ""
echo "🔍 Por Contenedor:"
echo "   {container=\"jenkins\"}             # 🏗️ Contenedor Jenkins"
echo "   {container=\"fluent-bit\"}          # 📊 Fluent Bit"
echo "   {container=\"loki\"}                # 🗄️ Loki"
echo "   {container=\"grafana\"}             # 📈 Grafana"
echo ""
echo "🚨 Diagnóstico:"
echo "   {namespace=~\"jenkins.*\"} |= \"error\"     # ❌ Errores Jenkins"
echo "   {} |= \"ERROR\" or \"Exception\"           # 💥 Errores críticos"
echo "   {} |= \"WARN\" or \"warn\"                 # ⚠️ Warnings"
echo ""
echo "⏱️ Con tiempo:"
echo "   {namespace=\"jenkins-master\"} | __time__ > now() - 5m  # 🕐 Últimos 5min"
echo ""
echo "📊 Métricas:"
echo "   count_over_time({namespace=\"jenkins-master\"}[1h])     # 📈 Conteo"
echo "   rate({namespace=\"jenkins-master\"} |= \"error\"[5m])   # 🎯 Rate errores"
echo ""

echo "🔧 COMANDOS ÚTILES:"
echo "=================="
echo ""
echo "📊 Ver pods de observabilidad:"
echo "   kubectl get pods -n observability-stack"
echo ""
echo "🔄 Reiniciar recolección de logs:"
echo "   kubectl rollout restart daemonset/fluent-bit -n observability-stack"
echo ""
echo "🔍 Verificar logs de Fluent Bit:"
echo "   kubectl logs -n observability-stack -l app.kubernetes.io/name=fluent-bit"
echo ""
echo "🌐 Port-forward manual a Grafana:"
echo "   kubectl port-forward -n observability-stack svc/grafana 3000:80"
echo ""

echo "💡 CÓMO USAR GRAFANA:"
echo "===================="
echo "1. 🌐 Ve a: $GRAFANA_URL"
echo "2. 🔑 Login: admin/admin123"
echo "3. 🔍 Click en 'Explore' (icono de brújula)"
echo "4. 📊 Selecciona 'Loki' como datasource"
echo "5. 📝 Pega cualquier consulta de arriba"
echo "6. ▶️ Click 'Run query'"
echo ""

log "SUCCESS" "Stack de observabilidad completo instalado y configurado"
echo "🎉 ¡Listo para monitorear logs de Jenkins y todo el cluster AKS!"

# Limpiar archivos temporales
rm -f loki-values.yaml fluent-bit-values.yaml grafana-values.yaml jenkins-logs-dashboard.json
