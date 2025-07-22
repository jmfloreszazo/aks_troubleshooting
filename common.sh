#!/bin/bash

# common.sh - Common functions
# Part of AKS + Jenkins + Spot Workers system

# Function to update variables in .env.production
update_env_var() {
    local var_name="$1"
    local var_value="$2"
    
    if [ -f .env.production ]; then
        # If variable exists, update it
        if grep -q "^${var_name}=" .env.production; then
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env.production
        else
            # If it doesn't exist, add it
            echo "${var_name}=${var_value}" >> .env.production
        fi
    else
        # If .env.production doesn't exist, create it
        echo "${var_name}=${var_value}" > .env.production
    fi
}

# Function to show status
show_status() {
    echo "SYSTEM STATUS"
    echo "============="
    echo ""
    
    # Verificar cluster
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
        echo "✅ Cluster AKS: $CLUSTER_NAME"
    else
        echo "❌ Cluster AKS: No encontrado"
        return
    fi
    
    # Verificar Jenkins
    if kubectl get deployment jenkins-master -n jenkins-master >/dev/null 2>&1; then
        echo "✅ Jenkins Master: Desplegado"
        
        # Obtener IP externa
        EXTERNAL_IP=$(kubectl get svc -n jenkins-master jenkins-master -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            echo "🌐 Jenkins URL: http://$EXTERNAL_IP:8080"
        fi
    else
        echo "❌ Jenkins Master: No desplegado"
    fi
    
    # Verificar nodes
    echo ""
    echo "🖥️ NODES DEL CLUSTER:"
    kubectl get nodes -l nodepool --no-headers 2>/dev/null | awk '{print "   " $1 " (" $2 ")"}'
    
    echo ""
}

# Función para verificar prerequisitos
check_prerequisites() {
    echo "🔍 Verificando prerequisitos..."
    
    # Verificar Azure CLI
    if ! command -v az >/dev/null 2>&1; then
        echo "❌ Azure CLI no instalado"
        exit 1
    fi
    
    # Verificar kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        echo "❌ kubectl no instalado"
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm >/dev/null 2>&1; then
        echo "❌ Helm no instalado"
        exit 1
    fi
    
    echo "✅ Prerequisitos verificados"
}

# Función para verificar login de Azure
check_azure_login() {
    echo "🔍 Verificando login de Azure..."
    
    if ! az account show >/dev/null 2>&1; then
        echo "❌ No estás logueado en Azure"
        echo "💡 Ejecuta: az login"
        exit 1
    fi
    
    echo "✅ Azure CLI autenticado"
}

# Función para cargar variables de entorno
load_env() {
    if [ -f .env.production ]; then
        source .env.production
        echo "✅ Variables cargadas desde .env.production"
    else
        echo "❌ Archivo .env.production no encontrado"
        echo "Por favor ejecuta primero: ./00_setup_subscription.sh"
        exit 1
    fi
}

# Función para verificar si una variable de entorno existe
check_env() {
    local var_name="$1"
    if [ -z "${!var_name}" ]; then
        return 1
    fi
    return 0
}

# Función para configuración inicial
setup_initial_config() {
    echo "⚙️ Configuración inicial..."
    
    # Usar valores por defecto si no existen
    if [ -z "$RESOURCE_GROUP" ]; then
        update_env_var "RESOURCE_GROUP" "rg-aks-jenkins-spot"
    fi
    
    if [ -z "$CLUSTER_NAME" ]; then
        update_env_var "CLUSTER_NAME" "aks-jenkins-spot"
    fi
    
    if [ -z "$LOCATION" ]; then
        update_env_var "LOCATION" "westeurope"
    fi
    
    echo "✅ Configuración inicial completada"
}

# Función para validar pasos
validate_step() {
    local step="$1"
    echo "✅ Validando paso: $step"
    return 0
}

# Función para logging
log() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

# Función para hacer backup del .env.production (DISABLED - no auto backups)
# backup_env() {
#     if [ -f .env.production ]; then
#         local timestamp=$(date +%Y%m%d_%H%M%S)
#         cp .env.production ".env.production.backup.$timestamp"
#         echo "✅ Backup de .env.production creado: .env.production.backup.$timestamp"
#     fi
# }

# Alias para compatibilidad
update_env() {
    update_env_var "$1" "$2"
}