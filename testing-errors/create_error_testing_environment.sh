#!/bin/bash

# Script para crear un nodo pool de "errors" y desplegar aplicaciones problemáticas
# para testing de monitoreo y troubleshooting

set -euo pipefail

# Cargar configuración del .env.production
source /mnt/c/sources/platfrom_engineer/aks_troubleshooting_v2/.env.production

echo "=========================================="
echo "🚨 CREANDO NODO POOL DE TESTING DE ERRORES"
echo "=========================================="

# Función para crear el nodo pool de errores
create_error_node_pool() {
    echo "🖥️  Creando nodo pool 'errors'..."
    
    az aks nodepool add \
        --resource-group "$RESOURCE_GROUP" \
        --cluster-name "$CLUSTER_NAME" \
        --name "errors" \
        --node-count 1 \
        --node-vm-size "Standard_DS2_v2" \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 2 \
        --node-taints "purpose=errors:NoSchedule" \
        --labels purpose=errors type=testing \
        --tags purpose=errors environment=testing \
        --zones 1 2 3
    
    echo "✅ Nodo pool 'errors' creado exitosamente"
}

# Función para crear namespace de testing
create_testing_namespace() {
    echo "📁 Creando namespace de testing..."
    
    kubectl create namespace testing-errors --dry-run=client -o yaml | kubectl apply -f -
    
    # Etiquetar el namespace
    kubectl label namespace testing-errors purpose=errors type=testing
    
    echo "✅ Namespace 'testing-errors' creado"
}

# Función para desplegar aplicación que consume inodos masivamente
deploy_inode_consumer() {
    echo "📄 Desplegando aplicación que consume inodos..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inode-consumer
  namespace: testing-errors
  labels:
    app: inode-consumer
    purpose: testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inode-consumer
  template:
    metadata:
      labels:
        app: inode-consumer
        purpose: testing
    spec:
      nodeSelector:
        purpose: errors
      tolerations:
      - key: "purpose"
        operator: "Equal"
        value: "errors"
        effect: "NoSchedule"
      containers:
      - name: inode-consumer
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "🔥 Iniciando consumidor de inodos masivo..."
          mkdir -p /tmp/inode-test
          cd /tmp/inode-test
          
          # Crear muchos archivos pequeños
          for i in \$(seq 1 10000); do
            echo "archivo \$i" > "archivo_\${i}.txt"
            if [ \$((i % 1000)) -eq 0 ]; then
              echo "📄 Creados \$i archivos..."
              sleep 2
            fi
          done
          
          echo "✅ 10,000 archivos creados para testing de inodos"
          
          # Mantener el contenedor vivo
          while true; do
            echo "📊 Total archivos: \$(find /tmp/inode-test -type f | wc -l)"
            sleep 30
          done
        resources:
          requests:
            memory: "100Mi"
            cpu: "100m"
          limits:
            memory: "500Mi"
            cpu: "500m"
        volumeMounts:
        - name: temp-storage
          mountPath: /tmp
      volumes:
      - name: temp-storage
        emptyDir:
          sizeLimit: "1Gi"
      restartPolicy: Always
EOF

    echo "✅ Aplicación inode-consumer desplegada"
}

# Función para desplegar aplicación con memory leak
deploy_memory_leak_app() {
    echo "💾 Desplegando aplicación con memory leak..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-leak-app
  namespace: testing-errors
  labels:
    app: memory-leak-app
    purpose: testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: memory-leak-app
  template:
    metadata:
      labels:
        app: memory-leak-app
        purpose: testing
    spec:
      nodeSelector:
        purpose: errors
      tolerations:
      - key: "purpose"
        operator: "Equal"
        value: "errors"
        effect: "NoSchedule"
      containers:
      - name: memory-leak
        image: python:3.9-slim
        command: ["python3"]
        args:
        - -c
        - |
          import time
          import sys
          
          print("🔥 Iniciando aplicación con memory leak...")
          
          # Lista que crecerá indefinidamente
          memory_consumer = []
          counter = 0
          
          while True:
              # Añadir 1MB de datos cada segundo
              data = 'x' * (1024 * 1024)  # 1MB
              memory_consumer.append(data)
              counter += 1
              
              if counter % 10 == 0:
                  print(f"💾 Memoria consumida: ~{counter}MB")
                  
              time.sleep(1)
        resources:
          requests:
            memory: "50Mi"
            cpu: "50m"
          limits:
            memory: "1Gi"
            cpu: "200m"
      restartPolicy: Always
EOF

    echo "✅ Aplicación memory-leak-app desplegada"
}

# Función para desplegar generador de logs masivos
deploy_log_generator() {
    echo "📝 Desplegando generador de logs masivos..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-generator
  namespace: testing-errors
  labels:
    app: log-generator
    purpose: testing
spec:
  replicas: 2
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
        purpose: testing
    spec:
      nodeSelector:
        purpose: errors
      tolerations:
      - key: "purpose"
        operator: "Equal"
        value: "errors"
        effect: "NoSchedule"
      containers:
      - name: log-generator
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "📝 Iniciando generador de logs masivos..."
          
          while true; do
            # Generar diferentes tipos de logs
            echo "INFO: \$(date) - Operación normal ejecutada correctamente"
            echo "WARNING: \$(date) - Advertencia de uso de memoria alta"
            echo "ERROR: \$(date) - Error simulado en la aplicación"
            echo "CRITICAL: \$(date) - Error crítico simulado"
            echo "FATAL: \$(date) - Error fatal simulado"
            echo "DEBUG: \$(date) - Información de debug detallada"
            
            # Log con stack trace simulado
            echo "EXCEPTION: \$(date) - Exception in thread main:"
            echo "  at com.example.App.main(App.java:42)"
            echo "  at java.base/java.lang.Thread.run(Thread.java:834)"
            
            # Simular diferentes velocidades de log
            sleep 0.1
          done
        resources:
          requests:
            memory: "50Mi"
            cpu: "50m"
          limits:
            memory: "200Mi"
            cpu: "100m"
      restartPolicy: Always
EOF

    echo "✅ Generador de logs desplegado"
}

# Función para desplegar aplicación que crashea constantemente
deploy_crash_app() {
    echo "💥 Desplegando aplicación que crashea constantemente..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crash-app
  namespace: testing-errors
  labels:
    app: crash-app
    purpose: testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crash-app
  template:
    metadata:
      labels:
        app: crash-app
        purpose: testing
    spec:
      nodeSelector:
        purpose: errors
      tolerations:
      - key: "purpose"
        operator: "Equal"
        value: "errors"
        effect: "NoSchedule"
      containers:
      - name: crash-app
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "💥 Iniciando aplicación que crashea..."
          sleep \$((RANDOM % 30 + 10))  # Funciona entre 10-40 segundos
          echo "PANIC: \$(date) - Aplicación crasheando intencionalmente"
          echo "CRASH: Segmentation fault (core dumped)"
          exit 1
        resources:
          requests:
            memory: "50Mi"
            cpu: "50m"
          limits:
            memory: "100Mi"
            cpu: "100m"
      restartPolicy: Always
EOF

    echo "✅ Aplicación crash-app desplegada"
}

# Función para crear pipeline de Jenkins problemático
create_jenkins_error_pipeline() {
    echo "🔧 Creando pipeline de Jenkins con errores..."
    
    # Crear ConfigMap con el pipeline problemático
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-error-pipeline
  namespace: jenkins-master
data:
  error-pipeline.groovy: |
    pipeline {
        agent {
            kubernetes {
                label 'error-testing'
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
                        
                        // Simular trabajo normal por un tiempo
                        sh '''
                            echo "INFO: Iniciando proceso..."
                            sleep 5
                        '''
                        
                        // 50% de probabilidad de fallo
                        def shouldFail = Math.random() > 0.5
                        if (shouldFail) {
                            error "ERROR: Fallo simulado en Stage 1"
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
                            # Crear archivo grande para simular uso de memoria
                            dd if=/dev/zero of=/tmp/bigfile bs=1M count=100 2>/dev/null || echo "ERROR: No se pudo crear archivo grande"
                            echo "INFO: Archivo creado: \$(ls -lh /tmp/bigfile)"
                            sleep 10
                            rm -f /tmp/bigfile
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
                            
                            for i in \$(seq 1 1000); do
                                echo "Archivo de test \$i" > "/tmp/stress-test/file_\$i.txt"
                            done
                            
                            echo "INFO: Archivos creados: \$(ls /tmp/stress-test | wc -l)"
                            
                            # Simular error ocasional
                            if [ \$((RANDOM % 3)) -eq 0 ]; then
                                echo "CRITICAL: Error crítico simulado"
                                exit 1
                            fi
                            
                            # Limpiar
                            rm -rf /tmp/stress-test
                            echo "INFO: Limpieza completada"
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
                            
                            # Intentar conectar a servicio inexistente
                            curl -m 5 http://servicio-inexistente:8080/health || echo "ERROR: No se pudo conectar al servicio"
                            
                            # Simular timeout
                            timeout 3 sleep 5 || echo "WARNING: Timeout simulado"
                            
                            echo "INFO: Tests de red completados"
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
                        echo "INFO: Ejecutando limpieza final..."
                        # Generar logs finales
                        echo "INFO: Pipeline completado en \$(date)"
                        echo "METRICS: Tiempo total de ejecución registrado"
                    '''
                }
            }
            failure {
                script {
                    echo "❌ Pipeline falló - generando logs de error..."
                    sh '''
                        echo "ERROR: Pipeline falló en \$(date)"
                        echo "FATAL: Se requiere intervención manual"
                        echo "STACK_TRACE: Error en pipeline de testing"
                    '''
                }
            }
            success {
                script {
                    echo "✅ Pipeline exitoso - generando logs de éxito..."
                    sh '''
                        echo "SUCCESS: Pipeline completado exitosamente en \$(date)"
                        echo "INFO: Todos los tests pasaron"
                    '''
                }
            }
        }
    }
EOF

    echo "✅ Pipeline de Jenkins con errores creado"
}

# Función para crear job de Jenkins que ejecute el pipeline
create_jenkins_job() {
    echo "⚙️  Configurando job de Jenkins..."
    
    # Script para crear el job via Jenkins API
    cat > /tmp/create_jenkins_job.sh << 'EOF'
#!/bin/bash

JENKINS_URL="http://20.8.71.3:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="admin123"

# XML del job
JOB_XML='<?xml version="1.0" encoding="UTF-8"?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Pipeline de testing que genera errores intencionalmente para monitoreo</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.TimerTrigger>
          <spec>H/5 * * * *</spec>
        </hudson.triggers.TimerTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.92">
    <script>
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
        stage("Error Testing Stage 1") {
            steps {
                script {
                    echo "🚨 Iniciando testing de errores..."
                    
                    sh """
                        echo "INFO: Iniciando proceso en \$(date)..."
                        sleep 5
                    """
                    
                    def shouldFail = Math.random() > 0.7
                    if (shouldFail) {
                        error "ERROR: Fallo simulado en Stage 1"
                    }
                }
            }
        }
        
        stage("Memory Intensive Stage") {
            steps {
                script {
                    echo "💾 Iniciando stage intensivo en memoria..."
                    
                    sh """
                        echo "WARNING: Consumiendo memoria..."
                        dd if=/dev/zero of=/tmp/bigfile bs=1M count=50 2>/dev/null || echo "ERROR: No se pudo crear archivo grande"
                        echo "INFO: Archivo creado: \$(ls -lh /tmp/bigfile 2>/dev/null || echo 'No existe')"
                        sleep 10
                        rm -f /tmp/bigfile
                    """
                }
            }
        }
        
        stage("File System Stress") {
            steps {
                script {
                    echo "📁 Testing de stress del filesystem..."
                    
                    sh """
                        echo "INFO: Creando muchos archivos pequeños..."
                        mkdir -p /tmp/stress-test
                        
                        for i in \$(seq 1 500); do
                            echo "Archivo de test \$i con contenido aleatorio \$(date)" > "/tmp/stress-test/file_\$i.txt"
                        done
                        
                        echo "INFO: Archivos creados: \$(ls /tmp/stress-test | wc -l)"
                        
                        if [ \$((RANDOM % 4)) -eq 0 ]; then
                            echo "CRITICAL: Error crítico simulado"
                            exit 1
                        fi
                        
                        rm -rf /tmp/stress-test
                        echo "INFO: Limpieza completada"
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Limpieza post-pipeline..."
                sh """
                    echo "INFO: Pipeline completado en \$(date)"
                    echo "METRICS: Tiempo total de ejecución registrado"
                """
            }
        }
        failure {
            script {
                echo "❌ Pipeline falló..."
                sh """
                    echo "ERROR: Pipeline falló en \$(date)"
                    echo "FATAL: Se requiere intervención manual"
                """
            }
        }
        success {
            script {
                echo "✅ Pipeline exitoso..."
                sh """
                    echo "SUCCESS: Pipeline completado exitosamente en \$(date)"
                """
            }
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>'

# Crear el job
curl -X POST \
  "${JENKINS_URL}/createItem?name=error-testing-pipeline" \
  -H "Content-Type: application/xml" \
  -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  --data-raw "$JOB_XML"

echo "✅ Job 'error-testing-pipeline' creado en Jenkins"
EOF

    chmod +x /tmp/create_jenkins_job.sh
    /tmp/create_jenkins_job.sh

    echo "✅ Job de Jenkins configurado para ejecutarse cada 5 minutos"
}

# Función para verificar el estado del despliegue
verify_deployment() {
    echo ""
    echo "🔍 Verificando estado del despliegue..."
    echo "----------------------------------------"
    
    echo "📊 Estado del nodo pool 'errors':"
    kubectl get nodes -l purpose=errors
    
    echo ""
    echo "📁 Pods en namespace testing-errors:"
    kubectl get pods -n testing-errors -o wide
    
    echo ""
    echo "📈 Uso de recursos en nodos errors:"
    kubectl top nodes -l purpose=errors 2>/dev/null || echo "❌ Metrics server no disponible"
    
    echo ""
    echo "📊 Logs de aplicaciones problemáticas (últimas 5 líneas):"
    echo "--- Inode Consumer ---"
    kubectl logs -n testing-errors deployment/inode-consumer --tail=5 2>/dev/null || echo "No disponible"
    
    echo "--- Memory Leak App ---"
    kubectl logs -n testing-errors deployment/memory-leak-app --tail=5 2>/dev/null || echo "No disponible"
    
    echo "--- Log Generator ---"
    kubectl logs -n testing-errors deployment/log-generator --tail=5 2>/dev/null || echo "No disponible"
}

# Función para mostrar información de monitoreo
show_monitoring_info() {
    echo ""
    echo "============================================="
    echo "📊 INFORMACIÓN DE MONITOREO"
    echo "============================================="
    echo ""
    echo "🎯 APLICACIONES DESPLEGADAS PARA TESTING:"
    echo "   1. 📄 inode-consumer: Consume inodos masivamente"
    echo "   2. 💾 memory-leak-app: Aplicación con memory leak"
    echo "   3. 📝 log-generator: Genera logs masivos"
    echo "   4. 💥 crash-app: Aplicación que crashea constantemente"
    echo "   5. 🔧 error-testing-pipeline: Pipeline de Jenkins problemático"
    echo ""
    echo "🔔 ALERTAS QUE SE ACTIVARÁN:"
    echo "   - Uso de inodos > 95%"
    echo "   - Uso de memoria > 90%"
    echo "   - Reinicisiones frecuentes de pods"
    echo "   - Errores en logs (CRITICAL, FATAL, ERROR)"
    echo "   - Fallos de pipeline en Jenkins"
    echo ""
    echo "📊 DASHBOARDS PARA MONITOREAR:"
    echo "   - Physical Resources: http://135.236.73.36/d/f50a7480-4ff6-4f08-b287-63daea6d00ae"
    echo "   - Logical Monitoring: http://135.236.73.36/d/4230d7c8-9ecf-4cf4-9fe2-37c1a5cc7223"
    echo "   - Critical Alerts: http://135.236.73.36/d/7a41aba6-f616-4347-b751-af5718e8887d"
    echo "   - Disk & Inode Troubleshooting: http://135.236.73.36/d/ca7aa68f-5b77-4205-a6cb-b2f7133966f2"
    echo ""
    echo "🔧 COMANDOS ÚTILES:"
    echo "   - Ver logs en tiempo real: kubectl logs -f -n testing-errors deployment/log-generator"
    echo "   - Monitorear uso de recursos: kubectl top pods -n testing-errors"
    echo "   - Ver eventos: kubectl get events -n testing-errors --sort-by='.lastTimestamp'"
    echo "   - Jenkins pipeline: http://20.8.71.3:8080/job/error-testing-pipeline/"
}

# Función para limpiar recursos de testing
cleanup_testing_resources() {
    echo ""
    echo "🧹 LIMPIANDO RECURSOS DE TESTING..."
    echo "----------------------------------------"
    
    # Eliminar namespace (elimina todos los pods dentro)
    kubectl delete namespace testing-errors --ignore-not-found=true
    
    # Eliminar job de Jenkins
    curl -X POST "http://20.8.71.3:8080/job/error-testing-pipeline/doDelete" \
         -u "admin:admin123" 2>/dev/null || echo "❌ No se pudo eliminar job de Jenkins"
    
    # Eliminar nodo pool
    read -p "¿Eliminar también el nodo pool 'errors'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az aks nodepool delete \
            --resource-group "$RESOURCE_GROUP" \
            --cluster-name "$CLUSTER_NAME" \
            --name "errors" \
            --no-wait
        echo "✅ Eliminando nodo pool 'errors' (en segundo plano)"
    fi
    
    echo "✅ Limpieza completada"
}

# Función principal
main() {
    case "${1:-}" in
        "cleanup")
            cleanup_testing_resources
            exit 0
            ;;
        "verify")
            verify_deployment
            exit 0
            ;;
        *)
            echo "🎯 Creando entorno de testing de errores para monitoreo"
            echo "Este proceso creará aplicaciones problemáticas para validar el monitoreo."
            echo ""
            
            create_error_node_pool
            sleep 30  # Esperar a que el nodo esté listo
            
            create_testing_namespace
            deploy_inode_consumer
            deploy_memory_leak_app
            deploy_log_generator
            deploy_crash_app
            create_jenkins_job
            
            echo ""
            echo "⏳ Esperando a que los pods se inicien..."
            sleep 60
            
            verify_deployment
            show_monitoring_info
            
            echo ""
            echo "============================================="
            echo "✅ ENTORNO DE TESTING DE ERRORES CREADO"
            echo "============================================="
            echo ""
            echo "🎯 PRÓXIMOS PASOS:"
            echo "   1. Monitorear dashboards de Grafana"
            echo "   2. Verificar alertas en tiempo real"
            echo "   3. Observar pipelines de Jenkins"
            echo "   4. Analizar logs y métricas"
            echo ""
            echo "🧹 Para limpiar todos los recursos:"
            echo "   $0 cleanup"
            echo ""
            echo "🔍 Para verificar estado:"
            echo "   $0 verify"
            ;;
    esac
}

# Ejecutar función principal
main "$@"
