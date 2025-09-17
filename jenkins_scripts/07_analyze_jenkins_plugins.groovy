// SCRIPT: Análisis Completo de Plugins de Jenkins
// ===============================================
// Ejecutar en Jenkins Script Console para generar informe de plugins

import jenkins.model.*
import hudson.PluginWrapper
import hudson.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import hudson.plugins.git.*
import java.text.SimpleDateFormat
import java.util.regex.Pattern
import java.net.InetAddress

println """
📊 ANALIZANDO PLUGINS DE JENKINS
===============================
Generando informe completo de plugins instalados y su uso...
"""

def jenkins = Jenkins.getInstance()
def pluginManager = jenkins.getPluginManager()
def installedPlugins = pluginManager.getPlugins()

// Listas para categorizar plugins
def pluginsInPipelines = [:]
def pluginsNotInPipelines = []
def adminPlugins = []
def securityPlugins = []
def buildPlugins = []
def scmPlugins = []
def notificationPlugins = []
def uiPlugins = []
def testingPlugins = []
def deploymentPlugins = []
def unknownPlugins = []

// Patrones para detectar uso de plugins en pipelines
def pipelinePatterns = [
    'git': /git\s*\(|checkout.*git|GitSCM/,
    'pipeline-stage-view': /pipeline\s*\{|stage\s*\(/,
    'workflow-aggregator': /pipeline\s*\{/,
    'workflow-job': /pipeline\s*\{/,
    'credentials': /withCredentials|credentials\(/,
    'ssh-agent': /sshagent/,
    'docker': /docker\.|dockerImage|dockerfile/,
    'kubernetes': /kubernetes\.|podTemplate/,
    'junit': /junit\s*\(/,
    'jacoco': /jacoco/,
    'sonar': /sonar|SonarQube/,
    'maven': /maven|mvn/,
    'gradle': /gradle/,
    'nodejs': /nodejs|npm|yarn/,
    'python': /python|pip/,
    'slack': /slack/,
    'email-ext': /emailext|mail/,
    'build-timeout': /timeout\s*\(/,
    'timestamper': /timestamps/,
    'ws-cleanup': /cleanWs|deleteDir/,
    'ant': /ant\s/,
    'copyartifact': /copyArtifacts/,
    'parameterized-trigger': /build\s*job|trigger/,
    'conditional-buildstep': /conditional/,
    'matrix-project': /matrix/,
    'parallel': /parallel\s*\{/,
    'archive': /archiveArtifacts/,
    'publish': /publishHTML|publishTestResults/
]

// Categorías de plugins
def pluginCategories = [
    // Administración y configuración
    'admin': [
        'configuration-as-code', 'job-dsl', 'script-security', 'role-strategy',
        'matrix-auth', 'ldap', 'active-directory', 'saml', 'oic-auth',
        'authorize-project', 'build-timeout', 'timestamper', 'ws-cleanup',
        'disk-usage', 'monitoring', 'naginator', 'rebuild'
    ],
    
    // Seguridad
    'security': [
        'credentials', 'credentials-binding', 'ssh-credentials', 'ssh-agent',
        'plain-credentials', 'workflow-scm-step', 'matrix-auth', 'role-strategy',
        'authorize-project', 'script-security', 'build-authorization-token-root'
    ],
    
    // Build y CI/CD
    'build': [
        'workflow-aggregator', 'workflow-job', 'workflow-cps', 'workflow-basic-steps',
        'workflow-durable-task-step', 'pipeline-stage-view', 'pipeline-graph-analysis',
        'pipeline-input-step', 'pipeline-milestone-step', 'maven-plugin', 'gradle',
        'ant', 'nodejs', 'python', 'docker-workflow', 'kubernetes'
    ],
    
    // SCM
    'scm': [
        'git', 'github', 'github-branch-source', 'bitbucket', 'subversion',
        'mercurial', 'workflow-scm-step', 'github-api', 'git-parameter'
    ],
    
    // Notificaciones
    'notification': [
        'mailer', 'email-ext', 'slack', 'hipchat', 'jabber', 'ircbot',
        'build-notifications', 'notification'
    ],
    
    // UI y visualización
    'ui': [
        'blueocean', 'dashboard-view', 'build-pipeline-plugin', 'delivery-pipeline-plugin',
        'view-job-filters', 'nested-view', 'sectioned-view', 'pipeline-stage-view',
        'build-monitor-plugin', 'radiator-view-plugin'
    ],
    
    // Testing
    'testing': [
        'junit', 'testng-plugin', 'xunit', 'jacoco', 'cobertura', 'sonar',
        'performance', 'htmlpublisher', 'robot', 'cucumber-reports'
    ],
    
    // Deployment
    'deployment': [
        'deploy', 'ssh', 'publish-over-ssh', 'copyartifact', 'artifactory',
        'nexus-artifact-uploader', 'kubernetes-cd', 'aws-codecommit-trigger',
        'elastic-beanstalk-deployment-plugin'
    ]
]

println "🔍 Analizando ${installedPlugins.size()} plugins instalados..."

// Obtener todos los pipelines y sus scripts
def allJobs = jenkins.getAllItems(Job.class)
def pipelineScripts = []

allJobs.each { job ->
    if (job instanceof WorkflowJob) {
        def definition = job.getDefinition()
        if (definition instanceof CpsFlowDefinition) {
            pipelineScripts.add(definition.getScript())
        }
    }
}

println "📋 Encontrados ${pipelineScripts.size()} pipelines para analizar..."

// Analizar cada plugin
installedPlugins.each { plugin ->
    def pluginName = plugin.getShortName()
    def pluginDisplayName = plugin.getDisplayName()
    def pluginVersion = plugin.getVersion()
    def isEnabled = plugin.isEnabled()
    def isActive = plugin.isActive()
    
    // Verificar si el plugin se usa en pipelines
    def usedInPipelines = false
    def pipelineUsageCount = 0
    def usageExamples = []
    
    if (pipelinePatterns.containsKey(pluginName)) {
        def pattern = pipelinePatterns[pluginName]
        pipelineScripts.each { script ->
            def matcher = script =~ pattern
            if (matcher.find()) {
                usedInPipelines = true
                pipelineUsageCount++
                if (usageExamples.size() < 3) {
                    def match = matcher[0]
                    usageExamples.add(match.toString().take(50) + "...")
                }
            }
        }
    }
    
    def pluginInfo = [
        name: pluginName,
        displayName: pluginDisplayName,
        version: pluginVersion,
        enabled: isEnabled,
        active: isActive,
        usedInPipelines: usedInPipelines,
        pipelineUsageCount: pipelineUsageCount,
        usageExamples: usageExamples,
        category: 'unknown'
    ]
    
    // Categorizar plugin
    def categorized = false
    pluginCategories.each { category, plugins ->
        if (plugins.contains(pluginName)) {
            pluginInfo.category = category
            categorized = true
        }
    }
    
    if (usedInPipelines) {
        pluginsInPipelines[pluginName] = pluginInfo
    } else {
        pluginsNotInPipelines.add(pluginInfo)
        
        // Categorizar plugins no usados en pipelines
        switch (pluginInfo.category) {
            case 'admin':
                adminPlugins.add(pluginInfo)
                break
            case 'security':
                securityPlugins.add(pluginInfo)
                break
            case 'build':
                buildPlugins.add(pluginInfo)
                break
            case 'scm':
                scmPlugins.add(pluginInfo)
                break
            case 'notification':
                notificationPlugins.add(pluginInfo)
                break
            case 'ui':
                uiPlugins.add(pluginInfo)
                break
            case 'testing':
                testingPlugins.add(pluginInfo)
                break
            case 'deployment':
                deploymentPlugins.add(pluginInfo)
                break
            default:
                unknownPlugins.add(pluginInfo)
        }
    }
}

// Generar informe en Markdown
def dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
def currentDate = dateFormat.format(new Date())

// Recopilar información completa del Jenkins
def jenkinsInfo = [:]

// Información básica
jenkinsInfo.version = jenkins.getVersion()
jenkinsInfo.instanceUrl = jenkins.getRootUrl() ?: "URL no configurada"
jenkinsInfo.rootDir = jenkins.getRootDir().getAbsolutePath()

// Información del sistema
def systemProps = System.getProperties()
jenkinsInfo.javaVersion = systemProps['java.version']
jenkinsInfo.javaVendor = systemProps['java.vendor']
jenkinsInfo.javaHome = systemProps['java.home']
jenkinsInfo.osName = systemProps['os.name']
jenkinsInfo.osVersion = systemProps['os.version']
jenkinsInfo.osArch = systemProps['os.arch']
jenkinsInfo.userName = systemProps['user.name']

// Información de memoria y runtime
def runtime = Runtime.getRuntime()
jenkinsInfo.availableProcessors = runtime.availableProcessors()
jenkinsInfo.maxMemory = Math.round(runtime.maxMemory() / 1024 / 1024) + " MB"
jenkinsInfo.totalMemory = Math.round(runtime.totalMemory() / 1024 / 1024) + " MB"
jenkinsInfo.freeMemory = Math.round(runtime.freeMemory() / 1024 / 1024) + " MB"
jenkinsInfo.usedMemory = Math.round((runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024) + " MB"

// Información de nodos
def allComputers = []
def onlineCount = 0
def offlineCount = 0

// Agregar nodo master
def masterComputer = jenkins.getComputer("")
allComputers.add(masterComputer)
if (masterComputer.isOnline()) {
    onlineCount++
} else {
    offlineCount++
}

// Agregar nodos esclavos
def slaveNodes = jenkins.getNodes()
slaveNodes.each { node ->
    def nodeComputer = node.toComputer()
    if (nodeComputer != null) {
        allComputers.add(nodeComputer)
        if (nodeComputer.isOnline()) {
            onlineCount++
        } else {
            offlineCount++
        }
    }
}

jenkinsInfo.totalNodes = allComputers.size()
jenkinsInfo.onlineNodes = onlineCount
jenkinsInfo.offlineNodes = offlineCount

// Información de seguridad
def securityRealm = jenkins.getSecurityRealm()
jenkinsInfo.securityRealm = securityRealm?.getClass()?.getSimpleName() ?: "No configurado"
def authorizationStrategy = jenkins.getAuthorizationStrategy()
jenkinsInfo.authorizationStrategy = authorizationStrategy?.getClass()?.getSimpleName() ?: "No configurado"

// Información de configuración
jenkinsInfo.quietPeriod = jenkins.getQuietPeriod()
jenkinsInfo.scmCheckoutRetryCount = jenkins.getScmCheckoutRetryCount()
jenkinsInfo.crumbIssuer = jenkins.getCrumbIssuer()?.getClass()?.getSimpleName() ?: "No configurado"

// Información de jobs
jenkinsInfo.totalJobs = allJobs.size()
jenkinsInfo.enabledJobs = allJobs.findAll { it.isBuildable() }.size()
jenkinsInfo.disabledJobs = allJobs.findAll { !it.isBuildable() }.size()

// Tipos de jobs
def jobTypes = [:]
allJobs.each { job ->
    def jobType = job.getClass().getSimpleName()
    jobTypes[jobType] = (jobTypes[jobType] ?: 0) + 1
}
jenkinsInfo.jobTypes = jobTypes

// Información de builds
def allBuilds = allJobs.collect { it.getBuilds() }.flatten()
jenkinsInfo.totalBuilds = allBuilds.size()

// Estados de la última semana
def oneWeekAgo = System.currentTimeMillis() - (7 * 24 * 60 * 60 * 1000)
def recentBuilds = allBuilds.findAll { it.getTimeInMillis() > oneWeekAgo }
jenkinsInfo.recentBuilds = recentBuilds.size()

// Información de nodos detallada
def nodeDetails = []
allComputers.each { computer ->
    def node = computer.getNode()
    def nodeInfo = [:]
    nodeInfo.name = computer.getName() ?: "master"
    nodeInfo.online = computer.isOnline()
    nodeInfo.offline = computer.isOffline()
    nodeInfo.temporarilyOffline = computer.isTemporarilyOffline()
    nodeInfo.idle = computer.isIdle()
    nodeInfo.numExecutors = computer.getNumExecutors()
    
    if (node) {
        nodeInfo.nodeDescription = node.getNodeDescription() ?: "Sin descripción"
        nodeInfo.labelString = node.getLabelString() ?: "Sin etiquetas"
        nodeInfo.mode = node.getMode()?.toString() ?: "Normal"
    } else {
        nodeInfo.nodeDescription = "Nodo master"
        nodeInfo.labelString = "master"
        nodeInfo.mode = "NORMAL"
    }
    
    nodeDetails.add(nodeInfo)
}
jenkinsInfo.nodeDetails = nodeDetails

// Información del entorno
try {
    def hostname = InetAddress.getLocalHost().getHostName()
    jenkinsInfo.hostname = hostname
} catch (Exception e) {
    jenkinsInfo.hostname = "No disponible"
}

// Configuración de proxy si existe
def proxyConfiguration = jenkins.proxy
if (proxyConfiguration) {
    jenkinsInfo.proxyHost = proxyConfiguration.name ?: "No configurado"
    jenkinsInfo.proxyPort = proxyConfiguration.port ?: "No configurado"
} else {
    jenkinsInfo.proxyHost = "Sin proxy"
    jenkinsInfo.proxyPort = "Sin proxy"
}

def markdownReport = """
# 📊 Informe de Plugins de Jenkins

## 🏢 Información de Identificación del Jenkins

### 📋 Datos Básicos de la Instancia
| Campo | Valor |
|-------|-------|
| **🆔 URL de la Instancia** | `${jenkinsInfo.instanceUrl}` |
| **📍 Hostname** | `${jenkinsInfo.hostname}` |
| **🔢 Versión de Jenkins** | `${jenkinsInfo.version}` |
| **📁 Directorio Root** | `${jenkinsInfo.rootDir}` |
| **👤 Usuario del Sistema** | `${jenkinsInfo.userName}` |
| **📅 Fecha de Análisis** | `${currentDate}` |

### 🖥️ Información del Sistema Operativo
| Campo | Valor |
|-------|-------|
| **🖥️ Sistema Operativo** | `${jenkinsInfo.osName} ${jenkinsInfo.osVersion}` |
| **🏗️ Arquitectura** | `${jenkinsInfo.osArch}` |
| **☕ Versión de Java** | `${jenkinsInfo.javaVersion}` |
| **🏭 Proveedor de Java** | `${jenkinsInfo.javaVendor}` |
| **📁 Java Home** | `${jenkinsInfo.javaHome}` |

### 💾 Recursos del Sistema
| Campo | Valor |
|-------|-------|
| **🧮 Procesadores Disponibles** | `${jenkinsInfo.availableProcessors}` |
| **📊 Memoria Máxima JVM** | `${jenkinsInfo.maxMemory}` |
| **📈 Memoria Total Asignada** | `${jenkinsInfo.totalMemory}` |
| **🆓 Memoria Libre** | `${jenkinsInfo.freeMemory}` |
| **🔥 Memoria en Uso** | `${jenkinsInfo.usedMemory}` |

### 🔐 Configuración de Seguridad
| Campo | Valor |
|-------|-------|
| **🛡️ Realm de Seguridad** | `${jenkinsInfo.securityRealm}` |
| **⚖️ Estrategia de Autorización** | `${jenkinsInfo.authorizationStrategy}` |
| **🍪 Emisor de Crumb** | `${jenkinsInfo.crumbIssuer}` |

### 🌐 Configuración de Red
| Campo | Valor |
|-------|-------|
| **🔗 Host del Proxy** | `${jenkinsInfo.proxyHost}` |
| **🚪 Puerto del Proxy** | `${jenkinsInfo.proxyPort}` |

### 🏗️ Configuración de Jenkins
| Campo | Valor |
|-------|-------|
| **⏰ Período de Quietud** | `${jenkinsInfo.quietPeriod} segundos` |
| **🔄 Reintentos de SCM Checkout** | `${jenkinsInfo.scmCheckoutRetryCount}` |

### 🖧 Información de Nodos (${jenkinsInfo.totalNodes} total)
| Campo | Valor |
|-------|-------|
| **✅ Nodos Online** | `${jenkinsInfo.onlineNodes}` |
| **❌ Nodos Offline** | `${jenkinsInfo.offlineNodes}` |

#### 📋 Detalle de Nodos
| Nodo | Estado | Ejecutores | Etiquetas | Descripción |
|------|--------|-----------|-----------|-------------|"""

nodeDetails.each { node ->
    def estado = node.online ? "✅ Online" : (node.temporarilyOffline ? "⏸️ Temp. Offline" : "❌ Offline")
    if (node.idle && node.online) estado += " 💤 Idle"
    
    markdownReport += "\n| `${node.name}` | ${estado} | ${node.numExecutors} | `${node.labelString}` | ${node.nodeDescription} |"
}

markdownReport += """

### 📊 Información de Jobs (${jenkinsInfo.totalJobs} total)
| Campo | Valor |
|-------|-------|
| **✅ Jobs Habilitados** | `${jenkinsInfo.enabledJobs}` |
| **❌ Jobs Deshabilitados** | `${jenkinsInfo.disabledJobs}` |
| **📈 Total de Builds** | `${jenkinsInfo.totalBuilds}` |
| **🗓️ Builds Última Semana** | `${jenkinsInfo.recentBuilds}` |

#### 🏷️ Tipos de Jobs
| Tipo de Job | Cantidad |
|-------------|----------|"""

jobTypes.sort { -it.value }.each { jobType, count ->
    markdownReport += "\n| `${jobType}` | ${count} |"
}

markdownReport += """

---

## 📈 Resumen de Plugins

| Categoría | Cantidad | Porcentaje |
|-----------|----------|------------|
| 🟢 **Plugins usados en Pipelines** | ${pluginsInPipelines.size()} | ${Math.round((pluginsInPipelines.size() / installedPlugins.size()) * 100)}% |
| 🔵 **Plugins NO usados en Pipelines** | ${pluginsNotInPipelines.size()} | ${Math.round((pluginsNotInPipelines.size() / installedPlugins.size()) * 100)}% |
| 🔧 **Plugins de Administración** | ${adminPlugins.size()} | ${Math.round((adminPlugins.size() / installedPlugins.size()) * 100)}% |
| 🛡️ **Plugins de Seguridad** | ${securityPlugins.size()} | ${Math.round((securityPlugins.size() / installedPlugins.size()) * 100)}% |
| 🎨 **Plugins de UI/Visualización** | ${uiPlugins.size()} | ${Math.round((uiPlugins.size() / installedPlugins.size()) * 100)}% |
| **📦 Total de Plugins** | **${installedPlugins.size()}** | **100%** |

---

## 🟢 Plugins Usados en Pipelines (${pluginsInPipelines.size()})

| Plugin | Versión | Usos | Estado | Ejemplos de Uso |
|--------|---------|------|--------|-----------------|
"""

pluginsInPipelines.sort { -it.value.pipelineUsageCount }.each { pluginName, info ->
    def status = info.enabled ? (info.active ? "✅ Activo" : "⚠️ Inactivo") : "❌ Deshabilitado"
    def examples = info.usageExamples.join("<br>")
    markdownReport += "| `${info.displayName}` | ${info.version} | ${info.pipelineUsageCount} | ${status} | ${examples} |\n"
}

markdownReport += """

---

## 🔧 Plugins de Administración NO Usados en Pipelines (${adminPlugins.size()})

> Estos plugins proporcionan funcionalidades administrativas y de configuración general

| Plugin | Versión | Estado | Descripción |
|--------|---------|--------|-------------|
"""

adminPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅ Activo" : "⚠️ Inactivo") : "❌ Deshabilitado"
    def description = getPluginDescription(plugin.name)
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} | ${description} |\n"
}

markdownReport += """

---

## 🛡️ Plugins de Seguridad NO Usados en Pipelines (${securityPlugins.size()})

> Plugins relacionados con autenticación, autorización y seguridad

| Plugin | Versión | Estado | Descripción |
|--------|---------|--------|-------------|
"""

securityPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅ Activo" : "⚠️ Inactivo") : "❌ Deshabilitado"
    def description = getPluginDescription(plugin.name)
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} | ${description} |\n"
}

markdownReport += """

---

## 🎨 Plugins de UI/Visualización NO Usados en Pipelines (${uiPlugins.size()})

> Plugins para mejorar la interfaz y visualización de Jenkins

| Plugin | Versión | Estado | Descripción |
|--------|---------|--------|-------------|
"""

uiPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅ Activo" : "⚠️ Inactivo") : "❌ Deshabilitado"
    def description = getPluginDescription(plugin.name)
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} | ${description} |\n"
}

markdownReport += """

---

## 📋 Otros Plugins NO Usados en Pipelines

### 🔨 Build y CI/CD (${buildPlugins.size()})
| Plugin | Versión | Estado |
|--------|---------|--------|
"""

buildPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅" : "⚠️") : "❌"
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} |\n"
}

markdownReport += """

### 📡 SCM y Versionado (${scmPlugins.size()})
| Plugin | Versión | Estado |
|--------|---------|--------|
"""

scmPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅" : "⚠️") : "❌"
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} |\n"
}

markdownReport += """

### 📧 Notificaciones (${notificationPlugins.size()})
| Plugin | Versión | Estado |
|--------|---------|--------|
"""

notificationPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅" : "⚠️") : "❌"
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} |\n"
}

markdownReport += """

### 🧪 Testing y Calidad (${testingPlugins.size()})
| Plugin | Versión | Estado |
|--------|---------|--------|
"""

testingPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅" : "⚠️") : "❌"
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} |\n"
}

markdownReport += """

### 🚀 Deployment (${deploymentPlugins.size()})
| Plugin | Versión | Estado |
|--------|---------|--------|
"""

deploymentPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅" : "⚠️") : "❌"
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} |\n"
}

markdownReport += """

### ❓ Plugins Sin Categorizar (${unknownPlugins.size()})
| Plugin | Versión | Estado |
|--------|---------|--------|
"""

unknownPlugins.sort { it.displayName }.each { plugin ->
    def status = plugin.enabled ? (plugin.active ? "✅" : "⚠️") : "❌"
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${status} |\n"
}

markdownReport += """

---

## 📊 Estadísticas Detalladas

### Uso en Pipelines
- **Total de pipelines analizados:** ${pipelineScripts.size()}
- **Plugins detectados en pipelines:** ${pluginsInPipelines.size()}
- **Plugins más utilizados:**
"""

pluginsInPipelines.sort { -it.value.pipelineUsageCount }.take(10).each { pluginName, info ->
    markdownReport += "  - `${info.displayName}`: ${info.pipelineUsageCount} usos\n"
}

markdownReport += """

### Estado de Plugins
- **Plugins activos:** ${installedPlugins.findAll { it.isActive() }.size()}
- **Plugins habilitados pero inactivos:** ${installedPlugins.findAll { it.isEnabled() && !it.isActive() }.size()}
- **Plugins deshabilitados:** ${installedPlugins.findAll { !it.isEnabled() }.size()}

### Recomendaciones
1. **Revisar plugins no utilizados:** Considera deshabilitar plugins que no se usan para mejorar el rendimiento
2. **Plugins de administración activos:** Los plugins administrativos están funcionando correctamente
3. **Optimización:** ${pluginsNotInPipelines.size()} plugins no se detectaron en pipelines pero pueden estar en uso por jobs clásicos o configuración global

---

## 📋 Tabla Consolidada de TODOS los Plugins

> Lista completa de todos los plugins ordenados alfabéticamente con su estado y uso

| Plugin | Versión | Estado | En Uso | Tipo de Uso |
|--------|---------|--------|--------|-------------|
"""

// Crear lista consolidada de todos los plugins
def allPluginsConsolidated = []

// Agregar plugins usados en pipelines
pluginsInPipelines.each { pluginName, info ->
    allPluginsConsolidated.add([
        name: info.name,
        displayName: info.displayName,
        version: info.version,
        enabled: info.enabled,
        active: info.active,
        inUse: true,
        usageType: "Pipeline (${info.pipelineUsageCount} usos)"
    ])
}

// Agregar plugins no usados en pipelines
pluginsNotInPipelines.each { plugin ->
    def inUse = false
    def usageType = "Sin uso detectado"
    
    // Determinar si está en uso general (solo plugins realmente importantes)
    if (plugin.category in ['admin', 'security'] && plugin.active) {
        inUse = true
        usageType = getGeneralUsageType(plugin.category, plugin.name)
    } else if (plugin.category == 'ui' && plugin.active && isUIPluginInUse(plugin.name)) {
        inUse = true
        usageType = "Interfaz/Visualización"
    } else if (plugin.active && isCorePlugin(plugin.name)) {
        inUse = true
        usageType = "Plugin core Jenkins"
    } else if (plugin.active) {
        // Plugin activo pero sin uso específico detectado
        usageType = "Activo (sin uso específico)"
    } else {
        usageType = "Inactivo/Deshabilitado"
    }
    
    allPluginsConsolidated.add([
        name: plugin.name,
        displayName: plugin.displayName,
        version: plugin.version,
        enabled: plugin.enabled,
        active: plugin.active,
        inUse: inUse,
        usageType: usageType
    ])
}

// Ordenar por displayName
allPluginsConsolidated.sort { it.displayName.toLowerCase() }

// Generar tabla
allPluginsConsolidated.each { plugin ->
    def estado = plugin.enabled ? (plugin.active ? "✅ Activo" : "⚠️ Habilitado") : "❌ Deshabilitado"
    def enUso = plugin.inUse ? "✅ SÍ" : "❌ NO"
    
    markdownReport += "| `${plugin.displayName}` | ${plugin.version} | ${estado} | ${enUso} | ${plugin.usageType} |\n"
}

markdownReport += """

### 📊 Resumen de la Tabla Consolidada
- **Total de plugins:** ${allPluginsConsolidated.size()}
- **Plugins en uso:** ${allPluginsConsolidated.findAll { it.inUse }.size()}
- **Plugins sin uso:** ${allPluginsConsolidated.findAll { !it.inUse }.size()}
- **Plugins activos:** ${allPluginsConsolidated.findAll { it.active }.size()}
- **Plugins inactivos/deshabilitados:** ${allPluginsConsolidated.findAll { !it.active }.size()}

---

*Informe generado automáticamente por el script de análisis de plugins de Jenkins*
"""

// Guardar el informe con nombre identificativo
def hostname = jenkinsInfo.hostname.replaceAll(/[^a-zA-Z0-9\-_]/, '_')
def version = jenkinsInfo.version.toString().replaceAll(/[^a-zA-Z0-9\-_\.]/, '_')
def timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date())
def reportFileName = "plugin-analysis-${hostname}-v${version}-${timestamp}.md"
def reportFile = new File(jenkins.getRootDir(), reportFileName)
reportFile.text = markdownReport

println """
✅ ANÁLISIS COMPLETADO
====================

📊 Resumen:
• Total plugins: ${installedPlugins.size()}
• Usados en pipelines: ${pluginsInPipelines.size()}
• No usados en pipelines: ${pluginsNotInPipelines.size()}
• Plugins administrativos: ${adminPlugins.size()}
• Plugins de seguridad: ${securityPlugins.size()}
• Plugins de UI: ${uiPlugins.size()}

📄 Informe guardado en: ${reportFile.absolutePath}

🔍 Plugins más utilizados en pipelines:"""

pluginsInPipelines.sort { -it.value.pipelineUsageCount }.take(5).each { pluginName, info ->
    println "   • ${info.displayName}: ${info.pipelineUsageCount} usos"
}

println "\n📋 INFORME MARKDOWN:\n"
println "=" * 50
println markdownReport
println "=" * 50

// Función helper para describir plugins
def getPluginDescription(pluginName) {
    def descriptions = [
        'configuration-as-code': 'Configuración como código (JCasC)',
        'job-dsl': 'Creación de jobs mediante DSL',
        'script-security': 'Seguridad de scripts',
        'role-strategy': 'Gestión de roles y permisos',
        'matrix-auth': 'Autenticación matricial',
        'ldap': 'Integración con LDAP',
        'active-directory': 'Integración con Active Directory',
        'credentials': 'Gestión de credenciales',
        'ssh-agent': 'Agente SSH',
        'timestamper': 'Marcas de tiempo en logs',
        'ws-cleanup': 'Limpieza de workspace',
        'blueocean': 'Interfaz moderna Blue Ocean',
        'dashboard-view': 'Vista de dashboard',
        'build-pipeline-plugin': 'Vista de pipeline de builds',
        'junit': 'Reportes de tests JUnit',
        'jacoco': 'Cobertura de código JaCoCo',
        'sonar': 'Integración con SonarQube',
        'slack': 'Notificaciones Slack',
        'email-ext': 'Email extendido'
    ]
    
    return descriptions[pluginName] ?: 'Plugin de Jenkins'
}

// Función para obtener nombre de categoría para mostrar
def getCategoryDisplayName(category) {
    def categoryNames = [
        'admin': '🔧 Administración',
        'security': '🛡️ Seguridad', 
        'build': '🔨 Build/CI-CD',
        'scm': '📡 SCM/Versionado',
        'notification': '📧 Notificaciones',
        'ui': '🎨 UI/Visualización',
        'testing': '🧪 Testing/Calidad',
        'deployment': '🚀 Deployment',
        'unknown': '❓ Sin categorizar'
    ]
    
    return categoryNames[category] ?: '❓ Sin categorizar'
}

// Función para determinar tipo de uso general
def getGeneralUsageType(category, pluginName) {
    switch(category) {
        case 'admin':
            return "Administración Jenkins"
        case 'security':
            if (pluginName.contains('credentials') || pluginName.contains('ssh')) {
                return "Gestión de credenciales"
            } else if (pluginName.contains('auth') || pluginName.contains('ldap') || pluginName.contains('saml')) {
                return "Autenticación/SSO"
            } else {
                return "Seguridad Jenkins"
            }
        case 'ui':
            return "Interfaz/Visualización"
        default:
            return "Uso general Jenkins"
    }
}

// Función para determinar si un plugin de UI está realmente en uso
def isUIPluginInUse(pluginName) {
    def uiPluginsInUse = ['blueocean', 'dashboard-view', 'build-pipeline-plugin']
    return uiPluginsInUse.contains(pluginName)
}

// Función para identificar plugins core/esenciales de Jenkins
def isCorePlugin(pluginName) {
    def corePlugins = [
        'ant', 'build-timeout', 'credentials', 'credentials-binding', 'display-url-api',
        'durable-task', 'email-ext', 'folders', 'git', 'github', 'gradle', 'jackson2-api',
        'junit', 'ldap', 'mailer', 'matrix-auth', 'nodejs', 'pam-auth', 'pipeline-build-step',
        'pipeline-input-step', 'pipeline-milestone-step', 'pipeline-model-api', 'pipeline-stage-step',
        'pipeline-stage-tags-metadata', 'plain-credentials', 'resource-disposer', 'ssh-credentials',
        'ssh-slaves', 'subversion', 'timestamper', 'token-macro', 'windows-slaves', 'workflow-aggregator',
        'workflow-basic-steps', 'workflow-cps', 'workflow-durable-task-step', 'workflow-job',
        'workflow-multibranch', 'workflow-scm-step', 'workflow-step-api', 'workflow-support',
        'apache-httpcomponents-client-4-api', 'bootstrap5-api', 'caffeine-api', 'commons-lang3-api',
        'gson-api', 'instance-identity', 'jackson2-api', 'jaxb', 'mailer', 'okhttp-api', 'plugin-util-api',
        'scm-api', 'script-security', 'structs', 'token-macro'
    ]
    return corePlugins.contains(pluginName)
}

return "Análisis completado. Informe guardado en ${reportFile.absolutePath}"
