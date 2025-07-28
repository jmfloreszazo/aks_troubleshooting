#!/bin/bash

# Script para probar el tracing de OpenTelemetry en Jenkins
# Este script ejecuta un job simple y verifica las trazas

set -e

JENKINS_URL="http://20.8.71.3:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"

echo "🔍 Probando OpenTelemetry tracing en Jenkins..."

# Crear un job simple de prueba
echo "📝 Creando job de prueba para generar trazas..."

# XML del job
JOB_XML='<?xml version="1.0" encoding="UTF-8"?>
<project>
  <description>Job de prueba para generar trazas OpenTelemetry</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>#!/bin/bash
echo "🚀 Iniciando job de prueba - $(date)"
echo "📊 Generando actividad para OpenTelemetry tracing"
sleep 5
echo "✅ Completado - $(date)"
echo "📈 Esta actividad debería aparecer en Grafana/Tempo"
      </command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>'

# Crear el job
curl -X POST \
  --user "${JENKINS_USER}:${JENKINS_PASS}" \
  --data-binary "${JOB_XML}" \
  --header "Content-Type: application/xml" \
  "${JENKINS_URL}/createItem?name=test-otel-tracing"

echo "✅ Job 'test-otel-tracing' creado"

# Ejecutar el job
echo "🚀 Ejecutando job para generar trazas..."
BUILD_NUMBER=$(curl -X POST \
  --user "${JENKINS_USER}:${JENKINS_PASS}" \
  "${JENKINS_URL}/job/test-otel-tracing/build" \
  -s -D /tmp/headers | grep -i location | cut -d'/' -f6)

echo "🔄 Build iniciado. Esperando completado..."
sleep 15

# Verificar el resultado
echo "📋 Verificando resultado del build..."
curl -X GET \
  --user "${JENKINS_USER}:${JENKINS_PASS}" \
  "${JENKINS_URL}/job/test-otel-tracing/lastBuild/api/json?pretty" \
  | jq '.result,.timestamp,.duration'

echo ""
echo "🎯 Trazas generadas. Verifica en Grafana:"
echo "   URL: http://grafana.observability-stack.svc.cluster.local:3000/d/jenkins-tempo-tracing/"
echo ""
echo "🔍 Para ver las trazas en Tempo directamente:"
kubectl port-forward -n observability-stack svc/grafana 3000:3000 &
PID=$!
sleep 3
echo "   Grafana disponible en: http://localhost:3000"
echo "   Usuario: admin / Password: admin"
echo ""
echo "⏹️  Para parar el port-forward: kill $PID"
