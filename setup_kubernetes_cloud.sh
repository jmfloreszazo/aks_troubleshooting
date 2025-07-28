#!/bin/bash

# Script para configurar la nube de Kubernetes en Jenkins

echo "🔧 Configurando nube de Kubernetes en Jenkins..."

# Crear ConfigMap con configuración de Jenkins para Kubernetes
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-kubernetes-config
  namespace: jenkins-master
data:
  kubernetes-cloud.groovy: |
    import jenkins.model.*
    import org.csanchez.jenkins.plugins.kubernetes.*
    import org.csanchez.jenkins.plugins.kubernetes.volumes.workspace.EmptyDirWorkspaceVolume
    import org.csanchez.jenkins.plugins.kubernetes.pod.retention.Never

    def jenkins = Jenkins.getInstance()

    // Eliminar nubes existentes de Kubernetes
    jenkins.clouds.removeAll { cloud -> cloud instanceof KubernetesCloud }

    // Configurar nueva nube de Kubernetes
    def kubernetesCloud = new KubernetesCloud("kubernetes")
    kubernetesCloud.setServerUrl("https://kubernetes.default.svc.cluster.local")
    kubernetesCloud.setNamespace("jenkins-workers")
    kubernetesCloud.setJenkinsUrl("http://jenkins-master.jenkins-master.svc.cluster.local:8080")
    kubernetesCloud.setJenkinsTunnel("jenkins-master-agent.jenkins-master.svc.cluster.local:50000")
    kubernetesCloud.setContainerCapStr("100")
    kubernetesCloud.setConnectTimeout(300)
    kubernetesCloud.setReadTimeout(300)
    kubernetesCloud.setRetentionTimeout(300)
    kubernetesCloud.setPodRetention(new Never())
    kubernetesCloud.setWebSocket(true)

    // Configurar template de pod por defecto
    def podTemplate = new PodTemplate()
    podTemplate.setName("jenkins-worker")
    podTemplate.setNamespace("jenkins-workers")
    podTemplate.setLabel("jenkins-worker")
    podTemplate.setNodeSelector("nodepool=monitoring")
    podTemplate.setWorkspaceVolume(new EmptyDirWorkspaceVolume(false))
    
    // Configurar tolerations
    def toleration = new PodToleration()
    toleration.setKey("nodepool")
    toleration.setValue("monitoring")
    toleration.setOperator("Equal")
    toleration.setEffect("NoSchedule")
    podTemplate.setTolerations([toleration])

    // Configurar contenedor Jenkins
    def containerTemplate = new ContainerTemplate("jnlp", "jenkins/inbound-agent:latest")
    containerTemplate.setCommand("")
    containerTemplate.setArgs("\${computer.jnlpmac} \${computer.name}")
    containerTemplate.setResourceRequestCpu("100m")
    containerTemplate.setResourceRequestMemory("256Mi")
    containerTemplate.setResourceLimitCpu("500m")
    containerTemplate.setResourceLimitMemory("512Mi")
    
    podTemplate.setContainers([containerTemplate])
    kubernetesCloud.addTemplate(podTemplate)

    // Agregar la nube a Jenkins
    jenkins.clouds.add(kubernetesCloud)
    jenkins.save()

    println "✅ Nube de Kubernetes configurada correctamente"
EOF

echo "📋 ConfigMap creado con configuración de Kubernetes"

# Ejecutar el script de configuración en Jenkins
echo "🚀 Ejecutando configuración en Jenkins..."
kubectl exec -n jenkins-master jenkins-master-0 -c jenkins -- \
  groovy /var/jenkins_home/casc_configs/kubernetes-cloud.groovy

# Montar el ConfigMap en Jenkins
echo "🔧 Montando configuración en Jenkins..."
kubectl patch statefulset jenkins-master -n jenkins-master --type='merge' -p='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "jenkins",
            "volumeMounts": [
              {
                "name": "kubernetes-config",
                "mountPath": "/var/jenkins_home/casc_configs",
                "readOnly": true
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "kubernetes-config",
            "configMap": {
              "name": "jenkins-kubernetes-config"
            }
          }
        ]
      }
    }
  }
}'

echo ""
echo "✅ Configuración aplicada. Verificando estado..."
kubectl get pods -n jenkins-master
kubectl get pods -n jenkins-workers

echo ""
echo "🎯 Para probar:"
echo "1. Ve a Jenkins: http://20.8.71.3:8080"
echo "2. Manage Jenkins > Nodes > Cloud"
echo "3. Ejecuta un pipeline para probar workers automáticos"
