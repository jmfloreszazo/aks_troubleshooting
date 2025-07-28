# 🛠️ Configuración Manual de Jenkins para Evitar Saturación

## 📋 Resumen del Problema
Jenkins se quedaba "tieso" debido a múltiples pipelines ejecutándose simultáneamente, causando reinicios constantes y builds atorados en cola.

## 🎯 Solución: Plugins de Control de Concurrencia

### 1. 📦 Plugins Necesarios

#### **Throttle Concurrent Builds Plugin** (`throttle-concurrents:2.14`)
- **Función:** Limita el número de builds simultáneos
- **Beneficio:** Evita saturación del sistema
- **Instalación:** Manage Jenkins → Manage Plugins → Available → Buscar "Throttle Concurrent Builds"

#### **Lockable Resources Plugin** (`lockable-resources:2.20`)
- **Función:** Permite reservar recursos exclusivos
- **Beneficio:** Evita conflictos entre builds
- **Instalación:** Manage Jenkins → Manage Plugins → Available → Buscar "Lockable Resources"

---

## 🔧 Configuración Manual en Jenkins UI

### Paso 1: Instalar Plugins
1. **Navegar a:** `Manage Jenkins` → `Manage Plugins`
2. **Ir a pestaña:** `Available`
3. **Buscar e instalar:**
   - `Throttle Concurrent Builds`
   - `Lockable Resources`
4. **Reiniciar Jenkins** cuando se solicite

### Paso 2: Configurar Throttle Categories
1. **Navegar a:** `Manage Jenkins` → `Configure System`
2. **Buscar sección:** `Throttle Concurrent Builds`
3. **Añadir categorías:**

```
📊 Categoría: spot-workers
├── Max builds per node: 1
├── Max builds total: 2
└── Descripción: "Workers en nodos spot"

📊 Categoría: regular-builds  
├── Max builds per node: 1
├── Max builds total: 3
└── Descripción: "Builds regulares"
```

### Paso 3: Configurar Lockable Resources
1. **Navegar a:** `Manage Jenkins` → `Configure System`
2. **Buscar sección:** `Lockable Resources`
3. **Añadir recursos:**

```
🔒 Recurso: spot-cluster
├── Descripción: "Cluster spot para evitar saturación"
└── Labels: spot, cluster

🔒 Recurso: master-executors
├── Descripción: "Ejecutores del master"
└── Labels: master, executors
```

### Paso 4: Configurar Sistema General
1. **Navegar a:** `Manage Jenkins` → `Configure System`
2. **Configurar:**
   - **# of executors:** `2` (máximo)
   - **Quiet period:** `5` segundos
   - **SCM checkout retry count:** `3`

---

## 💻 Template de Pipeline Anti-Saturación

### Pipeline Básico con Throttling
```groovy
pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    nodepool: spot
  tolerations:
  - key: "nodepool"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
  containers:
  - name: worker
    image: alpine:latest
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
"""
        }
    }
    
    options {
        // ⏰ Timeout obligatorio - evita builds colgados
        timeout(time: 15, unit: 'MINUTES')
        
        // 🚫 Un build a la vez por job
        disableConcurrentBuilds()
        
        // 🗑️ Limpiar builds antiguos
        buildDiscarder(logRotator(numToKeepStr: '3'))
        
        // 🎛️ Throttling por categoría
        throttleJobProperty(
            categories: ['spot-workers'],
            throttleEnabled: true,
            throttleOption: 'category',
            maxConcurrentTotal: 2
        )
    }
    
    stages {
        stage('Pre-Check') {
            steps {
                script {
                    echo "🔍 Verificando recursos disponibles..."
                    echo "Build #${env.BUILD_NUMBER}"
                    echo "Timestamp: ${new Date()}"
                }
            }
        }
        
        stage('Trabajo Controlado') {
            steps {
                // 🔒 Reservar recurso exclusivo
                lock('spot-cluster') {
                    container('worker') {
                        script {
                            echo "🎯 Ejecutándose en worker spot con control!"
                            sh 'hostname'
                            sh 'echo "Trabajo controlado iniciado..."'
                            
                            // Simular trabajo
                            sh 'sleep 10'
                            
                            echo "✅ Trabajo completado sin saturar el sistema!"
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Liberando recursos..."
            }
        }
        failure {
            script {
                echo "❌ Pipeline falló - recursos liberados automáticamente"
            }
        }
        aborted {
            script {
                echo "⏹️ Pipeline cancelado por timeout"
            }
        }
    }
}
```

### Pipeline con Multiple Locks
```groovy
pipeline {
    agent any
    
    options {
        timeout(time: 20, unit: 'MINUTES')
        throttleJobProperty(
            categories: ['regular-builds'],
            throttleEnabled: true,
            throttleOption: 'category'
        )
    }
    
    stages {
        stage('Parallel Work') {
            parallel {
                stage('Spot Work') {
                    steps {
                        lock('spot-cluster') {
                            echo "Trabajando en cluster spot..."
                            sleep 5
                        }
                    }
                }
                stage('Master Work') {
                    steps {
                        lock('master-executors') {
                            echo "Trabajando en master..."
                            sleep 5
                        }
                    }
                }
            }
        }
    }
}
```

---

## 🚨 Solución de Problemas Comunes

### Jenkins se queda "Waiting for next available executor"
1. **Verificar executors:** `Manage Jenkins` → `Manage Nodes` → `master`
2. **Aumentar executors:** De 0 a 2
3. **Cancelar builds atorados:** `Manage Jenkins` → `Build Queue`

### Builds acumulados en cola
```groovy
// Script Groovy para limpiar cola (Manage Jenkins → Script Console)
import jenkins.model.Jenkins
import hudson.model.Queue

def jenkins = Jenkins.getInstance()
def queue = jenkins.getQueue()

println "Items en cola: ${queue.getItems().size()}"

queue.getItems().each { item ->
    println "Cancelando: ${item.task.name}"
    queue.cancel(item)
}

println "Cola limpiada ✅"
```

### Verificar configuración de throttling
1. **Jobs individuales:** En configuración del job → `Throttle builds`
2. **Global:** `Manage Jenkins` → `Configure System` → `Throttle Concurrent Builds`

---

## 📊 Mejores Prácticas

### ✅ DO (Hacer)
- **Usar timeouts** en todos los pipelines (15-30 min máximo)
- **Limitar executors** a 2-3 máximo en master
- **Usar throttling** por categorías
- **Limpiar builds antiguos** automáticamente
- **Monitorear recursos** antes de ejecutar

### ❌ DON'T (No hacer)
- **No omitir timeouts** - causa builds infinitos
- **No permitir builds concurrentes** sin control
- **No acumular builds antiguos** - consume espacio
- **No ignorar warnings** de memoria
- **No ejecutar todo en master** - usar workers

---

## 🔍 Monitoreo y Maintenance

### Script de Limpieza Semanal
```groovy
// Ejecutar en Script Console cada semana
import jenkins.model.Jenkins

def jenkins = Jenkins.getInstance()

// Limpiar builds antiguos
jenkins.allItems.each { job ->
    if (job.hasProperty('builds')) {
        job.builds.findAll { 
            it.timestamp.time < (System.currentTimeMillis() - 7*24*60*60*1000) 
        }.each { 
            it.delete() 
        }
    }
}

println "Limpieza semanal completada ✅"
```

### Comandos de Verificación
```bash
# Verificar estado de Jenkins
kubectl get pods -n jenkins-master

# Ver logs si hay problemas
kubectl logs jenkins-master-0 -n jenkins-master -c jenkins --tail=50

# Verificar memoria
kubectl top pods -n jenkins-master
```

---

## 🎯 Resultado Esperado

Con esta configuración, Jenkins debería:
- ✅ Ejecutar máximo 2-3 builds simultáneos
- ✅ Evitar saturación de memoria
- ✅ Cancelar builds automáticamente por timeout
- ✅ Escalar workers spot solo cuando sea necesario
- ✅ Mantener la cola de builds bajo control

¡Jenkins funcionará de forma estable y controlada! 🚀
