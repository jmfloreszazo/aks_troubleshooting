#!/bin/bash

# 02_deploy_jenkins.sh - Deploy Jenkins Master
# Part of AKS + Jenkins + Spot Workers system

source .env.production
source common.sh

echo "Deploying Jenkins Master"
echo "======================="
echo ""

# Verify cluster exists
echo "Verifying AKS cluster..."
if ! az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Error: Cluster $CLUSTER_NAME not found"
    echo "Please execute first: ./01_create_cluster.sh"
    exit 1
fi

# Connect to cluster
echo "Connecting to cluster..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

# Add Jenkins repository
echo "Configuring Jenkins Helm repository..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Verify values file exists
if [ ! -f "helm/jenkins_helm_values.yaml" ]; then
    echo "❌ Error: Archivo helm/jenkins_helm_values.yaml no encontrado"
    exit 1
fi

# Desplegar Jenkins
echo "🚀 Desplegando Jenkins Master..."
helm install jenkins-master jenkins/jenkins \
  --namespace jenkins-master \
  --create-namespace \
  --values helm/jenkins_helm_values.yaml \
  --wait \
  --timeout=10m

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Jenkins Master desplegado exitosamente"
    echo ""
    
    # Obtener IP externa
    echo "🔍 Obteniendo IP externa del LoadBalancer..."
    sleep 30
    
    EXTERNAL_IP=""
    while [ -z "$EXTERNAL_IP" ]; do
        echo "⏳ Esperando IP externa..."
        EXTERNAL_IP=$(kubectl get svc -n jenkins-master jenkins-master -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        sleep 10
    done
    
    echo ""
    echo "🎉 JENKINS MASTER LISTO"
    echo "======================"
    echo "🌐 URL: http://$EXTERNAL_IP:8080"
    echo "👤 Usuario: admin"
    echo "🔐 Contraseña: admin123"
    echo ""
    # Actualizar .env.production con la IP
    update_env_var "JENKINS_URL" "http://$EXTERNAL_IP:8080"
    
    echo ""
    echo "� CONFIGURANDO PERMISOS RBAC PARA SPOT WORKERS..."
    echo "================================================="
    
    # Crear namespace jenkins-workers
    echo "📝 Creando namespace jenkins-workers..."
    kubectl create namespace jenkins-workers --dry-run=client -o yaml | kubectl apply -f -
    
    # Crear configuración RBAC completa
    echo "🔐 Aplicando permisos RBAC..."
    cat << 'EOF' | kubectl apply -f -
# ClusterRole para Jenkins con permisos específicos para spot workers
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-spot-worker-manager
  labels:
    app: jenkins
    component: spot-workers
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "pods/status"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
---
# ClusterRoleBinding para conectar Jenkins ServiceAccount con ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-spot-worker-binding
  labels:
    app: jenkins
    component: spot-workers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-spot-worker-manager
subjects:
- kind: ServiceAccount
  name: jenkins-master
  namespace: jenkins-master
---
# Role específico para jenkins-workers namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: jenkins-workers
  name: jenkins-worker-manager
  labels:
    app: jenkins
    component: spot-workers
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "pods/status", "pods/attach"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
# RoleBinding para jenkins-workers namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-worker-binding
  namespace: jenkins-workers
  labels:
    app: jenkins
    component: spot-workers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins-worker-manager
subjects:
- kind: ServiceAccount
  name: jenkins-master
  namespace: jenkins-master
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Permisos RBAC aplicados exitosamente"
    else
        echo "⚠️ Error aplicando permisos RBAC (continuando...)"
    fi
    
    echo ""
    echo "💡 Siguiente paso: ./03_configure_jenkins_spot.sh"
    
else
    echo "❌ Error en el despliegue de Jenkins"
    exit 1
fi