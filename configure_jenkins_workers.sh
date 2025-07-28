#!/bin/bash

# Script para configurar Jenkins con workers de Kubernetes

echo "🔧 Configurando Jenkins para usar workers de Kubernetes..."

# Actualizar Jenkins con la nueva configuración
echo "📦 Actualizando Jenkins con agentes habilitados..."
cd /mnt/c/sources/platfrom_engineer/aks_troubleshooting_v2

# Aplicar la nueva configuración de Helm
helm upgrade jenkins-master ./helm/jenkins \
  -f helm/jenkins_helm_values.yaml \
  -n jenkins-master \
  --wait

echo "✅ Jenkins actualizado con agentes habilitados"

# Verificar el estado
echo "📊 Verificando estado de los pods..."
kubectl get pods -n jenkins-master
kubectl get pods -n jenkins-workers

echo ""
echo "🔍 Verificando logs de Jenkins..."
kubectl logs jenkins-master-0 -n jenkins-master --tail=10

echo ""
echo "🎯 Próximos pasos:"
echo "1. Ve a Jenkins UI: http://20.8.71.3:8080"
echo "2. Ve a Manage Jenkins > Nodes"
echo "3. Deberías ver la nube de Kubernetes configurada"
echo "4. Ejecuta un pipeline para probar que se creen workers automáticamente"

echo ""
echo "💡 Si aún no funciona, necesitaremos configurar la nube de Kubernetes manualmente en Jenkins"
