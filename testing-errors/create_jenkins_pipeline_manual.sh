#!/bin/bash

# Script para crear pipeline de Jenkins manualmente con configuración completa

echo "=========================================="
echo "🔧 CONFIGURACIÓN DE PIPELINE DE JENKINS"
echo "=========================================="

echo "📋 PIPELINE GROOVY CODE:"
echo "Copia el siguiente código en Jenkins UI:"
echo ""

cat << 'EOF'
pipeline {
    agent {
        kubernetes {
            label "error-testing-${env.BUILD_NUMBER}"
            yaml """
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    purpose: errors
  tolerations:
  - key: "purpose"
    operator: "Equal"
    value: "errors"
    effect: "NoSchedule"
  containers:
  - name: tester
    image: ubuntu:22.04
    command:
    - sleep
    args:
    - 99d
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "500Mi"
        cpu: "500m"
"""
        }
    }
    
    stages {
        stage('Error Testing Stage 1') {
            steps {
                script {
                    echo "🚨 Iniciando testing de errores..."
                    
                    sh '''
                        echo "INFO: Iniciando proceso en $(date)..."
                        echo "INFO: Nodo asignado: $(hostname)"
                        echo "INFO: Información del sistema:"
                        df -h / || echo "ERROR: No se pudo obtener info del disco"
                        free -h || echo "ERROR: No se pudo obtener info de memoria"
                        sleep 5
                    '''
                    
                    // 30% de probabilidad de fallo
                    def shouldFail = Math.random() > 0.7
                    if (shouldFail) {
                        echo "💥 Simulando fallo..."
                        error "ERROR: Fallo simulado en Stage 1 - Testing de monitoreo"
                    } else {
                        echo "✅ Stage 1 completado exitosamente"
                    }
                }
            }
        }
        
        stage('Memory Intensive Stage') {
            steps {
                script {
                    echo "💾 Iniciando stage intensivo en memoria..."
                    
                    sh '''
                        echo "WARNING: Consumiendo memoria..."
                        # Crear archivo de 50MB para simular uso de memoria
                        dd if=/dev/zero of=/tmp/bigfile bs=1M count=50 2>/dev/null || echo "ERROR: No se pudo crear archivo grande"
                        
                        if [ -f "/tmp/bigfile" ]; then
                            echo "INFO: Archivo creado: $(ls -lh /tmp/bigfile)"
                        else
                            echo "ERROR: Archivo no creado"
                        fi
                        
                        echo "INFO: Uso de memoria actual:"
                        free -h || echo "ERROR: No se pudo obtener memoria"
                        
                        sleep 10
                        rm -f /tmp/bigfile
                        echo "INFO: Limpieza de memoria completada"
                    '''
                }
            }
        }
        
        stage('File System Stress') {
            steps {
                script {
                    echo "📁 Testing de stress del filesystem..."
                    
                    sh '''
                        echo "INFO: Creando muchos archivos pequeños..."
                        mkdir -p /tmp/stress-test
                        
                        # Crear 500 archivos pequeños
                        for i in $(seq 1 500); do
                            echo "Archivo de test $i con contenido aleatorio $(date) - datos adicionales para testing" > "/tmp/stress-test/file_$i.txt"
                        done
                        
                        echo "INFO: Archivos creados: $(ls /tmp/stress-test | wc -l)"
                        echo "INFO: Espacio usado en /tmp: $(du -sh /tmp/stress-test)"
                        echo "INFO: Inodos disponibles: $(df -i /tmp)"
                        
                        # 25% de probabilidad de fallo
                        if [ $((RANDOM % 4)) -eq 0 ]; then
                            echo "CRITICAL: Error crítico simulado en filesystem"
                            echo "FATAL: Sistema de archivos bajo stress - Fallo simulado"
                            exit 1
                        fi
                        
                        # Limpiar archivos
                        rm -rf /tmp/stress-test
                        echo "INFO: Limpieza de filesystem completada"
                    '''
                }
            }
        }
        
        stage('Network Error Simulation') {
            steps {
                script {
                    echo "🌐 Simulando errores de red..."
                    
                    sh '''
                        echo "INFO: Testing conectividad..."
                        
                        # Intentar conectar a servicios reales y falsos
                        echo "INFO: Probando conexión a Google DNS..."
                        ping -c 1 8.8.8.8 || echo "WARNING: No se pudo hacer ping a 8.8.8.8"
                        
                        echo "INFO: Probando conexión a servicio inexistente..."
                        curl -m 5 http://servicio-inexistente:8080/health || echo "ERROR: No se pudo conectar al servicio (esperado)"
                        
                        echo "INFO: Simulando timeout..."
                        timeout 3 sleep 5 || echo "WARNING: Timeout simulado (esperado)"
                        
                        # Generar algunos errores de red simulados
                        echo "ERROR: Connection refused to database server"
                        echo "WARNING: High latency detected: 5000ms"
                        echo "CRITICAL: Service mesh failure detected"
                        
                        echo "INFO: Tests de red completados"
                    '''
                }
            }
        }
        
        stage('Resource Monitor') {
            steps {
                script {
                    echo "📊 Monitoreando recursos del sistema..."
                    
                    sh '''
                        echo "INFO: Estado de recursos del contenedor:"
                        echo "CPU Info:"
                        cat /proc/loadavg || echo "ERROR: No se pudo obtener load average"
                        
                        echo "Memory Info:"
                        cat /proc/meminfo | head -10 || echo "ERROR: No se pudo obtener info de memoria"
                        
                        echo "Disk Info:"
                        df -h || echo "ERROR: No se pudo obtener info de disco"
                        
                        echo "Process Info:"
                        ps aux | head -10 || echo "ERROR: No se pudo obtener info de procesos"
                        
                        echo "INFO: Monitoreo de recursos completado"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Limpieza post-pipeline..."
                sh '''
                    echo "INFO: Pipeline completado en $(date)"
                    echo "METRICS: Tiempo total de ejecución registrado"
                    echo "INFO: Limpiando archivos temporales..."
                    rm -rf /tmp/stress-test /tmp/bigfile 2>/dev/null || true
                    echo "INFO: Limpieza completada"
                '''
            }
        }
        failure {
            script {
                echo "❌ Pipeline falló..."
                sh '''
                    echo "ERROR: Pipeline falló en $(date)"
                    echo "FATAL: Se requiere intervención manual"
                    echo "STACKTRACE: Error en pipeline de testing"
                    echo "ALERT: Pipeline failure detected - monitoring system should trigger alerts"
                '''
            }
        }
        success {
            script {
                echo "✅ Pipeline exitoso..."
                sh '''
                    echo "SUCCESS: Pipeline completado exitosamente en $(date)"
                    echo "INFO: Todos los tests pasaron"
                    echo "METRICS: Success rate logged"
                '''
            }
        }
    }
}
EOF

echo ""
echo "============================================="
echo "📋 INSTRUCCIONES PARA CREAR EL PIPELINE"
echo "============================================="
echo ""
echo "1. 🌐 Abrir Jenkins: http://20.8.71.3:8080"
echo "   Usuario: admin"
echo "   Password: admin123"
echo ""
echo "2. 📝 Crear nuevo Job:"
echo "   - Clic en 'New Item'"
echo "   - Nombre: 'error-testing-pipeline'"
echo "   - Seleccionar 'Pipeline'"
echo "   - Clic 'OK'"
echo ""
echo "3. ⚙️ Configurar el Pipeline:"
echo "   - En la sección 'Pipeline':"
echo "   - Seleccionar 'Pipeline script'"
echo "   - Copiar y pegar el código Groovy de arriba"
echo ""
echo "4. ⏰ Configurar Trigger (opcional):"
echo "   - En 'Build Triggers'"
echo "   - Marcar 'Build periodically'"
echo "   - Schedule: 'H/5 * * * *' (cada 5 minutos)"
echo ""
echo "5. 💾 Guardar y ejecutar:"
echo "   - Clic 'Save'"
echo "   - Clic 'Build Now'"
echo ""
echo "🎯 FUNCIONALIDADES DEL PIPELINE:"
echo "   - ✅ Se ejecuta en nodos 'errors'"
echo "   - 📄 Genera archivos para stress de inodos"
echo "   - 💾 Consume memoria intensivamente"
echo "   - 📝 Genera logs de diferentes tipos"
echo "   - 🌐 Simula errores de red"
echo "   - 💥 Falla aleatoriamente (30% probabilidad)"
echo "   - 📊 Monitorea recursos del sistema"
echo ""
echo "📊 MONITOREO:"
echo "Este pipeline activará alertas en los dashboards de Grafana"
echo "cuando consuma recursos o falle."

# Función para verificar el estado actual
show_current_status() {
    echo ""
    echo "============================================="
    echo "📊 ESTADO ACTUAL DEL ENTORNO DE TESTING"
    echo "============================================="
    
    echo ""
    echo "🖥️ NODOS 'ERRORS':"
    kubectl get nodes -l purpose=errors -o wide
    
    echo ""
    echo "📦 PODS EN TESTING-ERRORS:"
    kubectl get pods -n testing-errors -o wide
    
    echo ""
    echo "📈 USO DE RECURSOS:"
    kubectl top pods -n testing-errors 2>/dev/null || echo "❌ Metrics server no disponible"
    
    echo ""
    echo "📝 LOGS RECIENTES (LOG-GENERATOR):"
    kubectl logs -n testing-errors deployment/log-generator --tail=10 2>/dev/null | head -5
    
    echo ""
    echo "💥 REINICISIONES (CRASH-APP):"
    kubectl get pods -n testing-errors | grep crash-app
    
    echo ""
    echo "🔧 JENKINS:"
    echo "URL: http://20.8.71.3:8080"
    echo "Para crear el pipeline manualmente, sigue las instrucciones de arriba."
}

show_current_status
