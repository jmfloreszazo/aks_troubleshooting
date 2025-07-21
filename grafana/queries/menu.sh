#!/bin/bash

# Jenkins Spot Workers - Loki Queries Menu
# Execute individual query scripts for easy access

GRAFANA_IP=$(kubectl get svc grafana -n observability-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "GRAFANA_IP_NOT_FOUND")

echo "🔍 JENKINS SPOT WORKERS - LOKI QUERIES MENU"
echo "============================================"
echo ""
echo "📊 Grafana: http://$GRAFANA_IP"
echo "👤 Login: admin / admin123"
echo "🔗 Dashboard: http://$GRAFANA_IP/d/d96d4d0b-f8b5-4733-b086-55acd815c938"
echo ""

echo "📋 Available Query Scripts:"
echo ""
echo "🔍 BASIC QUERIES:"
echo "1️⃣  ./queries/01_all_jenkins_workers.sh     - All Jenkins workers logs"
echo "2️⃣  ./queries/02_workers_on_spot.sh         - Workers on spot nodes only"
echo "3️⃣  ./queries/03_workers_specific_node.sh   - Workers on specific spot node"
echo "4️⃣  ./queries/04_jenkins_master.sh          - Jenkins master logs"
echo "5️⃣  ./queries/05_lifecycle_events.sh        - Worker lifecycle (Created/Started/Killing)"
echo "6️⃣  ./queries/06_scheduling_events.sh       - Pod scheduling events"
echo "7️⃣  ./queries/07_all_spot_logs.sh           - All spot-related logs"
echo ""
echo "🔧 ADVANCED CONFIGURATION ANALYSIS:"
echo "8️⃣  ./queries/08_master_config_analysis.sh  - Master config (memory, plugins, JVM)"
echo "9️⃣  ./queries/09_spot_execution_analysis.sh - Spot workers execution details"
echo "🔟 ./queries/10_complete_system_analysis.sh - Complete system overview"
echo "🏗️  ./queries/11_extract_live_config.sh     - Live Kubernetes config extraction"
echo ""
echo "🔬 DEEP ANALYSIS QUERIES:"
echo "1️⃣2️⃣ ./queries/12_master_deep_config.sh     - Master configuration deep dive"
echo "1️⃣3️⃣ ./queries/13_spot_execution_deep.sh    - Spot execution deep analysis"
echo ""
echo "📋 SUMMARY & REPORTS:"
echo "📊 ./queries/SUMMARY_jenkins_config.sh     - Complete configuration summary"
echo ""

echo "💡 Usage:"
echo "   cd /path/to/aks_troubleshooting_v2/grafana"
echo "   ./queries/01_all_jenkins_workers.sh"
echo ""
echo "🎯 Each script will show you the exact query to copy into Grafana Explore"
echo "📋 No more copy/paste - just run the script and follow the instructions!"

echo ""
echo "🛠️  Quick access - run any query:"
echo ""

# Provide quick selection menu
read -p "Enter query number (1-13, S for summary) to run directly, or press Enter to exit: " choice

case $choice in
    1) ./queries/01_all_jenkins_workers.sh ;;
    2) ./queries/02_workers_on_spot.sh ;;
    3) ./queries/03_workers_specific_node.sh ;;
    4) ./queries/04_jenkins_master.sh ;;
    5) ./queries/05_lifecycle_events.sh ;;
    6) ./queries/06_scheduling_events.sh ;;
    7) ./queries/07_all_spot_logs.sh ;;
    8) ./queries/08_master_config_analysis.sh ;;
    9) ./queries/09_spot_execution_analysis.sh ;;
    10) ./queries/10_complete_system_analysis.sh ;;
    11) ./queries/11_extract_live_config.sh ;;
    12) ./queries/12_master_deep_config.sh ;;
    13) ./queries/13_spot_execution_deep.sh ;;
    S|s) ./queries/SUMMARY_jenkins_config.sh ;;
    "") echo "👋 Goodbye!" ;;
    *) echo "❌ Invalid option. Use 1-13, S for summary, or press Enter to exit." ;;
esac
