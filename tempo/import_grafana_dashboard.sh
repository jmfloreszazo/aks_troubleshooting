#!/bin/bash

# Script para importar el dashboard de Jenkins Tempo en Grafana
# =============================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE_OBSERVABILITY=${NAMESPACE_OBSERVABILITY:-"observability-stack"}
DASHBOARD_FILE="grafana-config/jenkins-tempo-dashboard.json"

echo -e "${YELLOW}📊 Importando dashboard de Jenkins Tempo en Grafana...${NC}"

# Verificar que el archivo del dashboard existe
if [[ ! -f "${DASHBOARD_FILE}" ]]; then
    echo -e "${RED}❌ Error: No se encontró el archivo del dashboard: ${DASHBOARD_FILE}${NC}"
    exit 1
fi

# Obtener la clave admin de Grafana
GRAFANA_ADMIN_PASSWORD=$(kubectl get secret --namespace ${NAMESPACE_OBSERVABILITY} grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

# Port forward a Grafana temporalmente
echo -e "${YELLOW}🌐 Creando port-forward a Grafana...${NC}"
kubectl port-forward -n ${NAMESPACE_OBSERVABILITY} svc/grafana 3000:80 &
GRAFANA_PF_PID=$!

# Función de cleanup
cleanup() {
    echo -e "${YELLOW}🧹 Cerrando port-forward...${NC}"
    kill $GRAFANA_PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Esperar a que el port-forward esté listo
sleep 5

# Preparar el payload para la API de Grafana
DASHBOARD_JSON=$(cat "${DASHBOARD_FILE}")
PAYLOAD=$(jq -n --argjson dashboard "$DASHBOARD_JSON" '{
  dashboard: $dashboard,
  overwrite: true,
  inputs: []
}')

# Importar el dashboard
echo -e "${YELLOW}📊 Importando dashboard...${NC}"
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "admin:${GRAFANA_ADMIN_PASSWORD}" \
  -d "$PAYLOAD" \
  http://localhost:3000/api/dashboards/db)

# Verificar el resultado
if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null; then
    DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url')
    echo -e "${GREEN}✅ Dashboard importado exitosamente${NC}"
    echo -e "${YELLOW}🔗 URL del dashboard: http://localhost:3000${DASHBOARD_URL}${NC}"
else
    echo -e "${RED}❌ Error al importar el dashboard:${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

echo -e "${GREEN}✅ Configuración completada${NC}"
echo -e "${YELLOW}📝 Para acceder a Grafana:${NC}"
echo -e "   kubectl port-forward -n ${NAMESPACE_OBSERVABILITY} svc/grafana 3000:80"
echo -e "   Usuario: admin"
echo -e "   Password: ${GRAFANA_ADMIN_PASSWORD}"
echo -e "   Dashboard: Jenkins Master-Pod Distributed Tracing"
