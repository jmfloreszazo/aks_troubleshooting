// Pipeline Alternativo con Throttling para Nodos Regulares
// Uso: Cuando no hay nodos spot disponibles
// Configuracion: Requiere plugins throttle-concurrents y lockable-resources

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    nodepool: regular
  tolerations:
  - key: "nodepool"
    operator: "Equal"
    value: "regular"
    effect: "NoSchedule"
  containers:
  - name: worker
    image: alpine:latest
    command: ['cat']
    tty: true
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
"""
        }
    }
    
    options {
        // Timeout obligatorio - evita builds colgados
        timeout(time: 15, unit: 'MINUTES')
        
        // Un build a la vez por job
        disableConcurrentBuilds()
        
        // Limpiar builds antiguos
        buildDiscarder(logRotator(numToKeepStr: '3'))
        
        // Throttling por categoria
        throttleJobProperty(
            categories: ['regular-builds'],
            throttleEnabled: true,
            throttleOption: 'category',
            maxConcurrentTotal: 2
        )
    }
    
    stages {
        stage('Pre-Check') {
            steps {
                script {
                    echo "Verificando recursos disponibles..."
                    echo "Build #${env.BUILD_NUMBER}"
                    echo "Timestamp: ${new Date()}"
                }
            }
        }
        
        stage('Trabajo Controlado') {
            steps {
                // Reservar recurso exclusivo
                lock('regular-cluster') {
                    container('worker') {
                        script {
                            echo "Ejecutandose en worker regular con control!"
                            sh 'hostname'
                            sh 'echo "Trabajo controlado iniciado..."'
                            
                            // Simular trabajo
                            sh 'sleep 10'
                            
                            echo "Trabajo completado sin saturar el sistema!"
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Liberando recursos..."
            }
        }
        failure {
            script {
                echo "Pipeline fallo - recursos liberados automaticamente"
            }
        }
        aborted {
            script {
                echo "Pipeline cancelado por timeout"
            }
        }
    }
}
