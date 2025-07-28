// Pipeline ULTRA Simple - Solo Copiar y Pegar
// Uso: Crear nuevo Pipeline Job → Pipeline Script → Copiar esto
// Test inmediato sin Script Console

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
  - name: test
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
        timeout(time: 5, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }
    
    stages {
        stage('Test Spot') {
            steps {
                script {
                    echo "TESTING SPOT WORKER"
                    echo "Time: ${new Date().format('HH:mm:ss')}"
                }
                
                container('test') {
                    sh 'echo "Container OK"'
                    sh 'echo "Host: \\$(hostname)"'
                    sh 'echo "Date: \\$(date)"'
                    sh 'echo "Disk: \\$(df -h / | tail -1 | awk \'{print \\$5}\')"'
                    sh 'echo "SUCCESS: Spot worker functioning!"'
                }
                
                script {
                    echo "SPOT TEST COMPLETED"
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "SUCCESS: Spot workers are working!"
            }
        }
        failure {
            script {
                echo "FAILURE: Spot connection failed"
            }
        }
    }
}
