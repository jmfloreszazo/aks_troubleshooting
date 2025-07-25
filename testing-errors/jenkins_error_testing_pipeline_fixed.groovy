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
  - key:                            if [ \$((RANDOM % 100)) -lt 25 ]; then
                                    if [ \$((RANDOM % 100)) -lt 20 ]; then
                               if [ \$((RANDOM % 100)) -lt 40 ]; then
                                echo "PANIC: \$(date) - Aplicación crasheando intencionalmente"
                                echo "FATAL: Critical system failure - Cannot continue"
                                exit 1
                            else
                                echo "RECOVERY: Simulación de crash completada sin fallo real"
                            fi                      echo "CRITICAL: Error crítico de red simulado"
                                echo "NETWORK_ERROR: Connection refused - Service unavailable"
                                exit 1
                            fi                   echo "CRITICAL: Error crítico simulado en filesystem"
                                echo "FILESYSTEM_ERROR: No space left on device (simulado)"
                                exit 1
                            fipose"
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
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "300m"
"""
        }
    }
    
    options {
        timeout(time: 15, unit: 'MINUTES')
        retry(2)
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    parameters {
        choice(
            name: 'ERROR_TYPE',
            choices: ['ALL', 'MEMORY', 'FILESYSTEM', 'NETWORK', 'CRASH'],
            description: 'Tipo de error a simular'
        )
        booleanParam(
            name: 'FORCE_FAILURE',
            defaultValue: false,
            description: 'Forzar que el pipeline falle'
        )
        string(
            name: 'DURATION_SECONDS',
            defaultValue: '30',
            description: 'Duración de cada etapa en segundos'
        )
    }
    
    environment {
        TESTING_NAMESPACE = 'testing-errors'
        LOG_LEVEL = 'DEBUG'
        FAILURE_PROBABILITY = '0.3'
    }
    
    stages {
        stage('🚀 Initialization') {
            steps {
                script {
                    echo "🎯 Iniciando pipeline de testing de errores..."
                    echo "📊 Parámetros:"
                    echo "   - Tipo de error: ${params.ERROR_TYPE}"
                    echo "   - Forzar fallo: ${params.FORCE_FAILURE}"
                    echo "   - Duración: ${params.DURATION_SECONDS}s"
                    echo "   - Build: ${env.BUILD_NUMBER}"
                    echo "   - Node: ${env.NODE_NAME}"
                    
                    container('tester') {
                        sh '''
                            echo "🖥️  Información del sistema:"
                            echo "   - Hostname: $(hostname)"
                            echo "   - Fecha: $(date)"
                            echo "   - Uptime: $(uptime)"
                            echo "   - Memoria: $(free -h)"
                            echo "   - Disco: $(df -h | head -2)"
                            echo "   - Procesos: $(ps aux | wc -l)"
                        '''
                    }
                }
            }
        }
        
        stage('💾 Memory Stress Testing') {
            when {
                anyOf {
                    expression { params.ERROR_TYPE == 'ALL' }
                    expression { params.ERROR_TYPE == 'MEMORY' }
                }
            }
            steps {
                script {
                    echo "💾 Iniciando testing intensivo de memoria..."
                    
                    container('tester') {
                        sh """
                            echo "WARNING: \$(date) - Iniciando consumo de memoria intensivo"
                            
                            echo "INFO: Creando archivo de ${params.DURATION_SECONDS}MB..."
                            dd if=/dev/zero of=/tmp/bigfile bs=1M count=${params.DURATION_SECONDS} 2>/dev/null || {
                                echo "ERROR: No se pudo crear archivo grande"
                                exit 1
                            }
                            
                            echo "INFO: Archivo creado: \$(ls -lh /tmp/bigfile)"
                            echo "INFO: Memoria después de crear archivo:"
                            free -h
                            
                            echo "INFO: Procesando archivo..."
                            for i in \$(seq 1 5); do
                                echo "PROCESSING: Iteración \$i de 5"
                                cat /tmp/bigfile > /dev/null &
                                sleep 2
                            done
                            
                            wait
                            echo "INFO: Procesamiento completado"
                            
                            rm -f /tmp/bigfile
                            echo "SUCCESS: Limpieza de memoria completada"
                            
                            if [ \$((RANDOM % 100)) -lt 30 ]; then
                                echo "CRITICAL: Error crítico simulado en testing de memoria"
                                exit 1
                            fi
                        """
                    }
                }
            }
            post {
                always {
                    script {
                        container('tester') {
                            sh '''
                                echo "🧹 Limpieza post-memory testing..."
                                rm -f /tmp/bigfile
                                echo "INFO: Estado final de memoria:"
                                free -h
                            '''
                        }
                    }
                }
            }
        }
        
        stage('📁 FileSystem Stress Testing') {
            when {
                anyOf {
                    expression { params.ERROR_TYPE == 'ALL' }
                    expression { params.ERROR_TYPE == 'FILESYSTEM' }
                }
            }
            steps {
                script {
                    echo "📁 Iniciando testing de stress del filesystem..."
                    
                    container('tester') {
                        sh '''
                            echo "INFO: $(date) - Iniciando stress test del filesystem"
                            
                            mkdir -p /tmp/stress-test
                            cd /tmp/stress-test
                            
                            echo "INFO: Creando archivos pequeños..."
                            for i in $(seq 1 1000); do
                                echo "Archivo de test $i - $(date) - contenido aleatorio ${RANDOM}" > "file_${i}.txt"
                                
                                if [ $((i % 200)) -eq 0 ]; then
                                    echo "PROGRESS: Creados $i/1000 archivos..."
                                fi
                            done
                            
                            echo "INFO: Total archivos creados: $(ls | wc -l)"
                            echo "INFO: Espacio usado: $(du -sh .)"
                            
                            echo "INFO: Realizando operaciones de I/O intensivas..."
                            for i in $(seq 1 10); do
                                echo "IO_TEST: Iteración $i - $(date)"
                                find . -name "*.txt" -exec grep -l "test" {} + > /dev/null 2>&1
                                sleep 1
                            done
                            
                            echo "INFO: Creando archivos grandes..."
                            for i in $(seq 1 3); do
                                dd if=/dev/zero of="bigfile_${i}.dat" bs=1M count=10 2>/dev/null
                                echo "INFO: Archivo grande $i creado"
                            done
                            
                            echo "INFO: Estado final del directorio:"
                            ls -la | head -10
                            echo "INFO: Uso total de espacio: $(du -sh .)"
                            
                            if [ $((RANDOM % 100)) -lt 25 ]; then
                                echo "CRITICAL: Error crítico simulado en filesystem"
                                echo "FILESYSTEM_ERROR: No space left on device (simulado)"
                                exit 1
                            fi
                            
                            cd /tmp
                            rm -rf /tmp/stress-test
                            echo "SUCCESS: Limpieza del filesystem completada"
                        '''
                    }
                }
            }
            post {
                always {
                    script {
                        container('tester') {
                            sh '''
                                echo "🧹 Limpieza post-filesystem testing..."
                                rm -rf /tmp/stress-test
                                echo "INFO: Estado del filesystem:"
                                df -h | grep -E "(Filesystem|/tmp|/$)"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('🌐 Network Error Simulation') {
            when {
                anyOf {
                    expression { params.ERROR_TYPE == 'ALL' }
                    expression { params.ERROR_TYPE == 'NETWORK' }
                }
            }
            steps {
                script {
                    echo "🌐 Simulando errores de red y conectividad..."
                    
                    container('tester') {
                        sh '''
                            echo "INFO: $(date) - Iniciando tests de conectividad"
                            
                            echo "INFO: Testing conectividad a Google DNS..."
                            if ping -c 3 8.8.8.8; then
                                echo "SUCCESS: Conectividad a 8.8.8.8 exitosa"
                            else
                                echo "WARNING: No se pudo conectar a 8.8.8.8"
                            fi
                            
                            echo "INFO: Testing servicios inexistentes..."
                            curl -m 5 http://servicio-inexistente:8080/health || echo "ERROR: No se pudo conectar al servicio inexistente (esperado)"
                            curl -m 5 http://192.168.999.999:8080/api/status || echo "ERROR: IP inválida no accesible (esperado)"
                            
                            echo "INFO: Simulando timeouts..."
                            timeout 3 sleep 5 || echo "WARNING: Timeout simulado (esperado)"
                            timeout 2 curl -m 10 http://httpbin.org/delay/5 || echo "WARNING: Timeout en request HTTP (esperado)"
                            
                            echo "INFO: Testing resolución DNS..."
                            nslookup servicio-que-no-existe.local || echo "ERROR: DNS resolution failed (esperado)"
                            
                            echo "INFO: Simulando latencia alta..."
                            for i in $(seq 1 5); do
                                start_time=$(date +%s)
                                sleep 0.5
                                end_time=$(date +%s)
                                duration=$((end_time - start_time))
                                echo "LATENCY: Request $i - Duration: ${duration}s"
                            done
                            
                            if [ $((RANDOM % 100)) -lt 20 ]; then
                                echo "CRITICAL: Error crítico de red simulado"
                                echo "NETWORK_ERROR: Connection refused - Service unavailable"
                                exit 1
                            fi
                            
                            echo "INFO: Tests de red completados"
                        '''
                    }
                }
            }
        }
        
        stage('💥 Crash Simulation') {
            when {
                anyOf {
                    expression { params.ERROR_TYPE == 'ALL' }
                    expression { params.ERROR_TYPE == 'CRASH' }
                    expression { params.FORCE_FAILURE == true }
                }
            }
            steps {
                script {
                    echo "💥 Simulando crashes y fallos críticos..."
                    
                    if (params.FORCE_FAILURE) {
                        echo "🔴 FORZANDO FALLO - FORCE_FAILURE activado"
                        error "FORCED_FAILURE: Pipeline configurado para fallar intencionalmente"
                    }
                    
                    container('tester') {
                        sh '''
                            echo "WARNING: $(date) - Iniciando simulación de crashes"
                            
                            crash_type=$((RANDOM % 4))
                            
                            case $crash_type in
                                0)
                                    echo "CRASH_TYPE: Simulando segmentation fault"
                                    echo "SEGFAULT: Program received signal SIGSEGV, Segmentation fault"
                                    echo "STACK_TRACE: 0x00007fff5fbff5c0 in main ()"
                                    ;;
                                1)
                                    echo "CRASH_TYPE: Simulando out of memory"
                                    echo "OOM_KILLER: Out of memory: Kill process"
                                    echo "MEMORY_ERROR: Cannot allocate memory"
                                    ;;
                                2)
                                    echo "CRASH_TYPE: Simulando assertion failure"
                                    echo "ASSERTION_FAILED: Assertion 'ptr != NULL' failed"
                                    echo "ABORT: Program aborted"
                                    ;;
                                3)
                                    echo "CRASH_TYPE: Simulando timeout fatal"
                                    echo "TIMEOUT_ERROR: Operation timed out after 30 seconds"
                                    echo "FATAL: Cannot recover from timeout"
                                    ;;
                            esac
                            
                            echo "CORE_DUMP: Writing core dump to /tmp/core.12345"
                            echo "PROCESS_INFO: PID 12345, Command: test-app"
                            
                            echo "EXCEPTION: $(date) - Unhandled exception in application"
                            echo "  at TestApp.CriticalFunction(TestApp.cs:42)"
                            echo "  at TestApp.Main(String[] args)"
                            
                            if [ $((RANDOM % 100)) -lt 40 ]; then
                                echo "PANIC: $(date) - Aplicación crasheando intencionalmente"
                                echo "FATAL: Critical system failure - Cannot continue"
                                exit 1
                            else
                                echo "RECOVERY: Simulación de crash completada sin fallo real"
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('🔍 System Health Check') {
            steps {
                script {
                    echo "🔍 Verificando estado del sistema después de los tests..."
                    
                    container('tester') {
                        sh '''
                            echo "INFO: $(date) - Iniciando health check final"
                            
                            echo "📊 SYSTEM METRICS:"
                            echo "   CPU Load: $(uptime | cut -d',' -f4-)"
                            echo "   Memory: $(free -h | grep Mem)"
                            echo "   Disk: $(df -h | grep -E "/$|/tmp" | head -2)"
                            echo "   Processes: $(ps aux | wc -l) total processes"
                            
                            echo "📈 PERFORMANCE METRICS:"
                            echo "   Load Average: $(cat /proc/loadavg)"
                            echo "   Memory Available: $(grep MemAvailable /proc/meminfo)"
                            
                            echo "🔍 ERROR SUMMARY:"
                            echo "   Build Number: ${BUILD_NUMBER}"
                            echo "   Duration: Approximately ${DURATION_SECONDS}s per stage"
                            echo "   Error Type: ${ERROR_TYPE}"
                            echo "   Forced Failure: ${FORCE_FAILURE}"
                            
                            echo "✅ Health check completado"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Ejecutando limpieza final del pipeline..."
                
                container('tester') {
                    sh '''
                        echo "INFO: $(date) - Limpieza final iniciada"
                        
                        rm -rf /tmp/stress-test /tmp/bigfile* /tmp/core.* 2>/dev/null || true
                        
                        echo "📊 PIPELINE SUMMARY:"
                        echo "   Build: ${BUILD_NUMBER}"
                        echo "   Duration: $(date)"
                        echo "   Node: ${NODE_NAME}"
                        echo "   Workspace: $(pwd)"
                        
                        echo "INFO: Limpieza completada"
                    '''
                }
                
                archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true
            }
        }
        
        success {
            script {
                echo "✅ Pipeline de testing de errores completado exitosamente"
                
                container('tester') {
                    sh '''
                        echo "SUCCESS: $(date) - Pipeline exitoso"
                        echo "INFO: Todos los tests de error pasaron correctamente"
                        echo "METRICS: Pipeline duration logged"
                        echo "STATUS: All error simulations completed successfully"
                    '''
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline de testing falló (esto puede ser intencional)"
                
                container('tester') {
                    sh '''
                        echo "ERROR: $(date) - Pipeline falló"
                        echo "FATAL: Se requiere análisis de logs"
                        echo "DEBUG: Failure may be intentional for testing purposes"
                        echo "STACK_TRACE: Error occurred in pipeline execution"
                        
                        echo "DEBUG_INFO: System state at failure:"
                        echo "   Memory: $(free -h | grep Mem || echo 'N/A')"
                        echo "   Disk: $(df -h | head -2 || echo 'N/A')"
                        echo "   Processes: $(ps aux | wc -l || echo 'N/A')"
                    '''
                }
            }
        }
        
        unstable {
            script {
                echo "⚠️ Pipeline completado con advertencias"
                
                container('tester') {
                    sh '''
                        echo "WARNING: $(date) - Pipeline unstable"
                        echo "WARN: Some tests completed with warnings"
                        echo "INFO: Review logs for details"
                    '''
                }
            }
        }
        
        aborted {
            script {
                echo "🛑 Pipeline abortado por el usuario"
                
                container('tester') {
                    sh '''
                        echo "ABORTED: $(date) - Pipeline was aborted"
                        echo "INFO: Manual intervention stopped the pipeline"
                        echo "CLEANUP: Performing emergency cleanup"
                        
                        rm -rf /tmp/stress-test /tmp/bigfile* 2>/dev/null || true
                    '''
                }
            }
        }
    }
}
