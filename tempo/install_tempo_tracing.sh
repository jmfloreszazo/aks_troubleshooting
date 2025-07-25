#!/bin/bash

# Jenkins Master-Pod Distributed Tracing Setup with Tempo
# =======================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE_OBSERVABILITY="observability-stack"
NAMESPACE_JENKINS="jenkins-master"
TEMPO_VERSION="1.23.2"

echo -e "${BLUE}🚀 Setting up Jenkins Master-Pod Distributed Tracing with Tempo${NC}"
echo "=================================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! command_exists helm; then
    echo -e "${RED}❌ helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check completed${NC}"

# Create namespace if it doesn't exist
echo -e "${YELLOW}📁 Creating namespace: ${NAMESPACE_OBSERVABILITY}${NC}"
kubectl create namespace ${NAMESPACE_OBSERVABILITY} --dry-run=client -o yaml | kubectl apply -f -

# Add Grafana Helm repository
echo -e "${YELLOW}📦 Adding Grafana Helm repository...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Get latest Tempo version if not specified
if [[ -z "${TEMPO_VERSION}" ]] || ! helm search repo grafana/tempo --version ${TEMPO_VERSION} &>/dev/null; then
    echo -e "${YELLOW}🔍 Detecting latest Tempo version...${NC}"
    TEMPO_VERSION=$(helm search repo grafana/tempo -o json | jq -r '.[0].version')
    echo -e "${BLUE}Using Tempo chart version: ${TEMPO_VERSION}${NC}"
fi

# Install Tempo
echo -e "${YELLOW}🎯 Installing Grafana Tempo...${NC}"
helm upgrade --install tempo grafana/tempo \
  --namespace ${NAMESPACE_OBSERVABILITY} \
  --version ${TEMPO_VERSION} \
  --values helm/tempo_helm_values_fixed.yaml \
  --timeout 10m \
  --wait

# Wait for Tempo to be ready
echo -e "${YELLOW}⏳ Waiting for Tempo to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tempo -n ${NAMESPACE_OBSERVABILITY} --timeout=300s

# Install OpenTelemetry Operator
echo -e "${YELLOW}🔧 Installing OpenTelemetry Operator...${NC}"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace ${NAMESPACE_OBSERVABILITY} \
  --create-namespace \
  --wait

# Create OpenTelemetry Instrumentation
echo -e "${YELLOW}🎛️ Creating OpenTelemetry Instrumentation...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: jenkins-instrumentation
  namespace: ${NAMESPACE_JENKINS}
spec:
  exporter:
    endpoint: http://tempo.${NAMESPACE_OBSERVABILITY}.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
    - jaeger
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
    env:
      - name: OTEL_SERVICE_NAME
        value: jenkins-master
      - name: OTEL_RESOURCE_ATTRIBUTES
        value: service.name=jenkins-master,service.version=2.504.3,deployment.environment=production
      - name: OTEL_INSTRUMENTATION_JENKINS_ENABLED
        value: "true"
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
    env:
      - name: OTEL_SERVICE_NAME
        value: jenkins-agent
EOF

# Apply Jenkins OpenTelemetry configuration
echo -e "${YELLOW}⚙️ Applying Jenkins OpenTelemetry configuration...${NC}"
kubectl apply -f jenkins-instrumentation/jenkins-otel-config.yaml

# Configure Grafana datasources
echo -e "${YELLOW}📊 Configuring Grafana datasources...${NC}"
kubectl apply -f grafana-config/tempo-datasources.yaml

# Wait for datasources to be applied
sleep 10

# Import Grafana dashboard
echo -e "${YELLOW}📈 Importing Jenkins tracing dashboard...${NC}"

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret -n ${NAMESPACE_OBSERVABILITY} grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
GRAFANA_URL="http://135.236.73.36"

# Import dashboard using API
curl -X POST \
  ${GRAFANA_URL}/api/dashboards/db \
  -H "Content-Type: application/json" \
  -u admin:${GRAFANA_PASSWORD} \
  -d @grafana-config/jenkins-tracing-dashboard.json

# Create service monitor for Tempo
echo -e "${YELLOW}📡 Creating Tempo service monitor...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tempo
  namespace: ${NAMESPACE_OBSERVABILITY}
  labels:
    app.kubernetes.io/name: tempo
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: tempo
  endpoints:
  - port: http-metrics
    interval: 30s
    path: /metrics
EOF

# Get service information
echo -e "${YELLOW}📋 Getting service information...${NC}"
echo ""
echo -e "${GREEN}✅ Tempo Installation Complete!${NC}"
echo ""
echo "🔍 Service Endpoints:"
echo "===================="

# Tempo services
kubectl get svc -n ${NAMESPACE_OBSERVABILITY} -l app.kubernetes.io/name=tempo

echo ""
echo "🎯 Access Information:"
echo "====================="
echo -e "Grafana Dashboard: ${BLUE}${GRAFANA_URL}${NC}"
echo -e "Grafana Username: ${YELLOW}admin${NC}"
echo -e "Grafana Password: ${YELLOW}${GRAFANA_PASSWORD}${NC}"
echo ""

# Port forward commands
echo "🔧 Port Forward Commands (if needed):"
echo "====================================="
echo "# Tempo Query (for direct API access)"
echo "kubectl port-forward -n ${NAMESPACE_OBSERVABILITY} svc/tempo 3200:3200"
echo ""
echo "# Jaeger-compatible endpoint"
echo "kubectl port-forward -n ${NAMESPACE_OBSERVABILITY} svc/tempo 16686:3200"
echo ""

# Instructions for Jenkins configuration
echo -e "${BLUE}📖 Next Steps:${NC}"
echo "=============="
echo "1. Restart Jenkins Master to apply OpenTelemetry instrumentation:"
echo "   kubectl rollout restart statefulset/jenkins-master -n ${NAMESPACE_JENKINS}"
echo ""
echo "2. Install Jenkins OpenTelemetry Plugin:"
echo "   - Go to Jenkins > Manage Jenkins > Manage Plugins"
echo "   - Install 'OpenTelemetry' plugin"
echo ""
echo "3. Configure Jenkins OpenTelemetry:"
echo "   - Go to Jenkins > Manage Jenkins > Configure System"
echo "   - Find 'OpenTelemetry' section"
echo "   - Set Endpoint: http://tempo.${NAMESPACE_OBSERVABILITY}.svc.cluster.local:4317"
echo ""
echo "4. Access Grafana Dashboard:"
echo "   - Go to ${GRAFANA_URL}"
echo "   - Navigate to 'Jenkins Master-Pod Distributed Tracing' dashboard"
echo ""
echo "5. Verify tracing is working:"
echo "   - Run a Jenkins job"
echo "   - Check Grafana for traces"
echo "   - Correlate logs with traces using trace IDs"
echo ""

# Test connectivity
echo -e "${YELLOW}🧪 Testing Tempo connectivity...${NC}"
kubectl run tempo-test --rm -i --tty --image=curlimages/curl -- \
  curl -s http://tempo.${NAMESPACE_OBSERVABILITY}.svc.cluster.local:3200/ready

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tempo is ready and accessible${NC}"
else
    echo -e "${YELLOW}⚠️ Tempo may still be starting up, please wait a few minutes${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Jenkins Master-Pod Distributed Tracing Setup Complete!${NC}"
echo ""
echo "You can now:"
echo "• View distributed traces in Grafana"
echo "• Correlate Jenkins Master failures with Pod logs"
echo "• Analyze job execution paths across spot workers"
echo "• Monitor service dependencies and communication"
echo ""
echo "Happy tracing! 🕵️‍♂️"
