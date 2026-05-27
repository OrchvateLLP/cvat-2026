#!/bin/bash

# Azure AKS Deployment Script for CVAT
# Resource Group: cvat-aks
# Location: Australia East (australiaeast)

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting CVAT AKS Deployment...${NC}"

# Variables
RESOURCE_GROUP="cvat-aks"
LOCATION="australiaeast"
CLUSTER_NAME="cvat-aks-cluster"
VM_SIZE="Standard_D4s_v3"
MIN_NODES=2
MAX_NODES=10

# 1. Create Resource Group
echo -e "${YELLOW}Step 1: Creating resource group '${RESOURCE_GROUP}' in ${LOCATION}...${NC}"
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}"

echo -e "${GREEN}✓ Resource group created successfully${NC}"

# 2. Create AKS Cluster with Auto-scaling
echo -e "${YELLOW}Step 2: Creating AKS cluster with auto-scaling enabled...${NC}"
az aks create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin azure \
  --min-count "${MIN_NODES}" \
  --max-count "${MAX_NODES}" \
  --enable-cluster-autoscale \
  --node-vm-size "${VM_SIZE}" \
  --zones 1 2 3 \
  --generate-ssh-keys

echo -e "${GREEN}✓ AKS cluster created successfully${NC}"

# 3. Get cluster credentials
echo -e "${YELLOW}Step 3: Getting cluster credentials...${NC}"
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --overwrite-existing

echo -e "${GREEN}✓ Cluster credentials configured${NC}"

# 4. Verify cluster connection
echo -e "${YELLOW}Step 4: Verifying cluster connection...${NC}"
kubectl cluster-info
kubectl get nodes

echo -e "${GREEN}✓ Successfully connected to cluster${NC}"

# 5. Create storage class for Azure Managed Disks
echo -e "${YELLOW}Step 5: Creating Azure Managed Disks storage class...${NC}"
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

# 6. Create CVAT namespace
echo -e "${YELLOW}Step 6: Creating cvat namespace...${NC}"
kubectl create namespace cvat || echo "Namespace already exists"

echo -e "${GREEN}✓ Namespace created${NC}"

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}AKS Cluster Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add Helm repositories:"
echo "   helm repo add bitnami https://charts.bitnami.com/bitnami"
echo "   helm repo add nuclio https://nuclio.github.io/nuclio/charts"
echo "   helm repo add vector https://helm.vector.dev"
echo "   helm repo add grafana https://grafana.github.io/helm-charts"
echo "   helm repo add traefik https://helm.traefik.io/traefik"
echo "   helm repo update"
echo ""
echo "2. Update Helm dependencies in helm-chart directory:"
echo "   cd ../helm-chart && helm dependency update"
echo ""
echo "3. Deploy CVAT using Helm:"
echo "   cd ../azure-deployment"
echo "   helm install cvat ../helm-chart --namespace cvat --values azure-values.yaml"
echo ""
echo -e "${YELLOW}Cluster Information:${NC}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location: ${LOCATION}"
echo "Cluster Name: ${CLUSTER_NAME}"
echo "VM Size: ${VM_SIZE}"
echo "Node Scaling: ${MIN_NODES} - ${MAX_NODES} nodes"
