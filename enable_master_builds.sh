#!/bin/bash

# Script para habilitar el master de Jenkins a ejecutar builds temporalmente

echo "🔧 Habilitando Jenkins Master para ejecutar builds..."

# Configuración rápida para permitir builds en el master
kubectl exec -n jenkins-master jenkins-master-0 -c jenkins -- bash -c '
echo "Configurando Jenkins master para ejecutar builds..."

# Crear script Groovy para habilitar builds en master
cat > /tmp/enable_master_builds.groovy << EOF
import jenkins.model.Jenkins

def jenkins = Jenkins.getInstance()

// Habilitar builds en el master (cambiar de 0 a 2 executors)
jenkins.setNumExecutors(2)
jenkins.setMode(hudson.model.Node.Mode.NORMAL)

jenkins.save()

println "✅ Master configurado para ejecutar builds con 2 executors"
EOF

# Ejecutar el script
groovy /tmp/enable_master_builds.groovy
'

echo "✅ Master configurado para ejecutar builds"

# Verificar el estado
echo "📊 Verificando configuración..."
kubectl logs jenkins-master-0 -n jenkins-master --tail=5

echo ""
echo "🎯 Ahora deberías poder ejecutar pipelines en el master"
echo "💡 Ve a Jenkins UI: http://20.8.71.3:8080"
echo "   - Manage Jenkins > Nodes"
echo "   - Deberías ver 'master' con 2 executors disponibles"
echo ""
echo "⚠️  Nota: Esta es una solución temporal"
echo "   Para producción, deberías usar workers dedicados"
