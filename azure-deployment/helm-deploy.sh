#!/bin/bash

# Helm Deployment Script for CVAT
# Deploys CVAT to AKS with Helm chart

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting CVAT Helm Deployment...${NC}"

# Check if kubectl is connected
echo -e "${YELLOW}Checking kubectl connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Not connected to Kubernetes cluster${NC}"
    echo "Run './aks-setup.sh' first or configure kubeconfig"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

# Variables
NAMESPACE="cvat"
RELEASE_NAME="cvat"
HELM_CHART_PATH="../helm-chart"

# 1. Add Helm Repositories
echo -e "${YELLOW}Step 1: Adding Helm repositories...${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo add nuclio https://nuclio.github.io/nuclio/charts || true
helm repo add vector https://helm.vector.dev || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo add traefik https://helm.traefik.io/traefik || true
helm repo update

echo -e "${GREEN}✓ Helm repositories added${NC}"

# 2. Update Chart Dependencies
echo -e "${YELLOW}Step 2: Updating Helm chart dependencies...${NC}"
if [ -d "${HELM_CHART_PATH}" ]; then
    cd "${HELM_CHART_PATH}"
    helm dependency update
    cd - > /dev/null
    echo -e "${GREEN}✓ Chart dependencies updated${NC}"
else
    echo -e "${RED}✗ Helm chart directory not found at ${HELM_CHART_PATH}${NC}"
    exit 1
fi

# 3. Create namespace if it doesn't exist
echo -e "${YELLOW}Step 3: Creating namespace '${NAMESPACE}'...${NC}"
kubectl create namespace "${NAMESPACE}" 2>/dev/null || echo "Namespace already exists"
echo -e "${GREEN}✓ Namespace ready${NC}"

# 4. Create storage classes
echo -e "${YELLOW}Step 4: Creating storage classes...${NC}"
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-managed-premium
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_LRS
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-managed-standard
provisioner: disk.csi.azure.com
parameters:
  skuname: Standard_LRS
volumeBindingMode: WaitForFirstConsumer
EOF
echo -e "${GREEN}✓ Storage classes created${NC}"

# 5. Deploy CVAT with Helm
echo -e "${YELLOW}Step 5: Deploying CVAT with Helm...${NC}"

# Check if release exists
if helm list -n "${NAMESPACE}" | grep -q "${RELEASE_NAME}"; then
    echo -e "${YELLOW}Upgrading existing release...${NC}"
    helm upgrade "${RELEASE_NAME}" "${HELM_CHART_PATH}" \
      --namespace "${NAMESPACE}" \
      --values azure-values.yaml \
      --wait \
      --timeout 10m
    echo -e "${GREEN}✓ CVAT upgraded successfully${NC}"
else
    echo -e "${YELLOW}Installing new release...${NC}"
    helm install "${RELEASE_NAME}" "${HELM_CHART_PATH}" \
      --namespace "${NAMESPACE}" \
      --values azure-values.yaml \
      --wait \
      --timeout 10m
    echo -e "${GREEN}✓ CVAT installed successfully${NC}"
fi

# 6. Display deployment information
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}CVAT Helm Deployment Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Deployment Information:${NC}"
echo "Namespace: ${NAMESPACE}"
echo "Release Name: ${RELEASE_NAME}"
echo ""
echo -e "${YELLOW}Check Deployment Status:${NC}"
echo "kubectl get pods -n ${NAMESPACE}"
echo "kubectl get svc -n ${NAMESPACE}"
echo ""
echo -e "${YELLOW}View Logs:${NC}"
echo "kubectl logs -f deployment/cvat-server -n ${NAMESPACE}"
echo ""
echo -e "${YELLOW}Port Forwarding (Access CVAT):${NC}"
echo "kubectl port-forward -n ${NAMESPACE} svc/cvat-frontend 8000:8000"
echo ""
echo -e "${YELLOW}Next: Apply auto-scaling policies${NC}"
echo "kubectl apply -f autoscaling.yaml -n ${NAMESPACE}"
echo ""
echo -e "${YELLOW}Waiting for all pods to be ready...${NC}"
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=cvat \
  -n "${NAMESPACE}" \
  --timeout=300s || echo "Some pods may still be initializing..."

echo -e "${GREEN}✓ Deployment complete!${NC}"
