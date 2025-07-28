// executor_blocker_simple.groovy
// Pipeline simple que bloquea executors para testing
// Ejecutar en Jenkins Script Console

import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def jenkins = Jenkins.getInstance()

// Create simple executor blocker job
def jobName = "Executor-Blocker-Simple"
def existingJob = jenkins.getItem(jobName)
if (existingJob != null) {
    existingJob.delete()
}

def job = jenkins.createProject(WorkflowJob.class, jobName)

def pipelineScript = '''
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
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '50'))
    }
    
    parameters {
        string(
            name: 'BLOCK_TIME_MINUTES',
            defaultValue: '10',
            description: 'Tiempo en minutos para bloquear el executor'
        )
        string(
            name: 'WORKER_ID',
            defaultValue: '1',
            description: 'ID del worker bloqueante'
        )
    }
    
    stages {
        stage('Block Executor') {
            steps {
                script {
                    def blockTime = (params.BLOCK_TIME_MINUTES ?: "10") as Integer
                    def workerId = params.WORKER_ID ?: "1"
                    def startTime = new Date()
                    
                    echo "============================================"
                    echo "EXECUTOR BLOCKER #${workerId} ACTIVE"
                    echo "============================================"
                    echo ""
                    echo "BLOCKING CONFIGURATION:"
                    echo "  Worker ID: ${workerId}"
                    echo "  Block Duration: ${blockTime} minutes"
                    echo "  Start Time: ${startTime.format('HH:mm:ss')}"
                    echo "  Build Number: ${env.BUILD_NUMBER}"
                    echo ""
                    echo "EXECUTOR STATUS: BLOCKED - Holding for ${blockTime} minutes"
                    echo "Other builds will queue with 'Waiting for next available executor'"
                    echo ""
                    
                    container('worker') {
                        for (int minute = 1; minute <= blockTime; minute++) {
                            sh """
                                echo "MINUTE ${minute}/${blockTime} - Executor held by Worker #${workerId}"
                                echo "  Current time: \\$(date '+%H:%M:%S')"
                                echo "  Status: BLOCKING EXECUTOR"
                                echo "  Remaining: ${blockTime - minute} minutes"
                                echo ""
                                
                                # Simulate some work to keep executor busy
                                timeout 30 yes > /dev/null 2>&1 &
                                PID=\\$!
                                sleep 10
                                kill \\$PID 2>/dev/null || true
                                
                                echo "  Work simulation completed for minute ${minute}"
                                echo ""
                            """
                            
                            if (minute < blockTime) {
                                sleep(time: 50, unit: 'SECONDS') // Complete the minute
                            }
                        }
                    }
                    
                    def endTime = new Date()
                    echo "============================================"
                    echo "EXECUTOR RELEASE - Worker #${workerId}"
                    echo "============================================"
                    echo "  End Time: ${endTime.format('HH:mm:ss')}"
                    echo "  Total Duration: ${blockTime} minutes"
                    echo "  Executor Status: NOW AVAILABLE"
                    echo "  Queue Effect: Next waiting build can start"
                    echo ""
                }
            }
        }
    }
    
    post {
        always {
            script {
                def workerId = params.WORKER_ID
                echo ""
                echo "Worker #${workerId} released executor - Queue can progress"
            }
        }
        success {
            script {
                def workerId = params.WORKER_ID
                def blockTime = params.BLOCK_TIME_MINUTES
                echo ""
                echo "SUCCESS: Worker #${workerId} blocked executor for ${blockTime} minutes"
                echo "Executor blocking test successful"
            }
        }
    }
}
'''

job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
job.save()

println "Simple Executor Blocker '${jobName}' created successfully"
println ""
println "USAGE FOR IMMEDIATE EXECUTOR BLOCKING:"
println ""
println "MÉTODO RÁPIDO PARA VER BLOQUEO:"
println "1. Ve a Jenkins Dashboard"
println "2. Ejecuta 'Executor-Blocker-Simple' 3-4 veces seguidas:"
println "   - Click en el job"
println "   - Click 'Build with Parameters'"
println "   - Deja valores por defecto (10 min)"
println "   - Click 'Build'"
println "   - Repite inmediatamente 3-4 veces"
println ""
println "3. INMEDIATAMENTE después:"
println "   - Ve al Dashboard"
println "   - Mira 'Build Queue' (sidebar)"
println "   - Verás: 'Waiting for next available executor'"
println ""
println "RESULTADO ESPERADO:"
println "  Build #1: Ejecutándose (ocupando executor)"
println "  Build #2: Ejecutándose (ocupando executor)"  
println "  Build #3: EN COLA - 'Waiting for next available executor'"
println "  Build #4: EN COLA - 'Waiting for next available executor'"
println ""

jenkins.save()

println "¡Ahora puedes ver el bloqueo de executors en acción!"
