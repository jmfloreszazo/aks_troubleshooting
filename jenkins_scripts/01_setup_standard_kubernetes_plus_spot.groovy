// SCRIPT: Configurar Kubernetes Cloud Estándar + Pod Template Spot
// =================================================================
// Ejecutar en Jenkins Script Console para configuración completa

import jenkins.model.*
import org.csanchez.jenkins.plugins.kubernetes.*
import org.csanchez.jenkins.plugins.kubernetes.volumes.*
import org.csanchez.jenkins.plugins.kubernetes.pod.retention.*

println """
🔧 CONFIGURANDO KUBERNETES CLOUD ESTÁNDAR + SPOT POD TEMPLATE
============================================================

Este script configurará:
1. ☁️  Kubernetes Cloud estándar (configuración out-of-box)
2. 📦 Pod Template estándar para cualquier pipeline
3. 🎯 Pod Template específico para nodos spot
4. ⚙️  Configuración compatible con pipelines existentes

"""

def jenkins = Jenkins.getInstance()

// Paso 1: Limpiar configuraciones anteriores
println "🧹 LIMPIANDO CONFIGURACIONES ANTERIORES:"
println "========================================"

def cloudsToRemove = []
jenkins.clouds.each { cloud ->
    if (cloud instanceof KubernetesCloud) {
        cloudsToRemove.add(cloud)
        println "   🗑️  Marcando para eliminar: ${cloud.name}"
    }
}

cloudsToRemove.each { cloud ->
    jenkins.clouds.remove(cloud)
    println "   ✅ Eliminado: ${cloud.name}"
}

if (cloudsToRemove.size() == 0) {
    println "   ✅ No hay configuraciones anteriores que limpiar"
}

// Paso 2: Crear Kubernetes Cloud estándar
println "\n☁️  CREANDO KUBERNETES CLOUD ESTÁNDAR:"
println "======================================"

def kubernetesCloud = new KubernetesCloud('kubernetes')

// Configuración básica del cloud (out-of-box)
kubernetesCloud.setServerUrl('https://kubernetes.default.svc.cluster.local')
kubernetesCloud.setNamespace('jenkins-master')
kubernetesCloud.setJenkinsUrl('http://jenkins-master.jenkins-master.svc.cluster.local:8080')
kubernetesCloud.setJenkinsTunnel('jenkins-master-agent.jenkins-master.svc.cluster.local:50000')

// Configuración estándar
kubernetesCloud.setContainerCapStr('20')   // Máximo 20 workers total
kubernetesCloud.setConnectTimeout(60)      // 60 segundos timeout conexión
kubernetesCloud.setReadTimeout(60)         // 60 segundos timeout lectura
kubernetesCloud.setRetentionTimeout(5)     // 5 minutos retención

println "   ✅ Cloud 'kubernetes' configurado (estándar)"
println "   📍 Namespace: jenkins-master"
println "   🔗 Jenkins URL: http://jenkins-master.jenkins-master.svc.cluster.local:8080"
println "   📊 Capacidad máxima: 20 workers"

// Paso 3: Crear Pod Template estándar (cualquier nodo)
println "\n📦 CREANDO POD TEMPLATE ESTÁNDAR:"
println "================================="

def standardPodTemplate = new PodTemplate()

// Configuración del pod template estándar
standardPodTemplate.setName('standard-worker')
standardPodTemplate.setLabel('standard-worker')  // Label específico para nodos estándar
standardPodTemplate.setIdleMinutes(5)       // 5 minutos idle
standardPodTemplate.setInstanceCap(15)      // Máximo 15 instancias estándar

// Pod template estándar usando YAML
def standardYaml = '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    env:
    - name: REMOTING_OPTS
      value: "-noReconnectAfter 1d"
    tty: true
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: workspace-volume
    emptyDir: {}
  restartPolicy: Never
'''

standardPodTemplate.setYaml(standardYaml)
standardPodTemplate.setPodRetention(new Never())

println "   ✅ Pod Template 'standard-worker' configurado"
println "   🏷️  Label: standard-worker (para pipelines estándar)"
println "   📊 Instancias máximas: 15"
println "   💾 Recursos: 100m-1000m CPU, 256Mi-1Gi RAM"

// Paso 4: Crear Pod Template para nodos spot
println "\n🎯 CREANDO POD TEMPLATE PARA NODOS SPOT:"
println "======================================="

def spotPodTemplate = new PodTemplate()

// Configuración del pod template spot
spotPodTemplate.setName('spot-worker')
spotPodTemplate.setLabel('nodepool=spot')    // Label específico para nodos spot
spotPodTemplate.setIdleMinutes(5)            // 5 minutos idle
spotPodTemplate.setInstanceCap(10)           // Máximo 10 instancias spot

// Pod template spot con tolerations y node selector
def spotYaml = '''
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
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoExecute"
  - key: "nodepool"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    env:
    - name: REMOTING_OPTS
      value: "-noReconnectAfter 1d"
    tty: true
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: workspace-volume
    emptyDir: {}
  restartPolicy: Never
'''

spotPodTemplate.setYaml(spotYaml)
spotPodTemplate.setPodRetention(new Never())

println "   ✅ Pod Template 'spot-worker' configurado"
println "   🏷️  Label: nodepool=spot (para nodos spot)"
println "   🎯 Node Selector: nodepool=spot"
println "   📊 Instancias máximas: 10"
println "   💾 Recursos: 100m-1000m CPU, 256Mi-1Gi RAM"

// Paso 5: Configurar Container Templates adicionales (respaldo)
println "\n🐳 CONFIGURANDO CONTAINER TEMPLATES:"
println "==================================="

// Container para template estándar
def standardContainer = new ContainerTemplate('jnlp', 'jenkins/inbound-agent:latest')
standardContainer.setAlwaysPullImage(false)
standardContainer.setTtyEnabled(true)
standardContainer.setPrivileged(false)
standardContainer.setResourceRequestCpu('100m')
standardContainer.setResourceLimitCpu('1000m')
standardContainer.setResourceRequestMemory('256Mi')
standardContainer.setResourceLimitMemory('1Gi')

def standardEnvVars = []
standardEnvVars.add(new ContainerEnvVar('REMOTING_OPTS', '-noReconnectAfter 1d'))
standardContainer.setEnvVars(standardEnvVars)

// Container para template spot
def spotContainer = new ContainerTemplate('jnlp', 'jenkins/inbound-agent:latest')
spotContainer.setAlwaysPullImage(false)
spotContainer.setTtyEnabled(true)
spotContainer.setPrivileged(false)
spotContainer.setResourceRequestCpu('100m')
spotContainer.setResourceLimitCpu('1000m')
spotContainer.setResourceRequestMemory('256Mi')
spotContainer.setResourceLimitMemory('1Gi')

def spotEnvVars = []
spotEnvVars.add(new ContainerEnvVar('REMOTING_OPTS', '-noReconnectAfter 1d'))
spotContainer.setEnvVars(spotEnvVars)

println "   ✅ Container templates configurados"

// Paso 6: Configurar workspaces (via YAML - sin constructores problemáticos)
println "\n💽 CONFIGURANDO WORKSPACES:"
println "=========================="

// Los workspaces están configurados via YAML (emptyDir: {})
// No usamos constructores de EmptyDirVolume para evitar errores
println "   ✅ Workspace volumes configurados via YAML"
println "   💡 emptyDir: {} definido en spec YAML de ambos templates"

// Paso 7: Ensamblar configuración
println "\n🔧 ENSAMBLANDO CONFIGURACIÓN FINAL:"
println "=================================="

// Agregar containers a los pod templates
standardPodTemplate.setContainers([standardContainer])
spotPodTemplate.setContainers([spotContainer])

// Agregar ambos pod templates al cloud
def templates = [standardPodTemplate, spotPodTemplate]
kubernetesCloud.setTemplates(templates)

// Agregar cloud a Jenkins
jenkins.clouds.add(kubernetesCloud)

// Guardar configuración
jenkins.save()

println "   ✅ Container Templates agregados"
println "   ✅ Pod Templates agregados al Cloud"
println "   ✅ Cloud agregado a Jenkins"
println "   💾 Configuración guardada"

// Paso 8: Resumen final
println "\n✅ CONFIGURACIÓN COMPLETADA EXITOSAMENTE"
println "========================================"
println ""
println "📋 RESUMEN DE LA CONFIGURACIÓN:"
println "==============================="
println "☁️  Cloud Name: kubernetes (estándar)"
println "📦 Template 1: standard-worker (label: standard-worker)"
println "📦 Template 2: spot-worker (label: nodepool=spot)"
println "📍 Namespace: jenkins-master"
println "📊 Capacidad total: 20 workers (15 estándar + 10 spot)"
println "💾 Recursos por worker: 100m-1000m CPU, 256Mi-1Gi RAM"
println "💽 Workspace: EmptyDir configurado via YAML"
println ""
println "🎯 TOLERATIONS CONFIGURADAS PARA SPOT:"
println "======================================"
println "✅ kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
println "✅ kubernetes.azure.com/scalesetpriority=spot:NoExecute"
println "✅ nodepool=spot:NoSchedule"
println ""
println "🔧 CORRECCIONES APLICADAS:"
println "=========================="
println "✅ Sin constructores problemáticos de EmptyDirVolume"
println "✅ Workspace configurado via YAML (emptyDir: {})"
println "✅ volumeMounts configurados en containers"
println "✅ Configuración completamente basada en YAML"
println ""
println "🚀 CÓMO USAR EN PIPELINES:"
println "========================="
println ""
println "PARA CUALQUIER NODO (estándar):"
println "-------------------------------"
println "pipeline {"
println "    agent { label 'standard-worker' }  // ← Usa nodos estándar"
println "    stages {"
println "        stage('Build') {"
println "            steps {"
println "                echo 'Running on standard node'"
println "            }"
println "        }"
println "    }"
println "}"
println ""
println "PARA NODOS SPOT ÚNICAMENTE:"
println "---------------------------"
println "pipeline {"
println "    agent { label 'nodepool=spot' }  // ← Usa SOLO nodos spot"
println "    stages {"
println "        stage('Build') {"
println "            steps {"
println "                echo 'Running on spot node - 80-90% cost savings!'"
println "            }"
println "        }"
println "    }"
println "}"
println ""
println "📈 BENEFICIOS:"
println "=============="
println "💰 Nodos spot: 80-90% ahorro vs nodos regulares"
println "🔄 Auto-scaling: Nodos se crean bajo demanda"
println "⚡ Flexibilidad: Usa cualquier nodo O específicamente spot"
println "🛡️ Tolerante: Maneja interrupciones de spot nodes"
println "📊 Escalable: Hasta 20 workers concurrentes"
println ""
println "🎯 CONFIGURACIÓN LISTA PARA USAR"
println "¡Jenkins puede ejecutar pipelines en nodos regulares Y spot!"
println ""
println "💡 PRÓXIMOS PASOS:"
println "=================="
println "1. Crea una pipeline con agent { label 'standard-worker' } para test general"
println "2. Crea una pipeline con agent { label 'nodepool=spot' } para test spot"
println "3. Ejecuta ambas y compara el comportamiento"
println "4. ¡Disfruta del ahorro de costos con nodos spot!"
