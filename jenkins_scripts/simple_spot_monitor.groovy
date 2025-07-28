// Pipeline Simple de Monitoreo Spot - Version Pipeline Directo
// Uso: Copiar y pegar como Pipeline Script en Jenkins Job
// Configuracion: Monitor simple con cron cada 5 minutos

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    nodepool: spot
  tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
  containers:
  - name: monitor
    image: alpine:latest
    command: ['cat']
    tty: true
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
"""
        }
    }
    
    options {
        timeout(time: 3, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        throttleJobProperty(
            categories: ['spot-monitoring'],
            throttleEnabled: true,
            throttleOption: 'category',
            maxConcurrentTotal: 1
        )
    }
    
    triggers {
        cron('*/5 * * * *')  // Every 5 minutes
    }
    
    stages {
        stage('Spot Monitor Check') {
            steps {
                script {
                    def startTime = new Date()
                    echo "SPOT MONITOR - Build #${env.BUILD_NUMBER}"
                    echo "Start: ${startTime.format('HH:mm:ss')}"
                    echo "Node: ${env.NODE_NAME ?: 'Unknown'}"
                    
                    container('monitor') {
                        sh '''
                            echo "Container responding"
                            echo "Hostname: $(hostname)"
                            echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
                            echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
                            echo "Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
                        '''
                    }
                    
                    def endTime = new Date()
                    def duration = (endTime.time - startTime.time) / 1000
                    echo "SPOT WORKER HEALTHY"
                    echo "Duration: ${duration}s"
                    echo "Next check: ${new Date(endTime.time + 300000).format('HH:mm:ss')}"
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "SUCCESS - Spot worker responding normally"
            }
        }
        failure {
            script {
                echo "FAILURE - Spot worker issue detected"
                echo "Check: kubectl get nodes -l nodepool=spot"
                echo "Check: kubectl get pods -n jenkins-workers"
            }
        }
    }
}
