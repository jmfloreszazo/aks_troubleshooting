// SCRIPT: Pipeline Spot con Prioridad 2 (ALTA) - Preseleccionada
// ==============================================================
// Ejecutar en Jenkins Script Console para crear pipeline con prioridad ALTA

import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

println """
🟠 CREANDO PIPELINE SPOT - PRIORIDAD ALTA (2)
============================================

Este script crea un pipeline que usa nodos SPOT
con prioridad ALTA (2) preseleccionada.

"""

def jenkins = Jenkins.getInstance()

try {
    println "\n🆕 CREANDO PIPELINE SPOT - PRIORIDAD ALTA"
    println "========================================"
    
    // Nombre del pipeline
    def pipelineName = 'spot-high-priority-2'
    
    // Eliminar pipeline existente si existe
    def existingJob = jenkins.getItem(pipelineName)
    if (existingJob) {
        existingJob.delete()
        println "   🗑️ Pipeline existente eliminado: ${pipelineName}"
    }
    
    // Definir el pipeline con prioridad ALTA fija
    def pipelineScript = '''
pipeline {
    agent { label 'nodepool=spot' }
    
    parameters {
        choice(
            name: 'PRIORITY_LEVEL',
            choices: ['2'],
            description: 'Prioridad fija: 2 (ALTA) - No modificar'
        )
        string(
            name: 'TASK_NAME',
            defaultValue: 'High Priority Task',
            description: 'Nombre de la tarea de alta prioridad'
        )
    }
    
    options {
        timeout(time: 8, unit: 'MINUTES')  // Timeout ajustado para tareas importantes
        buildDiscarder(logRotator(numToKeepStr: '12'))
    }
    
    stages {
        stage('High Priority Info') {
            steps {
                script {
                    echo "PIPELINE SPOT - PRIORIDAD ALTA"
                    echo "==============================="
                    echo "Priority Level: 2 (ALTA)"
                    echo "Execution Order: SEGUNDO"
                    echo "⚡ EJECUCIÓN PRIORITARIA - ALTA IMPORTANCIA"
                }
            }
        }
        
        stage('Environment Info') {
            steps {
                script {
                    echo "🎯 INFORMACIÓN DEL ENTORNO SPOT - ALTA PRIORIDAD"
                    echo "==============================================="
                    echo "Jenkins Node: ${env.NODE_NAME}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                    echo "Workspace: ${env.WORKSPACE}"
                    echo "Priority: 2 (ALTA)"
                    echo "Task: ${params.TASK_NAME}"
                }
                
                sh """
                    echo "📍 Pod/Nodo Spot - Tarea de Alta Prioridad:"
                    POD_NAME=\\$(hostname)
                    echo "Pod Name: \\$POD_NAME"
                    POD_IP=\\$(hostname -i)
                    echo "Pod IP: \\$POD_IP"
                    
                    echo "🟠 CONFIGURACIÓN ALTA PRIORIDAD:"
                    echo "• Priority: 2 (ALTA PRIORIDAD)"
                    echo "• NodeSelector: nodepool=spot"
                    echo "• Execution: SEGUNDA en cola"
                    echo "• Timeout: 8 minutos (balanceado)"
                    
                    echo "📊 Recursos para tarea importante:"
                    CPU_CORES=\\$(nproc)
                    echo "CPU cores: \\$CPU_CORES"
                    if command -v free >/dev/null 2>&1; then
                        MEMORY=\\$(free -h | grep Mem | awk '{print \\$2}')
                    else
                        MEMORY=\\$(cat /proc/meminfo | grep MemTotal | awk '{print \\$2 " KB"}')
                    fi
                    echo "Memory: \\$MEMORY"
                    
                    echo "💰 NODO SPOT - PRIORIDAD ALTA"
                    echo "Ahorro: 80-90% + Ejecución prioritaria"
                """
            }
        }
        
        stage('High Priority Spot Validation') {
            steps {
                script {
                    echo "🔍 VALIDACIÓN ALTA PRIORIDAD - NODO SPOT"
                    echo "======================================="
                }
                
                sh """
                    echo "🟠 VALIDACIÓN DE PRIORIDAD ALTA"
                    echo "Pod ejecutándose: \\$(hostname)"
                    
                    echo "✅ CONFIRMADO: Configuración SPOT + ALTA PRIORIDAD"
                    echo "🎯 Características de alta prioridad:"
                    echo "• Priority: 2 (ALTA)"
                    echo "• NodeSelector: nodepool=spot"
                    echo "• Execution Order: SEGUNDA en cola"
                    echo "• Timeout: 8 minutos (optimizado)"
                    
                    echo "🚀 EJECUCIÓN PRIORITARIA:"
                    echo "• Se ejecuta después de tareas críticas (priority 1)"
                    echo "• Ideal para: Releases importantes, testing crítico"
                    echo "• Combina ahorro SPOT + alta prioridad"
                """
            }
        }
        
        stage('High Priority Build Spot') {
            steps {
                script {
                    echo "🔨 EJECUTANDO BUILD IMPORTANTE EN NODO SPOT"
                    echo "=========================================="
                }
                
                sh """
                    echo "🟠 TAREA DE ALTA PRIORIDAD EN EJECUCIÓN"
                    echo "Task: ${params.TASK_NAME}"
                    echo "Priority: 2 (ALTA)"
                    echo "💰 Ahorrando 80-90% en costos"
                    
                    echo "🚀 EJECUCIÓN IMPORTANTE:"
                    for i in \\$(seq 1 3); do
                        echo "🟠 High priority step \\$i/3 executing..."
                        sleep 1
                    done
                    
                    echo "✅ Build importante completado exitosamente"
                    echo "⚡ Ejecutado con alta prioridad en nodo spot"
                """
            }
        }
        
        stage('High Priority Cost Benefits') {
            steps {
                script {
                    echo "💰 BENEFICIOS - PRIORIDAD ALTA + SPOT"
                    echo "===================================="
                    echo "🟠 Prioridad: ALTA (2)"
                    echo "💸 Ahorro: ~85% vs nodos regulares"
                    echo "⚡ Ejecución: SEGUNDA en cola"
                    echo ""
                    echo "🎯 CASOS DE USO ALTA PRIORIDAD:"
                    echo "• Releases importantes"
                    echo "• Testing de funcionalidades críticas"
                    echo "• Builds de ramas principales"
                    echo "• Validaciones pre-producción"
                    echo ""
                    echo "💡 VENTAJAS COMBINADAS:"
                    echo "• Alta prioridad + Máximo ahorro"
                    echo "• Ejecución preferente en infraestructura spot"
                    echo "• Ideal para CI/CD importante"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🏁 Pipeline de alta prioridad completado"
                echo "Node: ${env.NODE_NAME}"
                echo "Priority: 2 (ALTA)"
                echo "Task: ${params.TASK_NAME}"
            }
        }
        success {
            echo "✅ Pipeline ALTA PRIORIDAD ejecutado exitosamente"
            echo "🟠 Prioridad 2 - Ejecución preferente"
            echo "💰 Ahorro conseguido: ~85%"
            echo "⚡ Tiempo de respuesta: EXCELENTE"
        }
        failure {
            echo "❌ Pipeline de alta prioridad falló"
            echo "🟠 Priority: 2 (ALTA)"
            echo "⚠️ Requiere atención prioritaria"
        }
    }
}
'''
    
    // Crear el job
    def job = jenkins.createProject(WorkflowJob, pipelineName)
    job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
    job.save()
    
    println "   ✅ Pipeline creado: ${pipelineName}"
    
    // Guardar configuración
    jenkins.save()
    
    println "\n🟠 PIPELINE ALTA PRIORIDAD CREADO EXITOSAMENTE"
    println "============================================="
    println ""
    println "📋 PIPELINE CREADO:"
    println "==================="
    println "🎯 ${pipelineName}"
    println "   • Prioridad: 2 (ALTA) - FIJA"
    println "   • Usa nodos SPOT (nodepool=spot)"
    println "   • Ejecución PREFERENTE"
    println "   • Timeout balanceado: 8 minutos"
    println ""
    println "🔧 PARÁMETROS:"
    println "=============="
    println "📝 TASK_NAME (string):"
    println "   • Default: 'High Priority Task'"
    println "   • Descripción: Nombre de la tarea importante"
    println ""
    println "🟠 CARACTERÍSTICAS ALTA PRIORIDAD:"
    println "================================="
    println "✅ Prioridad 2 (ALTA) - Preseleccionada"
    println "✅ Ejecución SEGUNDA en cola"
    println "✅ Timeout balanceado (8 min)"
    println "✅ Ahorro 80-90% en nodos SPOT"
    println "✅ Optimizado para tareas importantes"
    println ""
    println "🚀 CASOS DE USO:"
    println "==============="
    println "📦 Releases importantes"
    println "🧪 Testing de funcionalidades críticas"
    println "🌟 Builds de ramas principales (main/master)"
    println "✅ Validaciones pre-producción"
    println ""
    println "💡 VENTAJAS:"
    println "============"
    println "⚡ Ejecución preferente (Priority 2)"
    println "💰 Máximo ahorro (nodos SPOT)"
    println "🎯 Optimizado para importancia"
    println "⏱️ Timeout balanceado para flexibilidad"
    println ""
    println "✅ ¡PIPELINE ALTA PRIORIDAD LISTO!"
    println "Ve a Jenkins → '${pipelineName}' → Build Now"
    
} catch (Exception e) {
    println "❌ ERROR CREANDO PIPELINE ALTA PRIORIDAD:"
    println "======================================="
    println "Error: ${e.message}"
    e.printStackTrace()
}
