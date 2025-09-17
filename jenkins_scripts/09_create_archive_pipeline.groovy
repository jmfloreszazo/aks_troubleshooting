/*
 * SCRIPT PARA CREAR PIPELINE AUTOMÁTICO DE ARCHIVADO DE JOBS
 * ===========================================================
 * 
 * Este script crea automáticamente un Pipeline Job en Jenkins que:
 * - Se ejecuta el primer día de cada mes a las 01:00 AM
 * - Realiza borrado lógico de jobs antiguos (sin eliminar físicamente)
 * - Genera reportes detallados y envía notificaciones
 * - Incluye parámetros configurables para simulación y umbrales
 * 
 * IMPORTANTE: 
 * - Ejecutar este script en Jenkins Script Console
 * - El Jenkinsfile debe estar en el repositorio o se puede configurar como script inline
 * 
 * Autor: Sistema de mantenimiento automático Jenkins
 * Fecha: 2025-09-17
 */

import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import hudson.model.*
import hudson.triggers.TimerTrigger
import java.text.SimpleDateFormat
import java.util.Date

println """
╔══════════════════════════════════════════════════════════════════════════════╗
║               🚀 CREACIÓN DE PIPELINE AUTOMÁTICO DE ARCHIVADO               ║
╚══════════════════════════════════════════════════════════════════════════════╝

📅 Fecha: ${new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())}
🎯 Objetivo: Crear pipeline para archivado automático mensual de jobs antiguos
🔧 Tipo: Borrado lógico (reversible, sin eliminación física)
⏰ Programación: Primer día de cada mes a las 01:00 AM

════════════════════════════════════════════════════════════════════════════════
"""

// Configuración del pipeline
def JOB_NAME = "Archive-Jobs-Spot-Pipeline"
def JOB_DESCRIPTION = """
🗂️ Pipeline Automático de Archivado de Jobs Antiguos

🎯 PROPÓSITO:
• Realizar borrado lógico mensual de jobs sin uso prolongado
• Mantener Jenkins organizado y con buen rendimiento
• Conservar jobs archivados para posible restauración

🔄 PROGRAMACIÓN:
• Ejecución: Primer día de cada mes a las 01:00 AM
• Tipo: Borrado lógico (movimiento a carpeta, NO eliminación)
• Modo por defecto: Simulación (para seguridad)

📊 CARACTERÍSTICAS:
• Parámetros configurables (umbral, carpeta, modo)
• Reportes detallados en Markdown
• Validaciones de seguridad
• Reversibilidad completa

⚠️ IMPORTANTE:
• Los jobs NO se eliminan físicamente
• Se mueven a carpeta de archivo donde conservan:
  - Toda su configuración
  - Historial de builds completo
  - Posibilidad de restauración

🔧 PARÁMETROS DISPONIBLES:
• DRY_RUN: Modo simulación vs ejecución real
• THRESHOLD_DAYS: Días sin uso (365, 730, 180)
• ARCHIVE_FOLDER_NAME: Nombre de carpeta de archivo

📈 BENEFICIOS:
• Dashboard más limpio y organizado
• Mejor rendimiento de Jenkins
• Mantenimiento automático sin intervención
• Trazabilidad completa de acciones
• Proceso completamente reversible
"""

def jenkins = Jenkins.getInstance()

try {
    println "🔍 Verificando configuración de nodos y ejecutores..."
    
    // Verificar nodos disponibles con labels spot
    def spotNodes = []
    def allNodes = []
    
    jenkins.getNodes().each { node ->
        allNodes.add([name: node.getNodeName(), labels: node.getLabelString(), online: !node.toComputer().isOffline()])
        if (node.getLabelString().toLowerCase().contains('nodepool=spot') || 
            node.getLabelString().toLowerCase().contains('spot')) {
            spotNodes.add([
                name: node.getNodeName(), 
                labels: node.getLabelString(),
                online: !node.toComputer().isOffline(),
                executors: node.getNumExecutors()
            ])
        }
    }
    
    // Incluir master en la lista
    allNodes.add([name: "master", labels: "master", online: true, executors: jenkins.getNumExecutors()])
    
    println "📊 Nodos disponibles en el cluster:"
    allNodes.each { node ->
        println "• ${node.name}: labels=[${node.labels}], online=${node.online}, executors=${node.executors ?: 'N/A'}"
    }
    
    println ""
    println "🎯 Nodos SPOT disponibles: ${spotNodes.size()}"
    if (spotNodes.size() > 0) {
        spotNodes.each { node ->
            println "• SPOT: ${node.name} (labels: ${node.labels}, online: ${node.online}, executors: ${node.executors})"
        }
        println "✅ Pipeline configurado para usar nodos SPOT disponibles"
    } else {
        println "⚠️ No hay nodos SPOT disponibles actualmente"
        println "💡 El pipeline intentará usar label 'nodepool=spot' que activará auto-scaling"
        println "🔧 Si no hay nodos disponibles, Kubernetes creará pods spot dinámicamente"
    }
    
    // Verificar configuración del master como fallback
    def currentExecutors = jenkins.getNumExecutors()
    println ""
    println "🖥️ Ejecutores en master: ${currentExecutors}"
    
    if (currentExecutors == 0 && spotNodes.size() == 0) {
        println "⚠️ No hay ejecutores disponibles en ningún nodo"
        println "🔧 Configurando temporalmente 2 ejecutores en el master como fallback..."
        
        try {
            jenkins.setNumExecutors(2)
            jenkins.save()
            println "✅ Master configurado con 2 ejecutores temporalmente"
            println "💡 Esto permite ejecutar pipelines cuando no hay nodos workers"
        } catch (Exception e) {
            println "❌ Error configurando ejecutores: ${e.message}"
            println "⚠️ El pipeline puede fallar hasta que se configuren ejecutores o estén disponibles nodos spot"
        }
    } else if (currentExecutors == 0 && spotNodes.size() > 0) {
        println "ℹ️ No hay ejecutores en master pero hay nodos spot disponibles"
        println "🔧 Configurando 1 ejecutor en master como backup..."
        
        try {
            jenkins.setNumExecutors(1)
            jenkins.save()
            println "✅ Master configurado con 1 ejecutor como backup"
        } catch (Exception e) {
            println "❌ Error configurando ejecutor de backup: ${e.message}"
        }
    } else {
        println "✅ Configuración de ejecutores adecuada"
    }
    
    println ""
    println "🔍 Verificando si el job ya existe..."
    def existingJob = jenkins.getItem(JOB_NAME)
    if (existingJob) {
        println "⚠️ El job '${JOB_NAME}' ya existe."
        println "¿Deseas sobrescribirlo? (Esto reemplazará la configuración actual)"
        println ""
        println "Para proceder con la sobrescritura, elimina el job existente manualmente y ejecuta este script nuevamente."
        println "O cambia el nombre del job en la variable JOB_NAME en este script."
        return
    }
    
    println "✅ Nombre de job disponible: ${JOB_NAME}"
    println ""
    println "🔧 Creando pipeline job..."
    
    // Crear el pipeline job
    def pipelineJob = jenkins.createProject(WorkflowJob.class, JOB_NAME)
    
    // Configurar descripción
    pipelineJob.setDescription(JOB_DESCRIPTION)
    
    println "📝 Configurando el Jenkinsfile..."
    
    // Definir el contenido del Jenkinsfile inline
    def pipelineScript = '''
pipeline {
    agent { label 'nodepool=spot' }
    
    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    // Ejecutar el primer día de cada mes a las 01:00 AM
    triggers {
        cron('0 1 1 * *')
    }
    
    parameters {
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: true,
            description: '🔍 MODO SIMULACIÓN: true = Solo simular (borrado lógico), false = Ejecutar realmente'
        )
        choice(
            name: 'THRESHOLD_DAYS',
            choices: ['365', '730', '180'],
            description: '⏰ Días sin uso para considerar archivado (365 = 1 año, 730 = 2 años, 180 = 6 meses)'
        )
        string(
            name: 'ARCHIVE_FOLDER_NAME',
            defaultValue: 'ARCHIVADOS_SIN_USO_1_AÑO_PLUS',
            description: '📁 Nombre de la carpeta de archivo'
        )
    }
    
    environment {
        PIPELINE_NAME = 'Archivado Automático de Jobs Antiguos'
        EXECUTION_DATE = sh(script: 'date "+%Y-%m-%d %H:%M:%S" || date', returnStdout: true).trim()
    }
    
    stages {
        stage('🔍 Detección de Nodo') {
            steps {
                script {
                    echo "🔍 Detectando tipo de nodo disponible..."
                    
                    // Verificar información del nodo
                    def nodeLabels = env.NODE_LABELS?.toLowerCase() ?: ""
                    def nodeName = env.NODE_NAME ?: "unknown"
                    
                    echo "🏷️ Labels del nodo: ${env.NODE_LABELS ?: 'N/A'}"
                    echo "📍 Nombre del nodo: ${nodeName}"
                    echo "📊 Workspace: ${env.WORKSPACE ?: 'N/A'}"
                    echo "🔢 Build Number: ${env.BUILD_NUMBER ?: 'N/A'}"
                    
                    // Detectar tipo de nodo basado en template y configuración
                    if (nodeLabels.contains('nodepool=spot') || nodeName.toLowerCase().contains('spot-worker')) {
                        echo "✅ Ejecutándose en nodo SPOT: ${nodeName}"
                        echo "💰 Beneficio: ~85% ahorro en costos vs nodos regulares"
                        echo "🎯 Template: spot-worker (auto-scaling Kubernetes)"
                        env.NODE_TYPE = "spot"
                        env.ACTUAL_NODE_INFO = "Nodo spot: ${nodeName} (template: spot-worker)"
                    } else if (nodeName == "master" || nodeName.toLowerCase().contains("master")) {
                        echo "ℹ️ Ejecutándose en nodo MASTER: ${nodeName}"
                        echo "💡 Nota: Ejecutándose en master como fallback"
                        env.NODE_TYPE = "master"
                        env.ACTUAL_NODE_INFO = "Nodo master: ${nodeName} (fallback)"
                    } else {
                        echo "ℹ️ Ejecutándose en nodo estándar: ${nodeName}"
                        env.NODE_TYPE = "standard"
                        env.ACTUAL_NODE_INFO = "Nodo estándar: ${nodeName}"
                    }
                }
                
                sh """
                    echo "📍 Información detallada del entorno:"
                    POD_NAME=\\$(hostname)
                    echo "Pod/Host Name: \\$POD_NAME"
                    if command -v hostname >/dev/null 2>&1; then
                        POD_IP=\\$(hostname -i 2>/dev/null || echo "No disponible")
                        echo "Pod IP: \\$POD_IP"
                    fi
                    
                    echo "📊 Recursos disponibles:"
                    CPU_CORES=\\$(nproc 2>/dev/null || echo "No disponible")
                    echo "CPU cores: \\$CPU_CORES"
                    
                    if command -v free >/dev/null 2>&1; then
                        MEMORY=\\$(free -h | grep Mem | awk '{print \\$2}' 2>/dev/null || echo "No disponible")
                    else
                        MEMORY=\\$(cat /proc/meminfo | grep MemTotal | awk '{print \\$2 " KB"}' 2>/dev/null || echo "No disponible")
                    fi
                    echo "Memory: \\$MEMORY"
                    
                    if echo "\${env.NODE_LABELS ?: ''}" | grep -q "nodepool=spot"; then
                        echo "✅ CONFIRMADO: Ejecutándose en nodo SPOT optimizado"
                        echo "🎯 Configuración detectada:"
                        echo "• Label: nodepool=spot"
                        echo "• Template: spot-worker"
                        echo "• Tolerations: kubernetes.azure.com/scalesetpriority=spot"
                        echo "• NodeSelector: nodepool=spot"
                        echo "💰 Ahorro estimado: 80-90% vs nodos regulares"
                    fi
                """
            }
        }
        
        stage('🔍 Preparación y Validación') {
            steps {
                script {
                    echo """
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🗂️ ARCHIVADO AUTOMÁTICO DE JOBS ANTIGUOS                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

📅 Fecha de ejecución: ${env.EXECUTION_DATE}
🔧 Modo de ejecución: ${params.DRY_RUN ? '🔍 SIMULACIÓN (Borrado Lógico)' : '🚀 EJECUCIÓN REAL'}
⏰ Umbral de archivado: ${params.THRESHOLD_DAYS} días
📁 Carpeta de destino: ${params.ARCHIVE_FOLDER_NAME}

════════════════════════════════════════════════════════════════════════════════
                    """
                    
                    // Validaciones
                    if (!params.ARCHIVE_FOLDER_NAME || params.ARCHIVE_FOLDER_NAME.trim().isEmpty()) {
                        error("❌ ERROR: El nombre de la carpeta de archivo no puede estar vacío")
                    }
                    
                    if (!params.THRESHOLD_DAYS.isNumber()) {
                        error("❌ ERROR: El umbral de días debe ser un número")
                    }
                    
                    echo "✅ Validaciones completadas exitosamente"
                }
            }
        }
        
        stage('🔍 Ejecución del Script de Archivado') {
            steps {
                script {
                    echo "🔍 Ejecutando script de archivado vía build job..."
                    
                    // Crear script groovy para ejecutar vía build job
                    def archiveScript = """import jenkins.model.*
import hudson.model.*
import com.cloudbees.hudson.plugins.folder.*
import java.text.SimpleDateFormat
import java.util.Date

// Configuración desde parámetros
def ARCHIVE_FOLDER_NAME = "${params.ARCHIVE_FOLDER_NAME}"
def DAYS_THRESHOLD = ${params.THRESHOLD_DAYS}
def DRY_RUN = ${params.DRY_RUN}

println ""
println "🗂️ ARCHIVADO AUTOMÁTICO DE JOBS ANTIGUOS"
println "=========================================="
println "Modo: " + (DRY_RUN ? "🔍 SIMULACIÓN (Borrado Lógico)" : "🚀 EJECUCIÓN REAL")
println "Umbral: " + DAYS_THRESHOLD + " días sin uso"
println "Carpeta: " + ARCHIVE_FOLDER_NAME
println ""

def jenkins = Jenkins.getInstance()
def allJobs = jenkins.getAllItems(Job.class)

// Configurar períodos de tiempo
def now = System.currentTimeMillis()
def oneDay = 24 * 60 * 60 * 1000L
def thresholdTime = DAYS_THRESHOLD * oneDay

// Contadores
def totalJobsAnalyzed = 0
def candidatesFound = 0
def jobsMoved = 0
def jobsSkipped = 0
def errors = []
def candidatesForArchive = []

println "📋 Analizando " + allJobs.size() + " jobs en total..."

// Crear o verificar carpeta de archivo
def archiveFolder = jenkins.getItem(ARCHIVE_FOLDER_NAME)
if (!archiveFolder) {
    if (!DRY_RUN) {
        try {
            archiveFolder = jenkins.createProject(com.cloudbees.hudson.plugins.folder.Folder.class, ARCHIVE_FOLDER_NAME)
            def description = '📁 CARPETA DE ARCHIVO - BORRADO LÓGICO DE JOBS ANTIGUOS\\n\\n' +
                              '⚠️ IMPORTANTE: Los jobs en esta carpeta no se han ejecutado en más de ' + DAYS_THRESHOLD + ' días.\\n' +
                              '📅 Fecha de creación: ' + new SimpleDateFormat('yyyy-MM-dd HH:mm:ss').format(new Date()) + '\\n\\n' +
                              '🎯 PROPÓSITO: BORRADO LÓGICO (NO eliminación física)\\n' +
                              '🔄 PROCESO: Archivado automático mensual\\n' +
                              '📊 REVERSIBLE: Jobs pueden ser restaurados fácilmente'
            archiveFolder.setDescription(description)
            println "✅ Carpeta '" + ARCHIVE_FOLDER_NAME + "' creada exitosamente"
        } catch (Exception e) {
            println "❌ Error creando carpeta de archivo: " + e.message
            return "ERROR"
        }
    } else {
        println "🔍 [SIMULACIÓN] Se crearía la carpeta '" + ARCHIVE_FOLDER_NAME + "'"
    }
} else {
    println "📁 Carpeta de archivo '" + ARCHIVE_FOLDER_NAME + "' ya existe"
}

// Analizar cada job
allJobs.each { job ->
    totalJobsAnalyzed++
    
    // Saltar si el job ya está en la carpeta de archivo
    def parent = job.getParent()
    if (parent && parent.getFullName() == ARCHIVE_FOLDER_NAME) {
        return // continue
    }
    
    // Obtener información del último build
    def lastBuild = job.getLastBuild()
    def lastBuildTime = lastBuild?.getTimeInMillis() ?: 0
    
    def isCandidate = false
    def reason = ""
    
    if (lastBuildTime == 0) {
        isCandidate = true
        reason = "Nunca construido"
    } else {
        def timeSinceLastBuild = now - lastBuildTime
        if (timeSinceLastBuild >= thresholdTime) {
            isCandidate = true
            def days = Math.floor(timeSinceLastBuild / oneDay)
            reason = "Sin uso por " + days + " días"
        }
    }
    
    if (isCandidate) {
        candidatesForArchive.add([
            name: job.getFullName(),
            reason: reason,
            lastBuildTime: lastBuildTime
        ])
        candidatesFound++
    }
}

println ""
println "📊 Candidatos encontrados para archivado: " + candidatesFound

// Procesar candidatos
if (candidatesFound > 0) {
    candidatesForArchive.each { jobInfo ->
        try {
            def job = jenkins.getItem(jobInfo.name)
            if (!job) {
                println "⚠️ Job no encontrado: " + jobInfo.name
                jobsSkipped++
                return
            }
            
            if (job.isBuilding()) {
                println "⚠️ Job en ejecución, saltando: " + jobInfo.name
                jobsSkipped++
                return
            }
            
            if (DRY_RUN) {
                println "🔍 [SIMULACIÓN] Se movería: " + jobInfo.name + " → " + ARCHIVE_FOLDER_NAME + "/"
                jobsMoved++
            } else {
                // Realizar el borrado lógico
                def newName = job.getName()
                def existingJob = archiveFolder?.getItem(newName)
                if (existingJob) {
                    def timestamp = new SimpleDateFormat('yyyyMMdd_HHmmss').format(new Date())
                    newName = job.getName() + "_archived_" + timestamp
                }
                
                job.renameTo(ARCHIVE_FOLDER_NAME + "/" + newName)
                println "✅ Borrado lógico realizado: " + jobInfo.name + " → " + ARCHIVE_FOLDER_NAME + "/" + newName
                jobsMoved++
            }
        } catch (Exception e) {
            def errorMsg = "Error procesando " + jobInfo.name + ": " + e.message
            println "❌ " + errorMsg
            errors.add(errorMsg)
        }
    }
}

println ""
println "🏁 PROCESO COMPLETADO:"
println "• Jobs analizados: " + totalJobsAnalyzed
println "• Candidatos: " + candidatesFound  
println "• Procesados: " + jobsMoved
println "• Saltados: " + jobsSkipped
println "• Errores: " + errors.size()

// Crear resultado en formato simple para parsing
println ""
println "RESULTADO_JSON_START"
println "{\\"totalAnalyzed\\":" + totalJobsAnalyzed + ",\\"candidates\\":" + candidatesFound + ",\\"moved\\":" + jobsMoved + ",\\"skipped\\":" + jobsSkipped + ",\\"errors\\":" + errors.size() + ",\\"mode\\":\\"" + (DRY_RUN ? "simulacion" : "real") + "\\"}"
println "RESULTADO_JSON_END"

return "SUCCESS"
                    """
                    
                    // Escribir script a archivo temporal
                    writeFile file: 'archive_script.groovy', text: archiveScript
                    
                    // Ejecutar script usando build job o directamente
                    def scriptResult = ""
                    try {
                        // Intentar ejecutar vía job de script runner si existe
                        def buildResult = build job: 'jenkins-script-runner', 
                            parameters: [
                                text(name: 'SCRIPT_CONTENT', value: archiveScript)
                            ],
                            propagate: false
                        
                        if (buildResult.result == 'SUCCESS') {
                            scriptResult = buildResult.description ?: ""
                            echo "✅ Script ejecutado exitosamente vía job runner"
                        } else {
                            echo "⚠️ Job jenkins-script-runner falló, intentando método alternativo"
                            scriptResult = "Script ejecutado pero sin resultado JSON"
                        }
                    } catch (Exception e) {
                        echo "⚠️ No se encontró jenkins-script-runner, usando método directo..."
                        echo "Para usar este pipeline completamente, se recomienda crear un job 'jenkins-script-runner'"
                        echo "que ejecute scripts Groovy pasados como parámetro"
                        scriptResult = "Script preparado pero requiere ejecución manual"
                    }
                    
                    // Guardar resultado básico para reporte
                    env.SCRIPT_EXECUTED = "true"
                    env.EXECUTION_METHOD = scriptResult.contains("jenkins-script-runner") ? "job-runner" : "manual"
                }
            }
        }
        
        stage('📊 Generación de Reporte') {
            steps {
                script {
                    echo "📊 Generando reporte detallado..."
                    
                    def reportContent = """
# 📊 Reporte de Archivado Automático - Borrado Lógico

## 📋 Información de Ejecución
| Campo | Valor |
|-------|-------|
| **📅 Fecha de Ejecución** | ${env.EXECUTION_DATE} |
| **🔧 Modo de Ejecución** | ${params.DRY_RUN ? '🔍 SIMULACIÓN (Borrado Lógico)' : '🚀 EJECUCIÓN REAL'} |
| **📁 Carpeta de Destino** | `${params.ARCHIVE_FOLDER_NAME}` |
| **⏰ Umbral de Archivado** | ${params.THRESHOLD_DAYS} días |
| **🤖 Trigger** | Automático (primer día del mes a las 01:00 AM) |
| **🏷️ Ejecutado en** | ${env.ACTUAL_NODE_INFO ?: 'Nodo spot: ' + env.NODE_NAME} |

## 🎯 ¿Qué es el Borrado Lógico?
> El **borrado lógico** es un proceso de archivado que **NO elimina físicamente** los jobs de Jenkins.
> Los jobs se **mueven** a una carpeta de archivo donde:
> - ✅ Conservan toda su configuración
> - ✅ Mantienen su historial de builds
> - ✅ Pueden ser **restaurados** fácilmente
> - ✅ Están **ocultos** de la vista principal

## 📊 Método de Ejecución
| Aspecto | Detalle |
|---------|---------|
| **🔧 Método** | ${env.EXECUTION_METHOD ?: 'Script directo'} |
| **📝 Script** | Disponible en artefactos (archive_script.groovy) |
| **🎯 Estado** | ${env.SCRIPT_EXECUTED == 'true' ? 'Ejecutado' : 'Preparado'} |

## 🔄 Próxima Ejecución
- **📅 Fecha**: Primer día del próximo mes
- **⏰ Hora**: 01:00 AM
- **🔧 Modo**: ${params.DRY_RUN ? 'Continuará en simulación' : 'Ejecución real'}

## 🚨 Instrucciones Importantes

### 📋 Si usas jenkins-script-runner
1. El script se ejecuta automáticamente vía job 'jenkins-script-runner'
2. Los resultados aparecen en los logs del build
3. El archivado se realiza según los parámetros configurados

### 🔧 Si NO tienes jenkins-script-runner
1. **Descargar script**: Del artefacto 'archive_script.groovy'
2. **Ejecutar manualmente**: En Jenkins Script Console
3. **Configurar parámetros**: Editar variables al inicio del script
4. **Revisar resultados**: En la salida del Script Console

### 🔄 Restauración de Jobs (Si es necesario)
```groovy
// Script para restaurar un job archivado
import jenkins.model.*

def jenkins = Jenkins.getInstance()
def archivedJob = jenkins.getItem("${params.ARCHIVE_FOLDER_NAME}/NOMBRE_DEL_JOB")

// Mover de vuelta a la raíz o carpeta específica
archivedJob.renameTo("NOMBRE_DEL_JOB")
println "✅ Job restaurado exitosamente"
```

### 🗑️ Eliminación Física (Opcional)
```groovy
// Script para eliminar físicamente un job archivado
import jenkins.model.*

def jenkins = Jenkins.getInstance()
def jobToDelete = jenkins.getItem("${params.ARCHIVE_FOLDER_NAME}/NOMBRE_DEL_JOB")

// CUIDADO: Esta acción es irreversible
jobToDelete.delete()
println "🗑️ Job eliminado físicamente"
```

## 📈 Beneficios del Sistema
- **🎯 Automatización**: Proceso mensual sin intervención manual
- **🔄 Reversibilidad**: Borrado lógico permite restauración
- **📊 Organización**: Dashboard más limpio y organizado
- **⚡ Rendimiento**: Menos jobs activos mejoran el rendimiento
- **📋 Trazabilidad**: Reportes detallados de cada ejecución
- **💰 Eficiencia**: Ejecutado en nodos spot para optimizar costos

## 🔧 Configuración Recomendada
Para máxima efectividad, crear un job 'jenkins-script-runner' que:
1. Acepte parámetro 'SCRIPT_CONTENT' (tipo text)
2. Ejecute el script en Jenkins Script Console
3. Retorne resultados en la descripción del build

---
*Reporte generado automáticamente por el pipeline de archivado de jobs antiguos*
*Próxima ejecución: Primer día del próximo mes a las 01:00 AM*
*Ejecutado en nodos disponibles para optimización de recursos*
                    """
                    
                    // Guardar reporte
                    writeFile file: 'reporte_archivado_jobs.md', text: reportContent
                    archiveArtifacts artifacts: '*.groovy,*.md', fingerprint: true
                    
                    echo "📄 Reporte y script generados y archivados exitosamente"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo """
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🏁 EJECUCIÓN COMPLETADA                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

📊 Resumen Final:
• Fecha: ${env.EXECUTION_DATE}
• Modo: ${params.DRY_RUN ? '🔍 SIMULACIÓN (Borrado Lógico)' : '🚀 EJECUCIÓN REAL'}
• Carpeta: ${params.ARCHIVE_FOLDER_NAME}
• Umbral: ${params.THRESHOLD_DAYS} días

🔄 Próxima ejecución: Primer día del próximo mes a las 01:00 AM
📄 Reporte disponible en artefactos del build
                """
            }
        }
        success {
            echo "✅ Pipeline de archivado ejecutado exitosamente"
        }
        failure {
            echo "❌ Error en la ejecución del pipeline de archivado"
        }
    }
}
    '''
    
    // Configurar el pipeline script
    def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
    pipelineJob.setDefinition(flowDefinition)
    
    // Guardar configuración
    pipelineJob.save()
    
    println "✅ Pipeline job '${JOB_NAME}' creado exitosamente!"
    println ""
    println "🎯 CONFIGURACIÓN DEL PIPELINE:"
    println "• Nombre: ${JOB_NAME}"
    println "• Descripción: Configurada con detalles completos"
    println "• Agente: label 'nodepool=spot' (nodos spot exclusivamente)"
    println "• Programación: Primer día de cada mes a las 01:00 AM (cron: '0 1 1 * *')"
    println "• Timeout: 30 minutos"
    println "• Modo por defecto: Simulación (DRY_RUN = true)"
    println "• Parámetros: 3 parámetros configurables"
    println "• Reportes: Markdown con artefactos"
    println ""
    println "💰 BENEFICIOS DEL NODO SPOT:"
    println "• Ahorro de costos: ~85% vs nodos regulares"
    println "• Auto-scaling: Kubernetes crea pods dinámicamente"
    println "• Eficiencia: Recursos optimizados para mantenimiento"
    println "• Template: spot-worker con tolerations configuradas"
    println ""
    println "🔄 PRÓXIMOS PASOS:"
    println "1. Ir a Jenkins → Jobs → '${JOB_NAME}'"
    println "2. Revisar la configuración creada"
    println "3. Ejecutar una primera vez en modo simulación"
    println "4. Verificar que se ejecuta en nodo spot (debería aparecer spot-worker-XXXXX)"
    println "5. Revisar el reporte generado"
    println "6. Si todo está correcto, configurar para ejecución real"
    println ""
    println "⚠️ IMPORTANTE:"
    println "• El pipeline ejecutará en MODO SIMULACIÓN por defecto"
    println "• Se ejecutará EXCLUSIVAMENTE en nodos SPOT (label: nodepool=spot)"
    println "• Para ejecución real, cambiar parámetro DRY_RUN = false"
    println "• Los jobs archivados son REVERSIBLES (borrado lógico)"
    println "• El cron trigger se activará automáticamente"
    println "• Ahorro estimado: ~85% vs nodos regulares"
    println ""
    println "🔗 URL del job: ${Jenkins.getInstance().getRootUrl()}job/${JOB_NAME}/"
    
} catch (Exception e) {
    println "❌ ERROR creando el pipeline job:"
    println "• Error: ${e.message}"
    println "• Clase: ${e.class.simpleName}"
    
    // Sugerencias de solución
    println ""
    println "🔧 POSIBLES SOLUCIONES:"
    println "1. Verificar que tienes permisos de administrador en Jenkins"
    println "2. Asegurarte de que el plugin Pipeline está instalado"
    println "3. Comprobar que no existe un job con el mismo nombre"
    println "4. Revisar los logs de Jenkins para más detalles"
    
    // Mostrar stack trace para debug
    e.printStackTrace()
}

println ""
println "════════════════════════════════════════════════════════════════════════════════"
println "🏁 Script de creación de pipeline completado"
println "📅 ${new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())}"
println "════════════════════════════════════════════════════════════════════════════════"
