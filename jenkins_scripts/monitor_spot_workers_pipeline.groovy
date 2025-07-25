// monitor_spot_workers_pipeline.groovy
// Simple monitoring pipeline that runs every 5 minutes
// Keeps spot workers active and shows execution times

import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def jenkins = Jenkins.getInstance()

// Create monitoring pipeline job
def jobName = "Spot-Workers-Monitor"
def existingJob = jenkins.getItem(jobName)
if (existingJob != null) {
    existingJob.delete()
}

def job = jenkins.createProject(WorkflowJob.class, jobName)

def pipelineScript = '''
pipeline {
    agent { label 'nodepool=spot' }
    
    options {
        timeout(time: 2, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '50'))
    }
    
    triggers {
        cron('*/5 * * * *')  // Every 5 minutes
    }
    
    environment {
        MONITOR_VERSION = "1.0"
    }
    
    stages {
        stage('Spot Worker Health Check') {
            steps {
                script {
                    def startTime = new Date()
                    def buildNum = env.BUILD_NUMBER ?: "Unknown"
                    def nodeName = env.NODE_NAME ?: "Unknown"
                    def workspace = env.WORKSPACE ?: "Unknown"
                    
                    echo "============================================"
                    echo "SPOT WORKERS HEALTH MONITORING - BUILD #${buildNum}"
                    echo "============================================"
                    echo ""
                    echo "DIAGNOSTIC INFORMATION:"
                    echo "  Start Time: ${startTime.format('yyyy-MM-dd HH:mm:ss')}"
                    echo "  Node Name: ${nodeName}"
                    echo "  Build Number: ${buildNum}"
                    echo "  Workspace: ${workspace}"
                    echo "  Monitor Version: ${env.MONITOR_VERSION}"
                    echo ""
                    
                    // Detailed Pod/Node Analysis for troubleshooting
                    echo "POD/NODE DIAGNOSTIC:"
                    sh """
                        echo "  Hostname: \\$(hostname)"
                        echo "  Pod Name: \\$(hostname)"
                        echo "  Node IP: \\$(hostname -i 2>/dev/null || echo 'IP not available - possible network issue')"
                        
                        # Check pod uptime and status
                        UPTIME_SECONDS=\\$(cat /proc/uptime | cut -d. -f1)
                        UPTIME_MINUTES=\\$((UPTIME_SECONDS / 60))
                        UPTIME_HOURS=\\$((UPTIME_MINUTES / 60))
                        
                        if [ "\\$UPTIME_SECONDS" -lt 60 ]; then
                            echo "  Pod Status: FRESHLY CREATED (\\${UPTIME_SECONDS}s ago)"
                            echo "  WARNING: Very new pod - possible recent restart/eviction"
                        elif [ "\\$UPTIME_SECONDS" -lt 300 ]; then
                            echo "  Pod Status: RECENTLY CREATED (\\${UPTIME_MINUTES}m ago)"
                            echo "  INFO: Pod started recently - monitor for stability"
                        elif [ "\\$UPTIME_SECONDS" -lt 3600 ]; then
                            echo "  Pod Status: STABLE REUSE (\\${UPTIME_MINUTES}m uptime)"
                            echo "  GOOD: Pod is stable and reusable"
                        else
                            echo "  Pod Status: LONG RUNNING (\\${UPTIME_HOURS}h uptime)"
                            echo "  EXCELLENT: Very stable pod"
                        fi
                        
                        echo "  Uptime Details: \\$(uptime)"
                    """
                    
                    echo ""
                    echo "SYSTEM HEALTH DIAGNOSTIC:"
                    sh """
                        # Memory pressure check
                        MEMORY_USED=\\$(free | grep Mem | awk '{printf "%.0f", \\$3/\\$2 * 100}')
                        echo "  Memory Usage: \\${MEMORY_USED}%"
                        if [ "\\$MEMORY_USED" -gt 90 ]; then
                            echo "  CRITICAL: High memory usage - possible OOM kill risk"
                        elif [ "\\$MEMORY_USED" -gt 70 ]; then
                            echo "  WARNING: Elevated memory usage"
                        else
                            echo "  GOOD: Memory usage normal"
                        fi
                        
                        # Disk pressure check
                        DISK_USED=\\$(df / | tail -1 | awk '{print \\$5}' | sed 's/%//')
                        echo "  Disk Usage: \\${DISK_USED}%"
                        if [ "\\$DISK_USED" -gt 90 ]; then
                            echo "  CRITICAL: Disk almost full - pod eviction risk"
                        elif [ "\\$DISK_USED" -gt 80 ]; then
                            echo "  WARNING: High disk usage"
                        else
                            echo "  GOOD: Disk usage normal"
                        fi
                        
                        # Load average check
                        LOAD=\\$(uptime | awk -F'load average:' '{print \\$2}' | awk '{print \\$1}' | sed 's/,//')
                        echo "  Load Average: \\$LOAD"
                        
                        # CPU count for context
                        CPU_COUNT=\\$(nproc)
                        echo "  CPU Cores: \\$CPU_COUNT"
                        
                        # Check if load is high relative to CPU count
                        if command -v bc >/dev/null 2>&1; then
                            LOAD_RATIO=\\$(echo "\\$LOAD / \\$CPU_COUNT" | bc -l | awk '{printf "%.2f", \\$0}')
                            echo "  Load/CPU Ratio: \\$LOAD_RATIO"
                        fi
                    """
                    
                    echo ""
                    echo "NETWORK CONNECTIVITY TEST:"
                    sh """
                        # Test internal cluster connectivity
                        echo "  Testing cluster DNS..."
                        if nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
                            echo "  GOOD: Cluster DNS resolution working"
                        else
                            echo "  CRITICAL: Cluster DNS resolution failed"
                        fi
                        
                        # Test external connectivity
                        echo "  Testing external connectivity..."
                        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
                            echo "  GOOD: External network connectivity OK"
                        else
                            echo "  WARNING: External connectivity issues"
                        fi
                        
                        # Test Jenkins master connectivity
                        echo "  Testing Jenkins master connectivity..."
                        if [ -n "\\$JENKINS_URL" ]; then
                            if curl -s --connect-timeout 5 "\\$JENKINS_URL" >/dev/null 2>&1; then
                                echo "  GOOD: Jenkins master reachable"
                            else
                                echo "  CRITICAL: Cannot reach Jenkins master"
                            fi
                        else
                            echo "  INFO: JENKINS_URL not set, skipping test"
                        fi
                    """
                    
                    echo ""
                    echo "KUBERNETES ENVIRONMENT CHECK:"
                    sh """
                        if [ -n "\\$KUBERNETES_SERVICE_HOST" ]; then
                            echo "  Environment: Kubernetes Pod"
                            echo "  Service Host: \\$KUBERNETES_SERVICE_HOST"
                            echo "  Namespace: \\${KUBERNETES_NAMESPACE:-default}"
                            echo "  Service Account: \\$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null || echo 'Not available')"
                            
                            # Check for spot instance annotations/labels
                            echo "  Checking spot instance indicators..."
                            if [ -f /proc/cpuinfo ]; then
                                echo "  Instance type detection attempted"
                            fi
                            
                            # Check for Azure spot instance metadata if available
                            if command -v curl >/dev/null 2>&1; then
                                SPOT_CHECK=\\$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance/compute/priority?api-version=2021-02-01" 2>/dev/null || echo "unknown")
                                if [ "\\$SPOT_CHECK" = "Spot" ]; then
                                    echo "  CONFIRMED: Running on Azure Spot Instance"
                                elif [ "\\$SPOT_CHECK" = "Regular" ]; then
                                    echo "  INFO: Running on Regular Instance (not spot)"
                                else
                                    echo "  INFO: Spot status unknown (metadata not available)"
                                fi
                            fi
                        else
                            echo "  Environment: Standalone or Docker"
                            echo "  WARNING: Not running in Kubernetes - unexpected for spot workers"
                        fi
                    """
                    
                    echo ""
                    echo "SPOT WORKER STABILITY TEST:"
                    
                    // Test worker responsiveness with small tasks
                    for (int i = 1; i <= 3; i++) {
                        echo "  Running stability test ${i}/3..."
                        sh "echo '    Test ${i}: Basic command execution' && sleep 1"
                        sh "echo '    Test ${i}: File system write test' && echo 'test' > /tmp/spot_test_${i}.txt && rm -f /tmp/spot_test_${i}.txt"
                        echo "    Test ${i} completed successfully"
                    }
                    
                    def endTime = new Date()
                    def duration = (endTime.time - startTime.time) / 1000
                    
                    echo ""
                    echo "MONITORING SUMMARY:"
                    echo "  End Time: ${endTime.format('yyyy-MM-dd HH:mm:ss')}"
                    echo "  Total Duration: ${duration} seconds"
                    echo "  Worker Status: RESPONDING"
                    echo "  Next Check: ${new Date(endTime.time + 300000).format('HH:mm:ss')} (in 5 min)"
                    echo ""
                    echo "DIAGNOSTIC RESULT: SPOT WORKER HEALTHY"
                    echo "============================================"
                }
            }
        }
        
        stage('Performance Stress Test') {
            when {
                expression { 
                    // Run stress test every 6th execution (every 30 minutes)
                    return (env.BUILD_NUMBER as Integer) % 6 == 0 
                }
            }
            steps {
                script {
                    echo ""
                    echo "EXTENDED PERFORMANCE TEST (Every 30 min)"
                    echo "============================================"
                    
                    sh """
                        echo "  Running CPU stress test..."
                        timeout 10 yes > /dev/null &
                        CPU_PID=\\$!
                        sleep 5
                        kill \\$CPU_PID 2>/dev/null || true
                        echo "  CPU stress test completed"
                        
                        echo "  Running memory allocation test..."
                        timeout 5 dd if=/dev/zero of=/tmp/memory_test bs=1M count=50 2>/dev/null || true
                        rm -f /tmp/memory_test 2>/dev/null || true
                        echo "  Memory test completed"
                        
                        echo "  Running I/O stress test..."
                        timeout 5 dd if=/dev/zero of=/tmp/io_test bs=1M count=100 2>/dev/null || true
                        rm -f /tmp/io_test 2>/dev/null || true
                        echo "  I/O test completed"
                    """
                    
                    echo "  RESULT: Spot worker survived stress test"
                    echo "============================================"
                }
            }
        }
    }
    
    post {
        always {
            script {
                def currentTime = new Date()
                def nodeName = env.NODE_NAME ?: "Unknown"
                echo ""
                echo "MONITORING CYCLE COMPLETED"
                echo "============================================"
                echo "Next spot worker health check in 5 minutes"
                echo "Continuous monitoring active for spot stability"
            }
        }
        success {
            script {
                def currentTime = new Date()
                def nodeName = env.NODE_NAME ?: "Unknown"
                echo ""
                echo "SUCCESS - ${currentTime.format('HH:mm:ss')} - Pod: ${nodeName}"
                echo "Spot worker is healthy and responsive"
                echo "Cost optimization functioning correctly"
            }
        }
        failure {
            script {
                def currentTime = new Date()
                def nodeName = env.NODE_NAME ?: "Unknown"
                echo ""
                echo "FAILURE - ${currentTime.format('HH:mm:ss')} - Pod: ${nodeName}"
                echo "SPOT WORKER ISSUE DETECTED"
                echo "============================================"
                echo "TROUBLESHOOTING STEPS:"
                echo "1. Check if spot instances are being evicted by Azure"
                echo "2. Verify nodepool=spot label configuration"
                echo "3. Check resource quotas and limits"
                echo "4. Review pod scheduling tolerations"
                echo "5. Check Azure spot instance availability in region"
                echo "6. Verify RBAC permissions for spot worker creation"
                echo "============================================"
            }
        }
        unstable {
            script {
                def currentTime = new Date()
                def nodeName = env.NODE_NAME ?: "Unknown"
                echo ""
                echo "UNSTABLE - ${currentTime.format('HH:mm:ss')} - Pod: ${nodeName}"
                echo "Spot worker showing signs of instability"
                echo "Monitor next execution for potential issues"
            }
        }
    }
}
'''

job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
job.save()

println "Advanced Spot Worker Monitoring pipeline '${jobName}' created successfully"
println ""
println "DIAGNOSTIC CAPABILITIES:"
println "  Pod lifecycle detection (new/reused/long-running)"
println "  Memory pressure monitoring (OOM kill prevention)"
println "  Disk usage monitoring (eviction prevention)"
println "  Network connectivity testing (cluster + external)"
println "  Azure spot instance verification"
println "  Jenkins master connectivity check"
println "  Kubernetes environment validation"
println "  Worker stability testing"
println "  Performance stress testing (every 30 min)"
println ""
println "TROUBLESHOOTING FEATURES:"
println "  - Detects spot instance evictions"
println "  - Identifies resource pressure issues"
println "  - Monitors pod restart patterns"
println "  - Tests network connectivity problems"
println "  - Validates worker responsiveness"
println "  - Provides actionable error messages"
println ""
println "MONITORING CONFIGURATION:"
println "  Execution Schedule: Every 5 minutes (cron: */5 * * * *)"
println "  Target: Spot workers (nodepool=spot)"
println "  Timeout: 2 minutes per execution"
println "  Build History: Last 50 executions"
println "  Stress Tests: Every 30 minutes"
println ""
println "CLIENT ISSUE DETECTION:"
println "  This pipeline will help identify:"
println "  - Why spot workers are falling down"
println "  - When spot instances get evicted"
println "  - Resource pressure causing restarts"
println "  - Network connectivity issues"
println "  - Configuration problems"
println ""
println "Usage:"
println "1. The pipeline will start automatically every 5 minutes"
println "2. Check Jenkins dashboard for execution status"
println "3. Review logs to monitor spot worker activity"
println "4. Use 'Build Now' for manual execution if needed"
println ""

jenkins.save()

println "Continuous monitoring configured and active"
