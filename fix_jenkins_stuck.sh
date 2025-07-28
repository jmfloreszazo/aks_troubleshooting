#!/bin/bash

echo "🧹 Limpiando Jenkins Master..."

# 1. Acceder a Jenkins y limpiar la cola
kubectl exec jenkins-master-0 -n jenkins-master -c jenkins -- bash -c "
echo '🔍 Limpiando archivos de queue atorados...'
rm -f /var/jenkins_home/queue.xml.bak
echo '' > /var/jenkins_home/queue.xml

echo '🗂️ Limpiando builds antiguos atorados...'
find /var/jenkins_home/jobs -name 'builds' -type d -exec find {} -name '*' -mtime +1 -type d -exec rm -rf {} + 2>/dev/null || true

echo '🔄 Reiniciando Jenkins de forma limpia...'
"

echo "✅ Limpieza completada. Jenkins debería arrancar limpio."
