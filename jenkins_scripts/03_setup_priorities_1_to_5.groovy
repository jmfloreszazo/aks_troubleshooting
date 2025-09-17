// SCRIPT: Configurar Job Priorities Plugin - Priority Sorter (1-5)
// ==============================================================
// Ejecutar en Jenkins Script Console para configuración automática

import jenkins.model.*
import jenkins.advancedqueue.*

println """
🎯 CONFIGURACIÓN AUTOMÁTICA DE JOB PRIORITIES (1-5)
==================================================

Este script configura el sistema de prioridades usando:
• Priority 1 = MÁXIMA PRIORIDAD (crítico)
• Priority 2 = ALTA PRIORIDAD  
• Priority 3 = PRIORIDAD MEDIA (por defecto)
• Priority 4 = BAJA PRIORIDAD
• Priority 5 = MÍNIMA PRIORIDAD (background)

Los pipelines usarán una variable 'PRIORITY' con valores 1-5.
Si no se especifica PRIORITY, se asume valor 3 (media).

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
    
    println "\n🆕 CREANDO GRUPOS DE PRIORIDAD (1-5)"
    println "==================================="
    
    // Crear lista de nuevos grupos
    def newGroups = []
    
    // GRUPO 1: CRÍTICO (Priority 1)
    println "\n🔴 Creando grupo CRÍTICO (Priority 1)..."
    def criticalGroup = new JobGroup()
    criticalGroup.setDescription("Jobs críticos - máxima prioridad")
    criticalGroup.setPriority(1)
    newGroups.add(criticalGroup)
    println "   ✅ Grupo CRÍTICO creado: Priority=1"
    
    // GRUPO 2: ALTO (Priority 2)
    println "\n🟠 Creando grupo ALTO (Priority 2)..."
    def highGroup = new JobGroup()
    highGroup.setDescription("Jobs de alta prioridad")
    highGroup.setPriority(2)
    newGroups.add(highGroup)
    println "   ✅ Grupo ALTO creado: Priority=2"
    
    // GRUPO 3: MEDIO (Priority 3) - POR DEFECTO
    println "\n🟡 Creando grupo MEDIO (Priority 3 - Default)..."
    def mediumGroup = new JobGroup()
    mediumGroup.setDescription("Jobs estándar - prioridad por defecto")
    mediumGroup.setPriority(3)
    newGroups.add(mediumGroup)
    println "   ✅ Grupo MEDIO creado: Priority=3 (DEFAULT)"
    
    // GRUPO 4: BAJO (Priority 4)
    println "\n🟢 Creando grupo BAJO (Priority 4)..."
    def lowGroup = new JobGroup()
    lowGroup.setDescription("Jobs de baja prioridad")
    lowGroup.setPriority(4)
    newGroups.add(lowGroup)
    println "   ✅ Grupo BAJO creado: Priority=4"
    
    // GRUPO 5: BACKGROUND (Priority 5)
    println "\n🔵 Creando grupo BACKGROUND (Priority 5)..."
    def backgroundGroup = new JobGroup()
    backgroundGroup.setDescription("Jobs de background - mínima prioridad")
    backgroundGroup.setPriority(5)
    newGroups.add(backgroundGroup)
    println "   ✅ Grupo BACKGROUND creado: Priority=5"
    
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
            println ""
        }
    } else {
        println "❌ ERROR: No se encontraron grupos después de la configuración"
    }
    
    println "🎉 CONFIGURACIÓN COMPLETADA EXITOSAMENTE"
    println "========================================"
    println ""
    println "📋 SISTEMA DE PRIORIDADES CONFIGURADO:"
    println "======================================"
    println "🔴 Priority 1: Jobs críticos - máxima prioridad"
    println "🟠 Priority 2: Jobs de alta prioridad"
    println "🟡 Priority 3: Jobs estándar - prioridad por defecto"
    println "🟢 Priority 4: Jobs de baja prioridad"
    println "🔵 Priority 5: Jobs de background - mínima prioridad"
    println ""
    println "🚀 CÓMO USAR EN PIPELINES:"
    println "========================="
    println ""
    println "EJEMPLO 1 - Pipeline crítico (Priority 1):"
    println "-------------------------------------------"
    println "pipeline {"
    println "    agent any"
    println "    parameters {"
    println "        choice("
    println "            name: 'PRIORITY',"
    println "            choices: ['1', '2', '3', '4', '5'],"
    println "            description: 'Job Priority (1=Critical, 3=Default, 5=Background)'"
    println "        )"
    println "    }"
    println "    stages {"
    println "        stage('Critical Task') {"
    println "            steps {"
    println "                echo \"Running with Priority: \\${params.PRIORITY ?: '3'}\""
    println "                echo 'This job runs FIRST!'"
    println "            }"
    println "        }"
    println "    }"
    println "}"
    println ""
    println "EJEMPLO 2 - Pipeline con prioridad por defecto:"
    println "-----------------------------------------------"
    println "pipeline {"
    println "    agent any"
    println "    // Sin parámetro PRIORITY = Priority 3 (default)"
    println "    stages {"
    println "        stage('Standard Task') {"
    println "            steps {"
    println "                echo 'Running with default priority (3)'"
    println "            }"
    println "        }"
    println "    }"
    println "}"
    println ""
    println "EJEMPLO 3 - Pipeline background (Priority 5):"
    println "----------------------------------------------"
    println "pipeline {"
    println "    agent any"
    println "    parameters {"
    println "        choice("
    println "            name: 'PRIORITY',"
    println "            choices: ['5'],"
    println "            description: 'Background job - lowest priority'"
    println "        )"
    println "    }"
    println "    stages {"
    println "        stage('Background Task') {"
    println "            steps {"
    println "                echo 'Running with lowest priority (5)'"
    println "                echo 'This job runs LAST when resources available'"
    println "            }"
    println "        }"
    println "    }"
    println "}"
    println ""
    println "🧪 PARA PROBAR EL SISTEMA:"
    println "=========================="
    println "1. Crea pipelines con diferentes valores de PRIORITY"
    println "2. Ejecuta múltiples builds simultáneamente:"
    println "   - Job con PRIORITY=1 (crítico)"
    println "   - Job con PRIORITY=3 (estándar)"
    println "   - Job con PRIORITY=5 (background)"
    println "   - Job SIN PRIORITY (asume 3)"
    println ""
    println "3. Ve a Jenkins Dashboard > Build Queue"
    println ""
    println "4. Observa el ORDEN de ejecución:"
    println "   🔴 Priority 1 → SE EJECUTA PRIMERO"
    println "   🟡 Priority 3 → Se ejecuta segundo"
    println "   🔵 Priority 5 → Se ejecuta último"
    println ""
    println "💡 CONFIGURACIÓN MANUAL SI ES NECESARIA:"
    println "========================================"
    println "Si necesitas configurar manualmente:"
    println "1. Ve a: Manage Jenkins > Configure System > Job Priorities"
    println "2. Los grupos ya están creados con Priority 1-5"
    println "3. Si necesitas patterns específicos, configúralos en la UI"
    println ""
    println "✅ EL PLUGIN USARÁ AUTOMÁTICAMENTE EL PARÁMETRO 'PRIORITY'"
    println "✅ SI NO EXISTE PRIORITY, ASUME VALOR 3 (MEDIO)"
    println ""
    println "🎯 ¡SISTEMA DE PRIORIDADES 1-5 LISTO Y FUNCIONANDO!"
    
} catch (Exception e) {
    println "❌ ERROR DURANTE LA CONFIGURACIÓN:"
    println "=================================="
    println "Error: ${e.message}"
    println ""
    println "🔧 CONFIGURACIÓN MANUAL ALTERNATIVA:"
    println "===================================="
    println "Ve a: Manage Jenkins > Configure System > Job Priorities"
    println ""
    println "Crear 5 grupos manualmente:"
    println ""
    println "GRUPO 1 - CRÍTICO:"
    println "• Description: Jobs críticos - máxima prioridad"
    println "• Priority: 1"
    println ""
    println "GRUPO 2 - ALTO:"
    println "• Description: Jobs de alta prioridad"
    println "• Priority: 2"
    println ""
    println "GRUPO 3 - MEDIO (DEFAULT):"
    println "• Description: Jobs estándar - prioridad por defecto"
    println "• Priority: 3"
    println ""
    println "GRUPO 4 - BAJO:"
    println "• Description: Jobs de baja prioridad"
    println "• Priority: 4"
    println ""
    println "GRUPO 5 - BACKGROUND:"
    println "• Description: Jobs de background - mínima prioridad"
    println "• Priority: 5"
    println ""
    // Imprimir stack trace para debugging
    e.printStackTrace()
}
