#!/bin/bash

# Script de diagnóstico detallado de inodos en nodos AKS
# Conecta directamente a los nodos para analizar el problema de inodos

set -euo pipefail

echo "=========================================="
echo "🔬 DIAGNÓSTICO DETALLADO DE INODOS EN NODOS"
echo "=========================================="

# Función para obtener pods de debugging en cada nodo
create_debug_pods() {
    echo "🛠️  CREANDO PODS DE DEBUG EN CADA NODO..."
    echo "----------------------------------------"
    
    # Obtener lista de nodos
    nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        echo "📱 Creando pod debug para nodo: $node"
        
        # Crear pod privilegiado para acceso al nodo
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: debug-$node
  namespace: default
spec:
  nodeName: $node
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: debug
    image: ubuntu:22.04
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host-root
      mountPath: /host
      readOnly: false
  volumes:
  - name: host-root
    hostPath:
      path: /
  restartPolicy: Never
  tolerations:
  - operator: Exists
EOF
        
        # Esperar a que el pod esté listo
        echo "⏳ Esperando que el pod debug-$node esté listo..."
        kubectl wait --for=condition=Ready pod/debug-$node --timeout=60s 2>/dev/null || echo "❌ Timeout esperando pod debug-$node"
    done
}

# Función para analizar inodos en cada nodo
analyze_inodes_per_node() {
    echo ""
    echo "🔍 ANALIZANDO INODOS EN CADA NODO..."
    echo "----------------------------------------"
    
    nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        echo ""
        echo "🖥️  ANÁLISIS DEL NODO: $node"
        echo "=============================="
        
        # Verificar si el pod debug existe
        if kubectl get pod debug-$node >/dev/null 2>&1; then
            echo "📊 Información básica del filesystem:"
            kubectl exec debug-$node -- chroot /host df -h / 2>/dev/null || echo "❌ Error obteniendo df -h"
            kubectl exec debug-$node -- chroot /host df -i / 2>/dev/null || echo "❌ Error obteniendo df -i"
            
            echo ""
            echo "🔍 Top 10 directorios con más archivos:"
            kubectl exec debug-$node -- chroot /host sh -c '
                echo "📁 /var/log:"
                find /var/log -type f 2>/dev/null | wc -l
                echo "📁 /tmp:"
                find /tmp -type f 2>/dev/null | wc -l
                echo "📁 /var/tmp:"
                find /var/tmp -type f 2>/dev/null | wc -l
                echo "📁 /var/lib/docker:"
                find /var/lib/docker -type f 2>/dev/null | wc -l || echo "Docker no encontrado"
                echo "📁 /var/lib/containerd:"
                find /var/lib/containerd -type f 2>/dev/null | wc -l || echo "Containerd no encontrado"
                echo "📁 /var/lib/kubelet:"
                find /var/lib/kubelet -type f 2>/dev/null | wc -l || echo "Kubelet no encontrado"
            ' 2>/dev/null || echo "❌ Error ejecutando análisis de directorios"
            
            echo ""
            echo "📊 Análisis de inodos por directorio raíz:"
            kubectl exec debug-$node -- chroot /host sh -c '
                echo "Directorio | Número de archivos"
                echo "--------------------------------"
                for dir in /var /tmp /usr /opt /home /root; do
                    if [ -d "$dir" ]; then
                        count=$(find "$dir" -type f 2>/dev/null | wc -l)
                        echo "$dir: $count archivos"
                    fi
                done
            ' 2>/dev/null || echo "❌ Error en análisis detallado"
            
            echo ""
            echo "🐳 Información de contenedores:"
            kubectl exec debug-$node -- chroot /host sh -c '
                if command -v crictl >/dev/null 2>&1; then
                    echo "Contenedores activos:"
                    crictl ps --quiet | wc -l
                    echo "Imágenes:"
                    crictl images --quiet | wc -l
                else
                    echo "crictl no disponible"
                fi
            ' 2>/dev/null || echo "❌ Error obteniendo info de contenedores"
            
        else
            echo "❌ Pod debug-$node no encontrado"
        fi
    done
}

# Función para generar reporte detallado
generate_detailed_report() {
    echo ""
    echo "📋 GENERANDO REPORTE DETALLADO..."
    echo "----------------------------------------"
    
    # Crear archivo de reporte
    report_file="/tmp/inode_analysis_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "REPORTE DE ANÁLISIS DE INODOS"
        echo "Fecha: $(date)"
        echo "=========================================="
        echo ""
        
        echo "🖥️  INFORMACIÓN DEL CLUSTER:"
        kubectl cluster-info
        echo ""
        
        echo "📊 ESTADO DE LOS NODOS:"
        kubectl get nodes -o wide
        echo ""
        
        echo "📦 PODS POR NAMESPACE:"
        kubectl get pods --all-namespaces | awk '{print $1}' | sort | uniq -c | sort -nr
        echo ""
        
        echo "💾 USO DE RECURSOS:"
        kubectl top nodes 2>/dev/null || echo "Metrics server no disponible"
        echo ""
        
        nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
        for node in $nodes; do
            echo "=========================================="
            echo "NODO: $node"
            echo "=========================================="
            
            if kubectl get pod debug-$node >/dev/null 2>&1; then
                echo "Filesystem info:"
                kubectl exec debug-$node -- chroot /host df -h / 2>/dev/null
                kubectl exec debug-$node -- chroot /host df -i / 2>/dev/null
                echo ""
                
                echo "Análisis de archivos por directorio:"
                kubectl exec debug-$node -- chroot /host sh -c '
                    for dir in /var/log /tmp /var/tmp /var/lib/docker /var/lib/containerd /var/lib/kubelet; do
                        if [ -d "$dir" ]; then
                            count=$(find "$dir" -type f 2>/dev/null | wc -l)
                            echo "$dir: $count archivos"
                        fi
                    done
                ' 2>/dev/null
                echo ""
            fi
        done
        
    } > "$report_file"
    
    echo "✅ Reporte generado en: $report_file"
    echo ""
    echo "📄 Para ver el reporte:"
    echo "   cat $report_file"
}

# Función para limpiar pods debug
cleanup_debug_pods() {
    echo ""
    echo "🧹 LIMPIANDO PODS DEBUG..."
    echo "----------------------------------------"
    
    nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        echo "🗑️  Eliminando debug-$node..."
        kubectl delete pod debug-$node --ignore-not-found=true
    done
    
    echo "✅ Limpieza completada"
}

# Función para mostrar comandos útiles
show_useful_commands() {
    echo ""
    echo "🛠️  COMANDOS ÚTILES PARA EJECUTAR EN LOS NODOS..."
    echo "----------------------------------------"
    
    echo "Para conectar directamente a un nodo y ejecutar comandos:"
    echo ""
    echo "1. 🔍 Análisis detallado de inodos:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "df -i && echo && du -s /var/log/* | sort -nr | head -10"'
    echo ""
    echo "2. 📁 Encontrar directorios con más archivos:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "find /var -type d -exec sh -c '"'"'echo \"{} \$(find \"{}\" -maxdepth 1 -type f | wc -l)\"'"'"' \; | sort -nrk2 | head -10"'
    echo ""
    echo "3. 🐳 Limpiar recursos de contenedores:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "crictl rmi --prune && crictl rmp"'
    echo ""
    echo "4. 📊 Análisis de archivos temporales:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "find /tmp -type f -mtime +1 | wc -l"'
    echo ""
    echo "5. 🔍 Buscar archivos muy pequeños que consumen inodos:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "find /var -type f -size -1k | head -20"'
}

# Función principal
main() {
    echo "🎯 Iniciando diagnóstico detallado de inodos en nodos AKS"
    echo "Este proceso creará pods debug privilegiados en cada nodo."
    echo ""
    
    read -p "¿Continuar con el diagnóstico? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Diagnóstico cancelado"
        exit 0
    fi
    
    create_debug_pods
    sleep 10  # Dar tiempo a que los pods se inicien
    analyze_inodes_per_node
    generate_detailed_report
    show_useful_commands
    
    echo ""
    echo "============================================="
    echo "✅ DIAGNÓSTICO COMPLETADO"
    echo "============================================="
    echo ""
    echo "🎯 PRÓXIMOS PASOS:"
    echo "   1. Revisar el reporte generado"
    echo "   2. Usar los comandos útiles para análisis específico"
    echo "   3. Ejecutar limpieza si es necesario"
    echo "   4. Eliminar pods debug cuando termine"
    echo ""
    echo "🧹 Para limpiar los pods debug:"
    echo "   $0 cleanup"
    echo ""
    echo "📊 Dashboard de monitoreo:"
    echo "   http://135.236.73.36/d/ca7aa68f-5b77-4205-a6cb-b2f7133966f2"
}

# Verificar argumentos
if [ "${1:-}" = "cleanup" ]; then
    cleanup_debug_pods
    exit 0
fi

# Ejecutar función principal
main "$@"
