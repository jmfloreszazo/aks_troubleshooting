// SCRIPT: Análisis de Pipelines Antiguos sin Uso
// =============================================
// Ejecutar en Jenkins Script Console para identificar pipelines no utilizados

import jenkins.model.*
import hudson.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import java.text.SimpleDateFormat
import java.util.concurrent.TimeUnit

println """
🔍 ANALIZANDO PIPELINES ANTIGUOS SIN USO
======================================
Identificando pipelines que no se han ejecutado en el último año...
"""

def jenkins = Jenkins.getInstance()
def allJobs = jenkins.getAllItems(Job.class)

// Configurar períodos de tiempo (en milisegundos)
def now = System.currentTimeMillis()
def oneHour = 60 * 60 * 1000L
def oneDay = 24 * oneHour
def oneWeek = 7 * oneDay
def oneMonth = 30 * oneDay
def oneYear = 365 * oneDay

// Categorías de análisis
def unusedForOneYear = []
def unusedForSixMonths = []
def unusedForThreeMonths = []
def unusedForOneMonth = []
def unusedForOneWeek = []
def recentlyUsed = []
def neverBuilt = []

// Información general
def totalJobs = 0
def workflowJobs = 0
def otherJobs = 0

println "📋 Analizando ${allJobs.size()} jobs en total..."

allJobs.each { job ->
    totalJobs++
    
    def jobInfo = [:]
    jobInfo.name = job.getFullName()
    jobInfo.displayName = job.getDisplayName()
    jobInfo.enabled = job.isBuildable()
    jobInfo.jobType = job.getClass().getSimpleName()
    jobInfo.url = jenkins.getRootUrl() + job.getUrl()
    
    // Verificar si es un WorkflowJob (Pipeline)
    def isPipeline = job instanceof WorkflowJob
    if (isPipeline) {
        workflowJobs++
    } else {
        otherJobs++
    }
    jobInfo.isPipeline = isPipeline
    
    // Obtener información de builds
    def builds = job.getBuilds()
    def lastBuild = job.getLastBuild()
    def lastSuccessfulBuild = job.getLastSuccessfulBuild()
    def lastFailedBuild = job.getLastFailedBuild()
    
    jobInfo.totalBuilds = builds.size()
    jobInfo.lastBuildNumber = lastBuild?.getNumber() ?: 0
    jobInfo.lastBuildTime = lastBuild?.getTimeInMillis() ?: 0
    jobInfo.lastBuildResult = lastBuild?.getResult()?.toString() ?: "NEVER_BUILT"
    jobInfo.lastBuildDuration = lastBuild?.getDuration() ?: 0
    
    // Formatear fechas
    def dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
    if (jobInfo.lastBuildTime > 0) {
        jobInfo.lastBuildDate = dateFormat.format(new Date(jobInfo.lastBuildTime))
        jobInfo.daysSinceLastBuild = Math.floor((now - jobInfo.lastBuildTime) / oneDay)
    } else {
        jobInfo.lastBuildDate = "Nunca construido"
        jobInfo.daysSinceLastBuild = -1
    }
    
    // Información adicional
    jobInfo.lastSuccessfulBuildNumber = lastSuccessfulBuild?.getNumber() ?: 0
    jobInfo.lastSuccessfulBuildTime = lastSuccessfulBuild?.getTimeInMillis() ?: 0
    if (jobInfo.lastSuccessfulBuildTime > 0) {
        jobInfo.lastSuccessfulBuildDate = dateFormat.format(new Date(jobInfo.lastSuccessfulBuildTime))
        jobInfo.daysSinceLastSuccess = Math.floor((now - jobInfo.lastSuccessfulBuildTime) / oneDay)
    } else {
        jobInfo.lastSuccessfulBuildDate = "Nunca exitoso"
        jobInfo.daysSinceLastSuccess = -1
    }
    
    // Obtener descripción del job
    jobInfo.description = job.getDescription() ?: "Sin descripción"
    
    // Obtener información de la carpeta padre
    def parent = job.getParent()
    if (parent && parent.getClass().getSimpleName() != "Jenkins") {
        jobInfo.folder = parent.getFullName()
    } else {
        jobInfo.folder = "Raíz"
    }
    
    // Categorizar según el tiempo sin uso
    if (jobInfo.lastBuildTime == 0) {
        neverBuilt.add(jobInfo)
    } else {
        def timeSinceLastBuild = now - jobInfo.lastBuildTime
        
        if (timeSinceLastBuild >= oneYear) {
            unusedForOneYear.add(jobInfo)
        } else if (timeSinceLastBuild >= (6 * oneMonth)) {
            unusedForSixMonths.add(jobInfo)
        } else if (timeSinceLastBuild >= (3 * oneMonth)) {
            unusedForThreeMonths.add(jobInfo)
        } else if (timeSinceLastBuild >= oneMonth) {
            unusedForOneMonth.add(jobInfo)
        } else if (timeSinceLastBuild >= oneWeek) {
            unusedForOneWeek.add(jobInfo)
        } else {
            recentlyUsed.add(jobInfo)
        }
    }
}

// Ordenar listas por tiempo sin uso (más antiguos primero)
unusedForOneYear.sort { -it.daysSinceLastBuild }
unusedForSixMonths.sort { -it.daysSinceLastBuild }
unusedForThreeMonths.sort { -it.daysSinceLastBuild }
unusedForOneMonth.sort { -it.daysSinceLastBuild }
unusedForOneWeek.sort { -it.daysSinceLastBuild }
neverBuilt.sort { it.name }

// Generar informe en Markdown
def dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
def currentDate = dateFormat.format(new Date())

// Obtener información del Jenkins
def jenkinsInfo = [:]
jenkinsInfo.version = jenkins.getVersion()
jenkinsInfo.instanceUrl = jenkins.getRootUrl() ?: "URL no configurada"

try {
    def hostname = java.net.InetAddress.getLocalHost().getHostName()
    jenkinsInfo.hostname = hostname
} catch (Exception e) {
    jenkinsInfo.hostname = "No disponible"
}

def markdownReport = """
# 📊 Análisis de Pipelines Antiguos sin Uso

## 🏢 Información de la Instancia Jenkins
| Campo | Valor |
|-------|-------|
| **🆔 URL de la Instancia** | `${jenkinsInfo.instanceUrl}` |
| **📍 Hostname** | `${jenkinsInfo.hostname}` |
| **🔢 Versión de Jenkins** | `${jenkinsInfo.version}` |
| **📅 Fecha de Análisis** | `${currentDate}` |

## 📈 Resumen General

| Categoría | Cantidad | Porcentaje |
|-----------|----------|------------|
| **📦 Total de Jobs** | ${totalJobs} | 100% |
| **🔄 Pipelines (WorkflowJob)** | ${workflowJobs} | ${Math.round((workflowJobs / totalJobs) * 100)}% |
| **🏗️ Otros tipos de Jobs** | ${otherJobs} | ${Math.round((otherJobs / totalJobs) * 100)}% |

## ⏰ Análisis por Tiempo sin Uso

| Período | Cantidad | Porcentaje |
|---------|----------|------------|
| **🔴 Sin uso por MÁS DE 1 AÑO** | ${unusedForOneYear.size()} | ${Math.round((unusedForOneYear.size() / totalJobs) * 100)}% |
| **🟠 Sin uso por 6+ meses** | ${unusedForSixMonths.size()} | ${Math.round((unusedForSixMonths.size() / totalJobs) * 100)}% |
| **🟡 Sin uso por 3+ meses** | ${unusedForThreeMonths.size()} | ${Math.round((unusedForThreeMonths.size() / totalJobs) * 100)}% |
| **🔵 Sin uso por 1+ mes** | ${unusedForOneMonth.size()} | ${Math.round((unusedForOneMonth.size() / totalJobs) * 100)}% |
| **🟢 Sin uso por 1+ semana** | ${unusedForOneWeek.size()} | ${Math.round((unusedForOneWeek.size() / totalJobs) * 100)}% |
| **✅ Usados recientemente** | ${recentlyUsed.size()} | ${Math.round((recentlyUsed.size() / totalJobs) * 100)}% |
| **❓ Nunca construidos** | ${neverBuilt.size()} | ${Math.round((neverBuilt.size() / totalJobs) * 100)}% |

---

## 🔴 CANDIDATOS PARA ARCHIVO: Jobs sin uso por MÁS DE 1 AÑO (${unusedForOneYear.size()})

> ⚠️ **RECOMENDACIÓN**: Estos jobs son candidatos ideales para mover a una carpeta de "Sin Uso" o archivar

| Job | Tipo | Carpeta | Último Build | Días sin Uso | Estado | Total Builds | URL |
|-----|------|---------|--------------|-------------|--------|--------------|-----|
"""

unusedForOneYear.each { job ->
    def estado = job.enabled ? "✅ Habilitado" : "❌ Deshabilitado"
    def tipo = job.isPipeline ? "🔄 Pipeline" : "🏗️ ${job.jobType}"
    markdownReport += "| `${job.name}` | ${tipo} | `${job.folder}` | ${job.lastBuildDate} | **${job.daysSinceLastBuild}** | ${estado} | ${job.totalBuilds} | [Ver](${job.url}) |\n"
}

markdownReport += """

### 📋 Script para Mover Jobs Antiguos a Carpeta de Archivo

```groovy
// Script para mover jobs sin uso de más de 1 año a carpeta "Jobs_Archivados"
import jenkins.model.*
import com.cloudbees.hudson.plugins.folder.*

def jenkins = Jenkins.getInstance()
def archiveFolder = jenkins.getItem("Jobs_Archivados")

// Crear carpeta de archivo si no existe
if (!archiveFolder) {
    archiveFolder = jenkins.createProject(Folder.class, "Jobs_Archivados")
    archiveFolder.setDescription("Carpeta para jobs archivados sin uso por más de 1 año")
    println "✅ Carpeta 'Jobs_Archivados' creada"
}

// Lista de jobs a mover (más de 1 año sin uso)
def jobsToMove = [
"""

unusedForOneYear.each { job ->
    markdownReport += "    \"${job.name}\",\n"
}

// Ahora construir el resto del script como texto plano
def scriptContent = """]

// Mover jobs a la carpeta de archivo
jobsToMove.each { jobName ->
    def job = jenkins.getItem(jobName)
    if (job && job.getParent().getFullName() != "Jobs_Archivados") {
        try {
            jenkins.getItem(jobName).renameTo("Jobs_Archivados/" + jobName)
            println "✅ Movido: " + jobName + " → Jobs_Archivados/"
        } catch (Exception e) {
            println "❌ Error moviendo " + jobName + ": " + e.message
        }
    }
}

println "🎯 Proceso de archivo completado"
```"""

markdownReport += scriptContent

markdownReport += """

---

## 🟠 Jobs sin uso por 6+ meses (${unusedForSixMonths.size()})

> ⚠️ **ATENCIÓN**: Candidatos para revisión y posible archivo

| Job | Tipo | Carpeta | Último Build | Días sin Uso | Estado | Último Resultado |
|-----|------|---------|--------------|-------------|--------|------------------|
"""

unusedForSixMonths.each { job ->
    def estado = job.enabled ? "✅ Habilitado" : "❌ Deshabilitado"
    def tipo = job.isPipeline ? "🔄 Pipeline" : "🏗️ ${job.jobType}"
    def resultado = job.lastBuildResult == "SUCCESS" ? "✅" : (job.lastBuildResult == "FAILURE" ? "❌" : "⚠️")
    markdownReport += "| `${job.name}` | ${tipo} | `${job.folder}` | ${job.lastBuildDate} | **${job.daysSinceLastBuild}** | ${estado} | ${resultado} ${job.lastBuildResult} |\n"
}

markdownReport += """

---

## 🟡 Jobs sin uso por 3+ meses (${unusedForThreeMonths.size()})

> 📋 **REVISIÓN**: Evaluar si siguen siendo necesarios

| Job | Tipo | Carpeta | Último Build | Días sin Uso | Estado |
|-----|------|---------|--------------|-------------|--------|
"""

unusedForThreeMonths.each { job ->
    def estado = job.enabled ? "✅ Habilitado" : "❌ Deshabilitado"
    def tipo = job.isPipeline ? "🔄 Pipeline" : "🏗️ ${job.jobType}"
    markdownReport += "| `${job.name}` | ${tipo} | `${job.folder}` | ${job.lastBuildDate} | ${job.daysSinceLastBuild} | ${estado} |\n"
}

markdownReport += """

---

## ❓ Jobs Nunca Construidos (${neverBuilt.size()})

> 🗑️ **CANDIDATOS PARA ELIMINACIÓN**: Jobs creados pero nunca ejecutados

| Job | Tipo | Carpeta | Estado | Descripción |
|-----|------|---------|--------|-------------|
"""

neverBuilt.each { job ->
    def estado = job.enabled ? "✅ Habilitado" : "❌ Deshabilitado"
    def tipo = job.isPipeline ? "🔄 Pipeline" : "🏗️ ${job.jobType}"
    def descripcion = job.description.take(80) + (job.description.length() > 80 ? "..." : "")
    markdownReport += "| `${job.name}` | ${tipo} | `${job.folder}` | ${estado} | ${descripcion} |\n"
}

markdownReport += """

---

## 📊 Estadísticas por Carpeta

### Jobs Antiguos (>1 año) por Carpeta
"""

// Agrupar jobs antiguos por carpeta
def jobsByFolder = [:]
unusedForOneYear.each { job ->
    def folder = job.folder
    if (!jobsByFolder.containsKey(folder)) {
        jobsByFolder[folder] = []
    }
    jobsByFolder[folder].add(job)
}

markdownReport += """
| Carpeta | Cantidad | Jobs |
|---------|----------|------|
"""

jobsByFolder.sort { -it.value.size() }.each { folder, jobs ->
    def jobNames = jobs.collect { it.name }.join(", ")
    markdownReport += "| `${folder}` | **${jobs.size()}** | ${jobNames.take(100)}${jobNames.length() > 100 ? "..." : ""} |\n"
}

markdownReport += """

---

## 📋 Recomendaciones de Acción

### 🎯 Acciones Inmediatas
1. **Archivar jobs de +1 año**: ${unusedForOneYear.size()} candidatos identificados
2. **Revisar jobs de 6+ meses**: ${unusedForSixMonths.size()} jobs necesitan evaluación
3. **Eliminar jobs nunca construidos**: ${neverBuilt.size()} jobs candidatos para eliminación

### 🛠️ Proceso Recomendado
1. **Backup**: Hacer backup de la configuración antes de mover/eliminar
2. **Notificación**: Informar a los equipos sobre jobs que serán archivados
3. **Período de gracia**: Esperar 30 días antes de eliminación definitiva
4. **Documentación**: Mantener registro de jobs archivados

### 📈 Impacto Estimado
- **Reducción de jobs activos**: ${unusedForOneYear.size() + neverBuilt.size()} jobs
- **Mejora en rendimiento**: Menos jobs para procesar en Jenkins
- **Mejor organización**: Vista más limpia del dashboard

---

*Informe generado automáticamente por el script de análisis de pipelines antiguos*
"""

// Guardar el informe
def hostname = jenkinsInfo.hostname.replaceAll(/[^a-zA-Z0-9\-_]/, '_')
def version = jenkinsInfo.version.toString().replaceAll(/[^a-zA-Z0-9\-_\.]/, '_')
def timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date())
def reportFileName = "old-pipelines-analysis-${hostname}-v${version}-${timestamp}.md"
def reportFile = new File(jenkins.getRootDir(), reportFileName)
reportFile.text = markdownReport

println """
✅ ANÁLISIS DE PIPELINES ANTIGUOS COMPLETADO
===========================================

📊 Resumen de Resultados:
• Total de jobs analizados: ${totalJobs}
• Jobs sin uso por +1 año: ${unusedForOneYear.size()}
• Jobs sin uso por 6+ meses: ${unusedForSixMonths.size()}
• Jobs sin uso por 3+ meses: ${unusedForThreeMonths.size()}
• Jobs nunca construidos: ${neverBuilt.size()}

🎯 CANDIDATOS PARA ARCHIVO (>1 año):"""

unusedForOneYear.take(10).each { job ->
    println "   • ${job.name} (${job.daysSinceLastBuild} días sin uso)"
}

if (unusedForOneYear.size() > 10) {
    println "   ... y ${unusedForOneYear.size() - 10} más"
}

println """
📄 Informe completo guardado en: ${reportFile.absolutePath}

🚀 PRÓXIMOS PASOS:
1. Revisar la lista de candidatos para archivo
2. Notificar a los equipos responsables
3. Ejecutar el script de movimiento a carpeta de archivo
4. Considerar eliminación de jobs nunca construidos

📋 INFORME MARKDOWN:
"""
println "=" * 60
println markdownReport
println "=" * 60

return "Análisis completado. ${unusedForOneYear.size()} jobs candidatos para archivo identificados."
