#!/bin/bash

# Detailed inode diagnostic script for AKS nodes
# Connects directly to nodes to analyze inode issues

set -euo pipefail

echo "=========================================="
echo "DETAILED INODE DIAGNOSTIC FOR NODES"
echo "=========================================="

# Function to get debugging pods on each node
create_debug_pods() {
    echo "CREATING DEBUG PODS ON EACH NODE..."
    echo "----------------------------------------"
    
    # Get list of nodes
    nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        echo "Creating debug pod for node: $node"
        
        # Create privileged pod for node access
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: debug-$node
  namespace: default
spec:
  nodeName: $node
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: debug
    image: ubuntu:22.04
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host-root
      mountPath: /host
      readOnly: false
  volumes:
  - name: host-root
    hostPath:
      path: /
  restartPolicy: Never
  tolerations:
  - operator: Exists
EOF
        
        # Wait for pod to be ready
        echo "Waiting for debug-$node pod to be ready..."
        kubectl wait --for=condition=Ready pod/debug-$node --timeout=60s 2>/dev/null || echo "Timeout waiting for debug-$node pod"
    done
}

# Function to analyze inodes on each node
analyze_inodes_per_node() {
    echo ""
    echo "ANALYZING INODES ON EACH NODE..."
    echo "----------------------------------------"
    
    nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        echo ""
        echo "NODE ANALYSIS: $node"
        echo "=============================="
        
        # Check if debug pod exists
        if kubectl get pod debug-$node >/dev/null 2>&1; then
            echo "Basic filesystem information:"
            kubectl exec debug-$node -- chroot /host df -h / 2>/dev/null || echo "Error getting df -h"
            kubectl exec debug-$node -- chroot /host df -i / 2>/dev/null || echo "Error getting df -i"
            
            echo ""
            echo "Top 10 directories with most files:"
            kubectl exec debug-$node -- chroot /host sh -c '
                echo "/var/log:"
                find /var/log -type f 2>/dev/null | wc -l
                echo "/tmp:"
                find /tmp -type f 2>/dev/null | wc -l
                echo "/var/tmp:"
                find /var/tmp -type f 2>/dev/null | wc -l
                echo "/var/lib/docker:"
                find /var/lib/docker -type f 2>/dev/null | wc -l || echo "Docker not found"
                echo "/var/lib/containerd:"
                find /var/lib/containerd -type f 2>/dev/null | wc -l || echo "Containerd not found"
                echo "/var/lib/kubelet:"
                find /var/lib/kubelet -type f 2>/dev/null | wc -l || echo "Kubelet not found"
            ' 2>/dev/null || echo "Error executing directory analysis"
            
            echo ""
            ' 2>/dev/null || echo "Error executing directory analysis"
            
            echo ""
            echo "Inode analysis by root directory:"
            kubectl exec debug-$node -- chroot /host sh -c '
                echo "Directory | Number of files"
                echo "--------------------------------"
                for dir in /var /tmp /usr /opt /home /root; do
                    if [ -d "$dir" ]; then
                        count=$(find "$dir" -type f 2>/dev/null | wc -l)
                        echo "$dir: $count files"
                    fi
                done
            ' 2>/dev/null || echo "Error in detailed analysis"
            
            echo ""
            echo "Container information:"
            kubectl exec debug-$node -- chroot /host sh -c '
                if command -v crictl >/dev/null 2>&1; then
                    echo "Active containers:"
                    crictl ps --quiet | wc -l
                    echo "Images:"
                    crictl images --quiet | wc -l
                else
                    echo "crictl not available"
                fi
            ' 2>/dev/null || echo "Error getting container info"
            
        else
            echo "Debug pod debug-$node not found"
        fi
    done
}
            
            echo ""
            echo "🐳 Información de contenedores:"
            kubectl exec debug-$node -- chroot /host sh -c '
                if command -v crictl >/dev/null 2>&1; then
                    echo "Contenedores activos:"
                    crictl ps --quiet | wc -l
                    echo "Imágenes:"
                    crictl images --quiet | wc -l
                else
                    echo "crictl no disponible"
                fi
            ' 2>/dev/null || echo "❌ Error obteniendo info de contenedores"
            
        else
            echo "❌ Pod debug-$node no encontrado"
        fi
    done
}

# Function to generate detailed report
generate_detailed_report() {
    echo ""
    echo "GENERATING DETAILED REPORT..."
    echo "----------------------------------------"
    
    # Create report file
    report_file="/tmp/inode_analysis_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "INODE ANALYSIS REPORT"
        echo "Date: $(date)"
        echo "=========================================="
        echo ""
        
        echo "CLUSTER INFORMATION:"
        kubectl cluster-info
        echo ""
        
        echo "NODE STATUS:"
        kubectl get nodes -o wide
        echo ""
        
        echo "PODS BY NAMESPACE:"
        kubectl get pods --all-namespaces | awk '{print $1}' | sort | uniq -c | sort -nr
        echo ""
        
        echo "RESOURCE USAGE:"
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"
        echo ""
        
        nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
        for node in $nodes; do
            echo "=========================================="
            echo "NODE: $node"
            echo "=========================================="
            
            if kubectl get pod debug-$node >/dev/null 2>&1; then
                echo "Filesystem info:"
                kubectl exec debug-$node -- chroot /host df -h / 2>/dev/null
                kubectl exec debug-$node -- chroot /host df -i / 2>/dev/null
                echo ""
                
                echo "File analysis by directory:"
                kubectl exec debug-$node -- chroot /host sh -c '
                    for dir in /var/log /tmp /var/tmp /var/lib/docker /var/lib/containerd /var/lib/kubelet; do
                        if [ -d "$dir" ]; then
                            count=$(find "$dir" -type f 2>/dev/null | wc -l)
                            echo "$dir: $count files"
                        fi
                    done
                ' 2>/dev/null
                echo ""
            fi
        done
        
    } > "$report_file"
    
    echo "Report generated at: $report_file"
    echo ""
    echo "To view the report:"
    echo "   cat $report_file"
}

# Function to clean up debug pods
cleanup_debug_pods() {
    echo ""
    echo "CLEANING UP DEBUG PODS..."
    echo "----------------------------------------"
    
    nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name")
    
    for node in $nodes; do
        echo "Deleting debug-$node..."
        kubectl delete pod debug-$node --ignore-not-found=true
    done
    
    echo "Cleanup completed"
}

# Function to show useful commands
show_useful_commands() {
    echo ""
    echo "USEFUL COMMANDS TO EXECUTE ON NODES..."
    echo "----------------------------------------"
    
    echo "To connect directly to a node and execute commands:"
    echo ""
    echo "1. Detailed inode analysis:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "df -i && echo && du -s /var/log/* | sort -nr | head -10"'
    echo ""
    echo "2. Find directories with most files:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "find /var -type d -exec sh -c '"'"'echo \"{} \$(find \"{}\" -maxdepth 1 -type f | wc -l)\"'"'"' \; | sort -nrk2 | head -10"'
    echo ""
    echo "3. Clean container resources:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "crictl rmi --prune && crictl rmp"'
    echo ""
    echo "4. Analyze temporary files:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "find /tmp -type f -mtime +1 | wc -l"'
    echo ""
    echo "5. Find very small files consuming inodes:"
    echo '   kubectl exec debug-<node-name> -- chroot /host sh -c "find /var -type f -size -1k | head -20"'
}

# Main function
main() {
    echo "Starting detailed inode diagnostic on AKS nodes"
    echo "This process will create privileged debug pods on each node."
    echo ""
    
    read -p "Continue with the diagnostic? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Diagnostic cancelled"
        exit 0
    fi
    
    create_debug_pods
    sleep 10  # Give time for pods to start
    analyze_inodes_per_node
    generate_detailed_report
    show_useful_commands
    
    echo ""
    echo "============================================="
    echo "DIAGNOSTIC COMPLETED"
    echo "============================================="
    echo ""
    echo "NEXT STEPS:"
    echo "   1. Review the generated report"
    echo "   2. Use the useful commands for specific analysis"
    echo "   3. Execute cleanup if necessary"
    echo "   4. Delete debug pods when finished"
    echo ""
    echo "To clean up debug pods:"
    echo "   $0 cleanup"
    echo ""
    echo "Monitoring dashboard:"
    echo "   http://[MONITORING_IP]/d/ca7aa68f-5b77-4205-a6cb-b2f7133966f2"
}

# Check arguments
if [ "${1:-}" = "cleanup" ]; then
    cleanup_debug_pods
    exit 0
fi

# Execute main function
main "$@"
