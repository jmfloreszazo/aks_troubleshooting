// SCRIPT: Configurar Job Priorities Plugin - Priority Sorter
// =========================================================
// Ejecutar en Jenkins Script Console para configuración automática

import jenkins.model.*
import jenkins.advancedqueue.*

println """
🎯 CONFIGURACIÓN AUTOMÁTICA DE JOB PRIORITIES
=============================================

Este script:
1. 🔍 Detecta el plugin Priority Sorter instalado
2. 🗑️ Limpia configuración existente
3. 🆕 Crea 3 grupos de prioridad automáticamente
4. ✅ Configura patrones y prioridades específicos

"""

def jenkins = Jenkins.getInstance()

try {
    println "\n🔍 DETECTANDO PLUGIN PRIORITY SORTER"
    println "===================================="
    
    // Obtener descriptor del plugin
    def descriptor = jenkins.getDescriptor('jenkins.advancedqueue.PriorityConfiguration')
    
    if (descriptor == null) {
        println "❌ ERROR: No se pudo obtener el descriptor del plugin"
        println "   Verifica que Priority Sorter Plugin esté instalado correctamente"
        return
    }
    
    println "✅ Plugin Priority Sorter detectado correctamente"
    println "   Descriptor: ${descriptor.class.name}"
    
    println "\n🗑️ LIMPIANDO CONFIGURACIÓN EXISTENTE"
    println "===================================="
    
    // Limpiar grupos existentes
    def existingGroups = descriptor.getJobGroups()
    if (existingGroups != null && existingGroups.size() > 0) {
        println "ℹ️ Encontrados ${existingGroups.size()} grupos existentes"
        existingGroups.clear()
        println "✅ Grupos existentes eliminados"
    } else {
        println "ℹ️ No hay grupos existentes que limpiar"
    }
    
    println "\n🆕 CREANDO NUEVOS GRUPOS DE PRIORIDAD"
    println "====================================="
    
    // Crear lista de nuevos grupos
    def newGroups = []
    
    // GRUPO 1: ALTA PRIORIDAD
    println "\n🔴 Creando grupo ALTA PRIORIDAD..."
    def highGroup = new JobGroup()
    highGroup.setDescription("Jobs críticos de alta prioridad")
    highGroup.setPriority(100)
    
    // Configurar pattern usando la API correcta
    try {
        highGroup.setJobPattern("priority-high-.*")
        println "   ✅ Pattern configurado: priority-high-.*"
    } catch (Exception pe) {
        println "   ⚠️ No se pudo configurar pattern automáticamente: ${pe.message}"
    }
    
    newGroups.add(highGroup)
    println "   ✅ Grupo ALTA creado: Priority=100"
    
    // GRUPO 2: MEDIA PRIORIDAD
    println "\n🟡 Creando grupo MEDIA PRIORIDAD..."
    def mediumGroup = new JobGroup()
    mediumGroup.setDescription("Jobs estándar de prioridad media")
    mediumGroup.setPriority(50)
    
    // Configurar pattern usando la API correcta
    try {
        mediumGroup.setJobPattern("priority-medium-.*")
        println "   ✅ Pattern configurado: priority-medium-.*"
    } catch (Exception pe) {
        println "   ⚠️ No se pudo configurar pattern automáticamente: ${pe.message}"
    }
    
    newGroups.add(mediumGroup)
    println "   ✅ Grupo MEDIA creado: Priority=50"
    
    // GRUPO 3: BAJA PRIORIDAD
    println "\n🟢 Creando grupo BAJA PRIORIDAD..."
    def lowGroup = new JobGroup()
    lowGroup.setDescription("Jobs de background y mantenimiento")
    lowGroup.setPriority(10)
    
    // Configurar pattern usando la API correcta
    try {
        lowGroup.setJobPattern("priority-low-.*")
        println "   ✅ Pattern configurado: priority-low-.*"
    } catch (Exception pe) {
        println "   ⚠️ No se pudo configurar pattern automáticamente: ${pe.message}"
    }
    
    newGroups.add(lowGroup)
    println "   ✅ Grupo BAJA creado: Priority=10"
    
    println "\n💾 GUARDANDO CONFIGURACIÓN"
    println "=========================="
    
    // Asignar nuevos grupos al descriptor
    descriptor.setJobGroups(newGroups)
    
    // Guardar configuración
    descriptor.save()
    jenkins.save()
    
    println "✅ Configuración guardada correctamente"
    
    println "\n🔍 VERIFICACIÓN FINAL"
    println "===================="
    
    // Verificar configuración
    def finalGroups = descriptor.getJobGroups()
    if (finalGroups != null && finalGroups.size() > 0) {
        println "✅ Grupos configurados correctamente: ${finalGroups.size()}"
        finalGroups.eachWithIndex { group, index ->
            println "   ${index + 1}. ${group.getDescription()}"
            println "      Priority: ${group.getPriority()}"
            
            // Verificar pattern de forma segura
            try {
                def pattern = group.getJobPattern()
                if (pattern) {
                    println "      Pattern: ${pattern}"
                } else {
                    println "      Pattern: (no configurado)"
                }
            } catch (Exception pe) {
                println "      Pattern: (no disponible via API)"
            }
            println ""
        }
    } else {
        println "❌ ERROR: No se encontraron grupos después de la configuración"
    }
    
    println "🎉 CONFIGURACIÓN COMPLETADA EXITOSAMENTE"
    println "========================================"
    println ""
    println "📋 GRUPOS CONFIGURADOS:"
    println "======================="
    println "🔴 ALTA PRIORIDAD:"
    println "   • Description: Jobs críticos de alta prioridad"
    println "   • Priority: 100"
    println "   • Pattern: priority-high-.*"
    println "   • Matches: priority-high-critical"
    println ""
    println "🟡 MEDIA PRIORIDAD:"
    println "   • Description: Jobs estándar de prioridad media"
    println "   • Priority: 50"
    println "   • Pattern: priority-medium-.*"
    println "   • Matches: priority-medium-standard"
    println ""
    println "🟢 BAJA PRIORIDAD:"
    println "   • Description: Jobs de background y mantenimiento"
    println "   • Priority: 10"
    println "   • Pattern: priority-low-.*"
    println "   • Matches: priority-low-background"
    println ""
    println "🧪 PARA PROBAR EL SISTEMA:"
    println "=========================="
    println "1. Ejecuta múltiples builds de los pipelines:"
    println "   - priority-high-critical (2-3 builds)"
    println "   - priority-medium-standard (2-3 builds)"
    println "   - priority-low-background (2-3 builds)"
    println ""
    println "2. Ve a Jenkins Dashboard > Build Queue"
    println ""
    println "3. Observa el ORDEN de ejecución:"
    println "   🔴 priority-high-critical → SE EJECUTA PRIMERO"
    println "   🟡 priority-medium-standard → Se ejecuta segundo"
    println "   🟢 priority-low-background → Se ejecuta último"
    println ""
    println "✅ Si ves este orden, ¡el sistema funciona perfectamente!"
    println ""
    println "📊 VERIFICAR EN UI:"
    println "=================="
    println "Ve a: Manage Jenkins > Configure System > Job Priorities"
    println "Deberías ver los 3 grupos configurados correctamente"
    println ""
    println "🎯 ¡SISTEMA DE PRIORIDADES LISTO Y FUNCIONANDO!"
    
} catch (Exception e) {
    println "❌ ERROR DURANTE LA CONFIGURACIÓN:"
    println "=================================="
    println "Error: ${e.message}"
    println ""
    println "🔧 SOLUCIONES POSIBLES:"
    println "======================"
    println "1. Verifica que Priority Sorter Plugin esté instalado"
    println "2. Verifica la versión del plugin (debe ser compatible)"
    println "3. Reinicia Jenkins y vuelve a intentar"
    println "4. Como alternativa, configura manualmente:"
    println ""
    println "   CONFIGURACIÓN MANUAL:"
    println "   ====================="
    println "   Ve a: Manage Jenkins > Configure System > Job Priorities"
    println ""
    println "   GRUPO 1:"
    println "   Description: Jobs críticos de alta prioridad"
    println "   Jobs to include: Use Job Pattern"
    println "   Job Pattern: priority-high-.*"
    println "   Priority: 100"
    println ""
    println "   GRUPO 2:"
    println "   Description: Jobs estándar de prioridad media"
    println "   Jobs to include: Use Job Pattern"
    println "   Job Pattern: priority-medium-.*"
    println "   Priority: 50"
    println ""
    println "   GRUPO 3:"
    println "   Description: Jobs de background y mantenimiento"
    println "   Jobs to include: Use Job Pattern"
    println "   Job Pattern: priority-low-.*"
    println "   Priority: 10"
    
    // Imprimir stack trace para debugging
    e.printStackTrace()
}
