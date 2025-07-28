#!/bin/bash

# Script para configurar Jenkins via API REST

echo "🔧 Configurando Jenkins Master via API REST..."

# Obtener la IP externa de Jenkins
JENKINS_URL="http://20.8.71.3:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"

echo "📡 Verificando conectividad con Jenkins..."
curl -s -o /dev/null -w "Jenkins HTTP Status: %{http_code}\n" "$JENKINS_URL"

echo ""
echo "🔧 SOLUCIÓN MANUAL PARA HABILITAR EXECUTORS:"
echo ""
echo "1. Ve a Jenkins UI: $JENKINS_URL"
echo "   Usuario: $JENKINS_USER"
echo "   Password: $JENKINS_PASS"
echo ""
echo "2. Ve a: Manage Jenkins > Nodes"
echo ""
echo "3. Click en 'master' (Built-In Node)"
echo ""
echo "4. Click 'Configure'"
echo ""
echo "5. Cambia 'Number of executors' de 0 a 2"
echo ""
echo "6. En 'Usage': selecciona 'Use this node as much as possible'"
echo ""
echo "7. Click 'Save'"
echo ""
echo "✅ Esto permitirá que el master ejecute builds inmediatamente"
echo ""
echo "🎯 VERIFICAR EL PROBLEMA ACTUAL:"
echo "   - Ve a: Manage Jenkins > Nodes"
echo "   - Si ves 'kubernetes' cloud configurada pero sin workers"
echo "   - Indica que la configuración de Kubernetes está mal"
echo ""
echo "💡 ALTERNATIVA: Configurar workers manualmente"
echo "   - Ve a: Manage Jenkins > Manage Clouds"
echo "   - Configure Kubernetes cloud con estos datos:"
echo "     * Kubernetes URL: https://kubernetes.default.svc.cluster.local"
echo "     * Namespace: jenkins-workers"
echo "     * Jenkins URL: http://jenkins-master.jenkins-master.svc.cluster.local:8080"
echo "     * Jenkins tunnel: jenkins-master-agent.jenkins-master.svc.cluster.local:50000"

# Verificar el estado actual de nodos
echo ""
echo "📊 Estado actual del cluster:"
kubectl get nodes -o wide
echo ""
echo "📊 Servicios de Jenkins:"
kubectl get svc -n jenkins-master
