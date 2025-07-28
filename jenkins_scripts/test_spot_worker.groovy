// Test Pipeline Spot - Solo para Testing Manual
// Uso: Copiar y pegar como Pipeline Script en Jenkins Job
// NO tiene cron - solo ejecucion manual

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
        throttleJobProperty(
            categories: ['spot-testing'],
            throttleEnabled: true,
            throttleOption: 'category',
            maxConcurrentTotal: 1
        )
    }
    
    stages {
        stage('Test Spot Connection') {
            steps {
                script {
                    echo "TESTING SPOT WORKER CONNECTION"
                    echo "Start Time: ${new Date().format('HH:mm:ss')}"
                    echo "Build: #${env.BUILD_NUMBER}"
                }
                
                container('test') {
                    sh '''
                        echo ""
                        echo "Basic Tests:"
                        echo "  Hostname: \\$(hostname)"
                        echo "  Date: \\$(date)"
                        echo "  Whoami: \\$(whoami)"
                        echo ""
                        
                        echo "System Info:"
                        echo "  Memory: \\$(free -h | grep Mem | awk '{print "Used:"\\$3" / Total:"\\$2}')"
                        echo "  Disk: \\$(df -h / | tail -1 | awk '{print "Used:"\\$5" of "\\$2}')"
                        echo "  Load: \\$(uptime | awk -F: '{print \\$NF}')"
                        echo ""
                        
                        echo "Network Test:"
                        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                            echo "  Internet: OK"
                        else
                            echo "  Internet: FAIL"
                        fi
                        
                        echo ""
                        echo "Work Simulation:"
                        echo "  Creating test file..."
                        echo "test-\\$(date +%s)" > /tmp/test.txt
                        echo "  Content: \\$(cat /tmp/test.txt)"
                        echo "  Removing test file..."
                        rm -f /tmp/test.txt
                        echo "  Work simulation completed"
                    '''
                }
                
                script {
                    echo ""
                    echo "SPOT WORKER TEST COMPLETED SUCCESSFULLY!"
                    echo "End Time: ${new Date().format('HH:mm:ss')}"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo ""
                echo "Cleanup completed"
            }
        }
        success {
            script {
                echo "SUCCESS: Spot worker is working correctly"
                echo "Ready for production workloads"
            }
        }
        failure {
            script {
                echo "FAILURE: Spot worker connection failed"
                echo "Troubleshooting needed"
            }
        }
    }
}
