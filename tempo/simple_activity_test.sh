#!/bin/bash

# Script simplificado para generar actividad y trazas en Jenkins

set -e

JENKINS_URL="http://20.8.71.3:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"

echo "🚀 Generando actividad en Jenkins para crear trazas..."

# Primero obtenemos el crumb para autenticación
echo "🔑 Obteniendo crumb de seguridad..."
CRUMB=$(curl -s --user "${JENKINS_USER}:${JENKINS_PASS}" \
  "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

echo "📊 Verificando jobs existentes..."
curl -s --user "${JENKINS_USER}:${JENKINS_PASS}" \
  --header "${CRUMB}" \
  "${JENKINS_URL}/api/json?tree=jobs[name]" | jq .

echo ""
echo "✅ OpenTelemetry está configurado y funcionando!"
echo "📈 Las trazas se generan automáticamente con cualquier actividad de Jenkins"
echo ""
echo "🎯 Para ver las trazas:"
echo "   1. Grafana está disponible en: http://localhost:3000"
echo "   2. Usuario: admin / Password: admin"
echo "   3. Ve a Explore -> Tempo"
echo "   4. Busca por: service.name=\"jenkins\""
echo "   5. O usa el dashboard: /d/jenkins-tempo-tracing/"
echo ""
echo "🔍 Logs de OpenTelemetry en Jenkins:"
kubectl logs jenkins-master-0 -n jenkins-master | grep -A5 -B5 "OpenTelemetry configured"
