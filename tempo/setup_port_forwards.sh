#!/bin/bash

# Script para configurar port-forwards para el análisis de trazas
# =============================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE_OBSERVABILITY=${NAMESPACE_OBSERVABILITY:-"observability-stack"}

echo -e "${YELLOW}🔗 Configurando port-forwards para análisis de trazas...${NC}"

# Función de cleanup
cleanup() {
    echo -e "${YELLOW}🧹 Cerrando port-forwards...${NC}"
    # Matar todos los procesos de port-forward de este script
    jobs -p | xargs -r kill 2>/dev/null || true
    wait 2>/dev/null || true
}

# Configurar trap para cleanup al salir
trap cleanup EXIT INT TERM

# Verificar que los servicios estén disponibles
echo -e "${YELLOW}🔍 Verificando servicios...${NC}"

SERVICES=("tempo:3200" "loki:3100" "grafana:80" "prometheus:80")
for service_port in "${SERVICES[@]}"; do
    service=$(echo $service_port | cut -d: -f1)
    port=$(echo $service_port | cut -d: -f2)
    
    if kubectl get svc $service -n $NAMESPACE_OBSERVABILITY &>/dev/null; then
        echo -e "  ✅ $service encontrado"
    else
        echo -e "  ❌ $service NO encontrado en namespace $NAMESPACE_OBSERVABILITY"
    fi
done

echo ""

# Configurar port-forwards
echo -e "${YELLOW}🌐 Iniciando port-forwards...${NC}"

# Tempo (3200)
echo -e "  📊 Tempo: http://localhost:3200"
kubectl port-forward -n $NAMESPACE_OBSERVABILITY svc/tempo 3200:3200 &
TEMPO_PF_PID=$!

# Loki (3100)
echo -e "  📝 Loki: http://localhost:3100"
kubectl port-forward -n $NAMESPACE_OBSERVABILITY svc/loki 3100:3100 &
LOKI_PF_PID=$!

# Grafana (3000)
echo -e "  📈 Grafana: http://localhost:3000"
kubectl port-forward -n $NAMESPACE_OBSERVABILITY svc/grafana 3000:80 &
GRAFANA_PF_PID=$!

# Prometheus (9090)
echo -e "  📊 Prometheus: http://localhost:9090"
kubectl port-forward -n $NAMESPACE_OBSERVABILITY svc/prometheus-server 9090:80 &
PROMETHEUS_PF_PID=$!

# Esperar a que los port-forwards estén listos
echo -e "${YELLOW}⏳ Esperando que los port-forwards estén listos...${NC}"
sleep 10

# Verificar que los endpoints respondan
echo -e "${YELLOW}🔍 Verificando conectividad...${NC}"

ENDPOINTS=(
    "http://localhost:3200/ready:Tempo"
    "http://localhost:3100/ready:Loki"
    "http://localhost:3000/api/health:Grafana"
    "http://localhost:9090/-/ready:Prometheus"
)

for endpoint_name in "${ENDPOINTS[@]}"; do
    endpoint=$(echo $endpoint_name | cut -d: -f1-2)
    name=$(echo $endpoint_name | cut -d: -f3)
    
    if curl -s -f "$endpoint" >/dev/null 2>&1; then
        echo -e "  ✅ $name está respondiendo"
    else
        echo -e "  ⚠️ $name no responde (puede estar iniciando)"
    fi
done

echo ""
echo -e "${GREEN}✅ Port-forwards configurados${NC}"
echo -e "${YELLOW}📋 Servicios disponibles:${NC}"
echo -e "   🎯 Tempo: http://localhost:3200"
echo -e "   📝 Loki: http://localhost:3100"
echo -e "   📈 Grafana: http://localhost:3000"
echo -e "   📊 Prometheus: http://localhost:9090"
echo ""

# Obtener credenciales de Grafana
GRAFANA_PASSWORD=$(kubectl get secret --namespace $NAMESPACE_OBSERVABILITY grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo -e "${YELLOW}🔑 Credenciales de Grafana:${NC}"
echo -e "   Usuario: admin"
echo -e "   Password: $GRAFANA_PASSWORD"
echo ""

echo -e "${YELLOW}🐍 Para ejecutar el analizador de trazas:${NC}"
echo -e "   python3 jenkins_trace_analyzer.py"
echo ""

echo -e "${YELLOW}📊 Dashboard de Jenkins Tempo:${NC}"
echo -e "   http://localhost:3000/d/jenkins-tempo-tracing/jenkins-master-pod-distributed-tracing"
echo ""

echo -e "${GREEN}🎯 Todo listo para el análisis de trazas.${NC}"
echo -e "${YELLOW}💡 Presiona Ctrl+C para cerrar todos los port-forwards.${NC}"

# Mantener los port-forwards activos
echo -e "${YELLOW}⏳ Manteniendo port-forwards activos...${NC}"

# Esperar indefinidamente hasta que se interrumpa
while true; do
    sleep 30
    
    # Verificar que los procesos sigan activos
    active_pfs=0
    for pid in $TEMPO_PF_PID $LOKI_PF_PID $GRAFANA_PF_PID $PROMETHEUS_PF_PID; do
        if kill -0 $pid 2>/dev/null; then
            ((active_pfs++))
        fi
    done
    
    echo -e "${YELLOW}📊 Port-forwards activos: $active_pfs/4${NC}"
    
    if [ $active_pfs -eq 0 ]; then
        echo -e "${RED}❌ Todos los port-forwards se han cerrado${NC}"
        break
    fi
done
