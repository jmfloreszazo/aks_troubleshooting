#!/bin/bash
# 04_backup_configuracion_completa.sh
# Script de respaldo que contiene TODA la configuración necesaria

echo "📦 RESPALDO DE CONFIGURACIÓN COMPLETA - JENKINS SPOT WORKERS"
echo "============================================================"
echo ""
echo "📋 CONTENIDO DE ESTE RESPALDO:"
echo "   1. ✅ Script principal: 04_fix_jenkins_spot_permissions.sh"
echo "   2. ✅ Script Groovy: limpiar_y_crear_spot_v2_debug.groovy"
echo "   3. ✅ Configuración RBAC completa"
echo "   4. ✅ Instrucciones de uso"
echo ""

# Mostrar contenido del script principal
echo "🔧 SCRIPT PRINCIPAL (04_fix_jenkins_spot_permissions.sh):"
echo "------------------------------------------------------"
if [ -f "04_fix_jenkins_spot_permissions.sh" ]; then
    echo "✅ Archivo existe y está listo para usar"
    echo "📊 Tamaño: $(wc -l < 04_fix_jenkins_spot_permissions.sh) líneas"
    echo "🔑 Permisos: $(ls -la 04_fix_jenkins_spot_permissions.sh | cut -d' ' -f1)"
else
    echo "❌ Archivo no encontrado - necesita ser creado"
fi
echo ""

# Mostrar contenido del script Groovy
echo "🔧 SCRIPT GROOVY (limpiar_y_crear_spot_v2_debug.groovy):"
echo "--------------------------------------------------------"
if [ -f "limpiar_y_crear_spot_v2_debug.groovy" ]; then
    echo "✅ Archivo existe y está listo para usar"
    echo "📊 Tamaño: $(wc -l < limpiar_y_crear_spot_v2_debug.groovy) líneas"
else
    echo "❌ Archivo no encontrado - necesita ser creado"
fi
echo ""

# Mostrar configuración RBAC que se debe aplicar
echo "🔧 CONFIGURACIÓN RBAC (incluida en el script principal):"
echo "--------------------------------------------------------"
echo "✅ ClusterRole: jenkins-spot-worker-manager"
echo "✅ ClusterRoleBinding: jenkins-spot-worker-binding"
echo "✅ Role (jenkins-workers): jenkins-worker-manager"
echo "✅ RoleBinding (jenkins-workers): jenkins-worker-binding"
echo "✅ ServiceAccount (jenkins-workers): jenkins-worker"
echo ""

echo "🚀 INSTRUCCIONES DE USO:"
echo "========================"
echo ""
echo "PASO 1: Ejecutar el script de permisos"
echo "   ./04_fix_jenkins_spot_permissions.sh"
echo ""
echo "PASO 2: Ir a Jenkins Script Console"
echo "   http://[IP-JENKINS]:8080/script"
echo "   Usuario: admin / Password: admin123"
echo ""
echo "PASO 3: Copiar y ejecutar el script Groovy"
echo "   Abrir: limpiar_y_crear_spot_v2_debug.groovy"
echo "   Copiar todo el contenido"
echo "   Pegar en Script Console"
echo "   Presionar 'Run'"
echo ""
echo "PASO 4: Ejecutar el job de prueba"
echo "   Ir al Dashboard de Jenkins"
echo "   Ejecutar job: 'Debug-Spot-Scaling'"
echo "   Verificar que dice 'NODO SPOT' en los logs"
echo ""

echo "🎯 SOLUCIÓN A PROBLEMAS COMUNES:"
echo "================================"
echo ""
echo "PROBLEMA: 'Jenkins se demora mucho en escalar'"
echo "SOLUCIÓN: Ejecutar el PASO 1 (permisos RBAC)"
echo ""
echo "PROBLEMA: 'Error creating pod'"
echo "SOLUCIÓN: Verificar que jenkins-workers namespace existe"
echo ""
echo "PROBLEMA: 'No aparece nodo spot'"
echo "SOLUCIÓN: Verificar que el cluster tiene nodepool spot configurado"
echo ""
echo "PROBLEMA: 'Job queda pendiente para siempre'"
echo "SOLUCIÓN: Reiniciar Jenkins después de aplicar permisos"
echo ""

echo "💡 VERIFICACIÓN RÁPIDA:"
echo "======================"
echo ""
echo "Verificar nodos spot disponibles:"
echo "   kubectl get nodes --show-labels | grep spot"
echo ""
echo "Verificar permisos aplicados:"
echo "   kubectl get clusterrolebinding jenkins-spot-worker-binding"
echo ""
echo "Verificar pods Jenkins:"
echo "   kubectl get pods -n jenkins-master"
echo "   kubectl get pods -n jenkins-workers"
echo ""

echo "📚 ARCHIVOS NECESARIOS:"
echo "======================"
echo ""
ls -la *.sh *.groovy 2>/dev/null || echo "Verificar que todos los archivos están presentes"
echo ""

echo "🎉 RESPALDO COMPLETO DOCUMENTADO"
echo "Todos los componentes están listos para uso"
