#!/bin/bash

# Script para configurar Tempo como datasource en Grafana
# =====================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE_OBSERVABILITY=${NAMESPACE_OBSERVABILITY:-"observability-stack"}

echo -e "${YELLOW}🔧 Configurando Tempo como datasource en Grafana...${NC}"

# Obtener la clave admin de Grafana
GRAFANA_ADMIN_PASSWORD=$(kubectl get secret --namespace ${NAMESPACE_OBSERVABILITY} grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

# Port forward a Grafana temporalmente
echo -e "${YELLOW}🌐 Creando port-forward a Grafana...${NC}"
kubectl port-forward -n ${NAMESPACE_OBSERVABILITY} svc/grafana 3000:80 &
GRAFANA_PF_PID=$!

# Esperar a que el port-forward esté listo
sleep 5

# Crear datasource de Tempo
echo -e "${YELLOW}📊 Agregando Tempo como datasource...${NC}"
curl -X POST \
  -H "Content-Type: application/json" \
  -u "admin:${GRAFANA_ADMIN_PASSWORD}" \
  -d '{
    "name": "Tempo",
    "type": "tempo",
    "access": "proxy",
    "url": "http://tempo:3200",
    "basicAuth": false,
    "isDefault": false,
    "jsonData": {
      "httpMethod": "GET",
      "serviceMap": {
        "datasourceUid": "prometheus"
      },
      "search": {
        "hide": false
      },
      "lokiSearch": {
        "datasourceUid": "loki"
      },
      "tracesToLogs": {
        "datasourceUid": "loki",
        "tags": ["service", "pod", "namespace"],
        "mappedTags": [
          {"key": "service.name", "value": "service"},
          {"key": "k8s.pod.name", "value": "pod"}
        ],
        "mapTagNamesEnabled": true,
        "spanStartTimeShift": "-1h",
        "spanEndTimeShift": "1h"
      },
      "tracesToMetrics": {
        "datasourceUid": "prometheus",
        "tags": [
          {"key": "service.name", "value": "service"},
          {"key": "k8s.pod.name", "value": "pod"}
        ],
        "queries": [
          {
            "name": "Sample query",
            "query": "sum(rate(tempo_span_metrics_latency_bucket[5m]))"
          }
        ]
      }
    }
  }' \
  http://localhost:3000/api/datasources

# Cleanup
kill $GRAFANA_PF_PID 2>/dev/null || true

echo -e "${GREEN}✅ Tempo datasource configurado en Grafana${NC}"
echo -e "${YELLOW}📝 Para acceder a Grafana:${NC}"
echo -e "   kubectl port-forward -n ${NAMESPACE_OBSERVABILITY} svc/grafana 3000:80"
echo -e "   Usuario: admin"
echo -e "   Password: ${GRAFANA_ADMIN_PASSWORD}"
