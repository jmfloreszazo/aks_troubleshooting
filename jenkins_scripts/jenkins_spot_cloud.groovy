// jenkins_spot_cloud.groovy
// Production-ready Jenkins Kubernetes Cloud configuration for Azure Spot instances
// Includes proper tolerations and resource allocation for cost-effective CI/CD

import jenkins.model.Jenkins
import org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud
import org.csanchez.jenkins.plugins.kubernetes.PodTemplate
import org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate

println "Configuring Jenkins Kubernetes Cloud for Azure Spot instances..."
println "================================================================="

def jenkins = Jenkins.getInstance()

// Clean up existing spot cloud configurations
println "Removing existing spot cloud configurations..."
def cloudsToRemove = []
jenkins.clouds.each { cloud ->
    if (cloud.name.toLowerCase().contains('spot')) {
        cloudsToRemove.add(cloud)
        println "  Marking for removal: ${cloud.name}"
    }
}

cloudsToRemove.each { cloud ->
    jenkins.clouds.remove(cloud)
    println "  Removed: ${cloud.name}"
}

// Create production Kubernetes cloud for spot instances
println ""
println "Creating Kubernetes cloud: 'spot-production'..."

def kubernetesCloud = new KubernetesCloud('spot-production')
kubernetesCloud.setServerUrl('https://kubernetes.default.svc')
kubernetesCloud.setNamespace('jenkins-workers')
kubernetesCloud.setJenkinsUrl('http://jenkins-master.jenkins-master.svc.cluster.local:8080')
kubernetesCloud.setJenkinsTunnel('jenkins-master-agent.jenkins-master.svc.cluster.local:50000')
kubernetesCloud.setContainerCapStr('10')
kubernetesCloud.setConnectTimeout(300)
kubernetesCloud.setReadTimeout(300)
kubernetesCloud.setRetentionTimeout(60)

// Configure pod template for spot workers
println "Configuring pod template: 'spot-worker-production'..."

def podTemplate = new PodTemplate()
podTemplate.setName('spot-worker-production')
podTemplate.setLabel('nodepool=spot')
podTemplate.setIdleMinutes(1)
podTemplate.setInstanceCap(5)

// Set node selector for spot nodepool
podTemplate.setNodeSelector('nodepool=spot')

// Configure Azure spot node tolerations
println "Applying Azure spot node tolerations..."
def yaml = """
spec:
  tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoExecute"
  nodeSelector:
    nodepool: spot
"""

podTemplate.setYaml(yaml)

// Configure Jenkins agent container
println "Configuring Jenkins agent container..."
def containerTemplate = new ContainerTemplate('jnlp', 'jenkins/inbound-agent:latest')
containerTemplate.setAlwaysPullImage(false)
containerTemplate.setCommand('')
containerTemplate.setArgs('')
containerTemplate.setTtyEnabled(true)
containerTemplate.setResourceRequestCpu('100m')
containerTemplate.setResourceRequestMemory('256Mi')
containerTemplate.setResourceLimitCpu('2000m')
containerTemplate.setResourceLimitMemory('2Gi')

def containers = []
containers.add(containerTemplate)
podTemplate.setContainers(containers)

def templates = []
templates.add(podTemplate)
kubernetesCloud.setTemplates(templates)

// Apply cloud configuration
jenkins.clouds.add(kubernetesCloud)
jenkins.save()

println ""
println "Jenkins Kubernetes Cloud configuration completed successfully"
println "==========================================================="
println "Cloud name: spot-production"
println "Pod template: spot-worker-production"
println "Agent label: nodepool=spot"
println ""
println "Configuration details:"
println "======================"
println "Namespace: jenkins-workers"
println "Node selector: nodepool=spot"
println "Tolerations: kubernetes.azure.com/scalesetpriority=spot"
println "Max capacity: 5 concurrent workers"
println "Idle timeout: 1 minute"
println "CPU resources: 100m request, 2000m limit"
println "Memory resources: 256Mi request, 2Gi limit"
println "Container image: jenkins/inbound-agent:latest"
println ""
println "Tolerations configured:"
println "======================"
println "NoSchedule: Enables pod scheduling on spot nodes"
println "NoExecute: Maintains pod execution on spot nodes"
println ""
println "System ready for production use"
println "==============================="
println "Pipelines using 'nodepool=spot' label will trigger automatic spot node creation"
println "Expected cost savings: 80-90% compared to regular compute instances"
println "Auto-scaling will provision spot nodes based on pipeline demand"
println ""
println "Spot cloud configuration completed successfully"
println "Ready for pipeline execution"
