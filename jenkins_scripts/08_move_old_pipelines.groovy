/*
 * SCRIPT DE BORRADO LÓGICO DE JOBS ANTIGUOS - VERSIÓN SCRIPT CONSOLE
 * ================================================================
 * 
 * Este script está diseñado para ejecutarse en el Script Console de Jenkins.
 * Mueve jobs sin uso por más de 1 año a una carpeta de archivo (borrado lógico).
 * 
 * IMPORTANTE: 
 * - NO elimina físicamente los jobs
 * - Los mueve a una carpeta de archivo donde pueden ser restaurados
 * - Es un proceso REVERSIBLE
 * 
 * Autor: Sistema de mantenimiento automático Jenkins
 * Fecha: 2025-09-17
 */

import jenkins.model.*
import hudson.model.*
import com.cloudbees.hudson.plugins.folder.*
import java.text.SimpleDateFormat
import java.util.Date

// =====================================================================
// CONFIGURACIÓN - MODIFICA ESTOS VALORES SEGÚN TUS NECESIDADES
// =====================================================================

def ARCHIVE_FOLDER_NAME = "ARCHIVADOS_SIN_USO_1_AÑO_PLUS"  // Nombre de la carpeta de archivo
def DAYS_THRESHOLD = 365                                    // Días sin uso (365 = 1 año)
def DRY_RUN = true                                         // true = Simulación, false = Ejecución real

println """
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🗂️ BORRADO LÓGICO DE JOBS ANTIGUOS                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

🔧 Modo: ${DRY_RUN ? '🔍 SIMULACIÓN (Borrado Lógico)' : '🚀 EJECUCIÓN REAL'}
⏰ Umbral: ${DAYS_THRESHOLD} días sin uso
📁 Carpeta: ${ARCHIVE_FOLDER_NAME}
📅 Fecha: ${new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())}

🎯 ¿Qué es el Borrado Lógico?
   Los jobs NO se eliminan, se MUEVEN a una carpeta de archivo donde:
   ✅ Conservan toda su configuración
   ✅ Mantienen su historial de builds
   ✅ Pueden ser restaurados fácilmente
   ✅ Están organizados fuera de la vista principal

════════════════════════════════════════════════════════════════════════════════
"""

def jenkins = Jenkins.getInstance()
def allJobs = jenkins.getAllItems(Job.class)

// Configurar períodos de tiempo
def now = System.currentTimeMillis()
def oneDay = 24 * 60 * 60 * 1000L
def thresholdTime = DAYS_THRESHOLD * oneDay

// Contadores y listas
def totalJobsAnalyzed = 0
def candidatesFound = 0
def jobsMoved = 0
def jobsSkipped = 0
def errors = []
def candidatesForArchive = []

println "📋 Analizando ${allJobs.size()} jobs en total..."

// Crear o verificar carpeta de archivo
def archiveFolder = jenkins.getItem(ARCHIVE_FOLDER_NAME)
if (!archiveFolder) {
    if (!DRY_RUN) {
        try {
            archiveFolder = jenkins.createProject(Folder.class, ARCHIVE_FOLDER_NAME)
            archiveFolder.setDescription("""
📁 CARPETA DE ARCHIVO - BORRADO LÓGICO DE JOBS ANTIGUOS

⚠️ IMPORTANTE: Los jobs en esta carpeta no se han ejecutado en más de ${DAYS_THRESHOLD} días.
📅 Fecha de creación: ${new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())}

🎯 PROPÓSITO:
• BORRADO LÓGICO: Jobs movidos aquí NO están eliminados físicamente
• Mantener organización separando jobs activos de inactivos
• Permitir revisión y restauración si es necesario
• Facilitar limpieza progresiva del Jenkins

🔄 PROCESO DE ARCHIVADO:
• Criterio: Jobs sin uso por más de ${DAYS_THRESHOLD} días
• Tipo: Borrado lógico (movimiento, no eliminación)

🚨 ACCIONES DISPONIBLES:
• ✅ RESTAURAR: Mover job de vuelta a su ubicación original
• 🗑️ ELIMINAR: Borrado físico definitivo (opcional)
• 📊 REVISAR: Evaluar utilidad del job archivado

📊 ESTADÍSTICAS:
• Borrado lógico reversible
• Conservación de historial y configuración
            """.trim())
            println "✅ Carpeta '${ARCHIVE_FOLDER_NAME}' creada exitosamente"
        } catch (Exception e) {
            println "❌ Error creando carpeta de archivo: ${e.message}"
            return
        }
    } else {
        println "🔍 [SIMULACIÓN] Se crearía la carpeta '${ARCHIVE_FOLDER_NAME}'"
    }
} else {
    println "📁 Carpeta de archivo '${ARCHIVE_FOLDER_NAME}' ya existe"
}

println ""
println "🔍 ANALIZANDO JOBS..."
println "=" * 80

// Analizar cada job
allJobs.each { job ->
    totalJobsAnalyzed++
    
    // Saltar si el job ya está en la carpeta de archivo
    def parent = job.getParent()
    if (parent && parent.getFullName() == ARCHIVE_FOLDER_NAME) {
        return // continue en Groovy
    }
    
    def jobInfo = [:]
    jobInfo.name = job.getFullName()
    jobInfo.displayName = job.getDisplayName()
    jobInfo.enabled = job.isBuildable()
    jobInfo.jobType = job.getClass().getSimpleName()
    jobInfo.folder = parent && parent.getClass().getSimpleName() != "Jenkins" ? parent.getFullName() : "Raíz"
    
    // Obtener información del último build
    def lastBuild = job.getLastBuild()
    jobInfo.lastBuildTime = lastBuild?.getTimeInMillis() ?: 0
    jobInfo.totalBuilds = job.getBuilds().size()
    
    if (jobInfo.lastBuildTime > 0) {
        jobInfo.daysSinceLastBuild = Math.floor((now - jobInfo.lastBuildTime) / oneDay)
        jobInfo.lastBuildDate = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date(jobInfo.lastBuildTime))
    } else {
        jobInfo.daysSinceLastBuild = -1
        jobInfo.lastBuildDate = "Nunca construido"
    }
    
    // Verificar si es candidato para archivo (borrado lógico)
    def isCandidate = false
    def reason = ""
    
    if (jobInfo.lastBuildTime == 0) {
        isCandidate = true
        reason = "Nunca construido"
    } else {
        def timeSinceLastBuild = now - jobInfo.lastBuildTime
        if (timeSinceLastBuild >= thresholdTime) {
            isCandidate = true
            reason = "Sin uso por ${jobInfo.daysSinceLastBuild} días"
        }
    }
    
    if (isCandidate) {
        jobInfo.reason = reason
        candidatesForArchive.add(jobInfo)
        candidatesFound++
    }
}

println ""
println "📊 RESULTADOS DEL ANÁLISIS:"
println "• Total de jobs analizados: ${totalJobsAnalyzed}"
println "• Candidatos para borrado lógico: ${candidatesFound}"
println ""

if (candidatesFound == 0) {
    println "✅ No se encontraron jobs candidatos para archivo"
    println ""
    println "🏁 PROCESO COMPLETADO - SIN ACCIONES NECESARIAS"
    return
}

// Mostrar candidatos
println "🎯 CANDIDATOS PARA BORRADO LÓGICO:"
println "=" * 80
candidatesForArchive.sort { -it.daysSinceLastBuild }.eachWithIndex { job, index ->
    if (index < 10) { // Mostrar solo los primeros 10 para no saturar la salida
        println "• ${job.name}"
        println "  └─ Razón: ${job.reason}"
        println "  └─ Carpeta actual: ${job.folder}"
        println "  └─ Último build: ${job.lastBuildDate}"
        println "  └─ Total builds: ${job.totalBuilds}"
        println ""
    }
}

if (candidatesFound > 10) {
    println "... y ${candidatesFound - 10} jobs más"
    println ""
}

// Proceder con el movimiento (borrado lógico)
println "🚀 INICIANDO PROCESO DE BORRADO LÓGICO..."
println ""

candidatesForArchive.each { jobInfo ->
    try {
        def job = jenkins.getItem(jobInfo.name)
        if (!job) {
            println "⚠️ Job no encontrado: ${jobInfo.name}"
            jobsSkipped++
            return
        }
        
        // Verificar que el job no esté siendo ejecutado
        if (job.isBuilding()) {
            println "⚠️ Job en ejecución, saltando: ${jobInfo.name}"
            jobsSkipped++
            return
        }
        
        if (DRY_RUN) {
            println "🔍 [SIMULACIÓN] Se movería (borrado lógico): ${jobInfo.name} → ${ARCHIVE_FOLDER_NAME}/"
            jobsMoved++
        } else {
            // Realizar el borrado lógico (movimiento)
            def newName = job.getName()
            
            // Verificar si ya existe un job con el mismo nombre en la carpeta de archivo
            def existingJob = archiveFolder.getItem(newName)
            if (existingJob) {
                def timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date())
                newName = "${job.getName()}_archived_${timestamp}"
                println "⚠️ Job con mismo nombre existe, renombrando a: ${newName}"
            }
            
            // Realizar el borrado lógico
            job.renameTo("${ARCHIVE_FOLDER_NAME}/${newName}")
            println "✅ Borrado lógico realizado: ${jobInfo.name} → ${ARCHIVE_FOLDER_NAME}/${newName}"
            jobsMoved++
        }
        
    } catch (Exception e) {
        def errorMsg = "Error en borrado lógico de ${jobInfo.name}: ${e.message}"
        println "❌ ${errorMsg}"
        errors.add(errorMsg)
    }
}

println ""
println "╔══════════════════════════════════════════════════════════════════════════════╗"
println "║                           🏁 BORRADO LÓGICO COMPLETADO                      ║"
println "╚══════════════════════════════════════════════════════════════════════════════╝"
println ""
println "📊 RESUMEN FINAL:"
println "• Jobs analizados: ${totalJobsAnalyzed}"
println "• Candidatos encontrados: ${candidatesFound}"
println "• Jobs procesados: ${jobsMoved}"
println "• Jobs saltados: ${jobsSkipped}"
println "• Errores: ${errors.size()}"
println ""

if (DRY_RUN) {
    println "🔍 MODO SIMULACIÓN COMPLETADO"
    println "• Para ejecutar realmente, cambia DRY_RUN = false"
    println "• Los jobs NO han sido movidos (solo simulación)"
} else {
    println "🚀 EJECUCIÓN REAL COMPLETADA"
    println "• Los jobs han sido movidos a la carpeta: ${ARCHIVE_FOLDER_NAME}"
    println "• Tipo de proceso: BORRADO LÓGICO (reversible)"
}

println ""
println "🔄 PRÓXIMOS PASOS RECOMENDADOS:"
println "1. Revisar jobs en la carpeta: ${ARCHIVE_FOLDER_NAME}"
println "2. Identificar jobs que realmente no se necesiten"
println "3. Restaurar jobs necesarios si es requerido"
println "4. Documentar decisiones tomadas"

if (errors.size() > 0) {
    println ""
    println "❌ ERRORES ENCONTRADOS:"
    errors.each { error ->
        println "• ${error}"
    }
}

println ""
println "✅ Proceso completado exitosamente"
println "📅 Fecha de finalización: ${new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())}"

// Retornar resumen para uso programático si es necesario
return [
    totalAnalyzed: totalJobsAnalyzed,
    candidates: candidatesFound,
    moved: jobsMoved,
    skipped: jobsSkipped,
    errors: errors.size(),
    mode: DRY_RUN ? "simulacion" : "real",
    archiveFolder: ARCHIVE_FOLDER_NAME,
    threshold: DAYS_THRESHOLD
]
