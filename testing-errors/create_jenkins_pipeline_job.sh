#!/bin/bash

# Script para crear el Pipeline Job en Jenkins
set -euo pipefail

JENKINS_URL="http://20.8.71.3:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="admin123"
JOB_NAME="error-testing-pipeline"

echo "=========================================="
echo "🔧 CREANDO PIPELINE JOB EN JENKINS"
echo "=========================================="

echo "📋 Método 1: Creación automática via API..."

# Leer el contenido del pipeline
if [ ! -f "jenkins_error_testing_pipeline_fixed.groovy" ]; then
    echo "❌ Error: No se encuentra el archivo jenkins_error_testing_pipeline_fixed.groovy"
    exit 1
fi

PIPELINE_SCRIPT=$(cat jenkins_error_testing_pipeline_fixed.groovy | sed 's/"/\\"/g' | tr '\n' ' ')

# XML del job con parámetros
JOB_XML=$(cat << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Pipeline de testing que genera errores intencionalmente para monitoreo y troubleshooting</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.TimerTrigger>
          <spec>H/10 * * * *</spec>
        </hudson.triggers.TimerTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>ERROR_TYPE</name>
          <description>Tipo de error a simular</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>ALL</string>
              <string>MEMORY</string>
              <string>FILESYSTEM</string>
              <string>NETWORK</string>
              <string>CRASH</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>FORCE_FAILURE</name>
          <description>Forzar que el pipeline falle</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>DURATION_SECONDS</name>
          <description>Duración de cada etapa en segundos</description>
          <defaultValue>30</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.92">
    <script>PIPELINE_SCRIPT_PLACEHOLDER</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
)

# Reemplazar el placeholder con el script real
PIPELINE_CONTENT=$(cat jenkins_error_testing_pipeline_fixed.groovy)
JOB_XML_FINAL=$(echo "$JOB_XML" | sed "s|PIPELINE_SCRIPT_PLACEHOLDER|${PIPELINE_CONTENT}|")

# Intentar crear el job via API
echo "🔄 Intentando crear job via Jenkins API..."

CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" \
    2>/dev/null || echo "")

if [ -n "$CRUMB" ]; then
    echo "✅ Crumb obtenido: $CRUMB"
    
    # Crear el job
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/jenkins_response.txt \
        -X POST \
        -H "$CRUMB" \
        -H "Content-Type: application/xml" \
        -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        --data-binary "@-" \
        "$JENKINS_URL/createItem?name=$JOB_NAME" << EOF
$JOB_XML_FINAL
EOF
    )
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -c 4)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ Job '$JOB_NAME' creado exitosamente!"
        echo "🔗 URL: $JENKINS_URL/job/$JOB_NAME/"
        echo ""
        echo "🚀 Para ejecutar el pipeline:"
        echo "   1. Ve a: $JENKINS_URL/job/$JOB_NAME/"
        echo "   2. Click en 'Build with Parameters'"
        echo "   3. Selecciona los parámetros deseados"
        echo "   4. Click 'Build'"
        exit 0
    else
        echo "❌ Error al crear job via API (HTTP $HTTP_CODE)"
        cat /tmp/jenkins_response.txt 2>/dev/null || echo "No response details"
    fi
else
    echo "❌ No se pudo obtener CSRF crumb"
fi

echo ""
echo "=========================================="
echo "📋 MÉTODO MANUAL - INSTRUCCIONES"
echo "=========================================="
echo ""
echo "🌐 1. Accede a Jenkins: $JENKINS_URL"
echo "🔑 2. Login: $JENKINS_USER / $JENKINS_PASSWORD"
echo "➕ 3. Click 'New Item'"
echo "📝 4. Nombre: '$JOB_NAME'"
echo "📦 5. Tipo: 'Pipeline'"
echo "✅ 6. Click 'OK'"
echo ""
echo "📋 7. Configuración del Job:"
echo "   📄 Description: 'Pipeline de testing que genera errores para monitoreo'"
echo "   ✅ Marca: 'This project is parameterized'"
echo ""
echo "   ➕ Add Parameter → Choice Parameter:"
echo "      Name: ERROR_TYPE"
echo "      Choices: ALL, MEMORY, FILESYSTEM, NETWORK, CRASH"
echo "      Description: Tipo de error a simular"
echo ""
echo "   ➕ Add Parameter → Boolean Parameter:"
echo "      Name: FORCE_FAILURE"
echo "      Default: false"
echo "      Description: Forzar que el pipeline falle"
echo ""
echo "   ➕ Add Parameter → String Parameter:"
echo "      Name: DURATION_SECONDS"
echo "      Default: 30"
echo "      Description: Duración de cada etapa en segundos"
echo ""
echo "📄 8. En 'Pipeline' section:"
echo "   Definition: 'Pipeline script'"
echo "   Script: [Copiar el contenido del archivo jenkins_error_testing_pipeline_fixed.groovy]"
echo ""
echo "💾 9. Click 'Save'"
echo "🚀 10. Click 'Build with Parameters'"
echo ""
echo "📁 El archivo a copiar está en:"
echo "   $(pwd)/jenkins_error_testing_pipeline_fixed.groovy"
echo ""
echo "=========================================="
echo "🎯 TRIGGERS CONFIGURADOS"
echo "=========================================="
echo "   📅 Timer: Cada 10 minutos (H/10 * * * *)"
echo "   🔧 Manual: Build with Parameters"
echo ""
echo "=========================================="
echo "📊 PARA MONITOREAR RESULTADOS"
echo "=========================================="
echo "   📈 Grafana Dashboards:"
echo "   - Physical Resources: http://135.236.73.36/d/f50a7480-4ff6-4f08-b287-63daea6d00ae"
echo "   - Disk & Inode: http://135.236.73.36/d/ca7aa68f-5b77-4205-a6cb-b2f7133966f2"
echo "   - Critical Alerts: http://135.236.73.36/d/7a41aba6-f616-4347-b751-af5718e8887d"
echo ""
echo "   🔍 Ver pods de testing:"
echo "   kubectl get pods -n testing-errors"
echo ""
echo "   📝 Ver logs del pipeline:"
echo "   kubectl logs -f -n testing-errors -l app=error-testing"
