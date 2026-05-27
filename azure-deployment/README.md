# CVAT Deployment on Azure AKS (Australia East)

This directory contains scripts and configuration files for deploying CVAT on Azure Kubernetes Service (AKS) with auto-scaling capabilities.

## Prerequisites

- Azure CLI (`az`) installed and configured
- kubectl installed and configured
- Helm 3.x installed
- Azure subscription with appropriate permissions

## Quick Start

### 1. Create AKS Cluster

```bash
chmod +x aks-setup.sh
./aks-setup.sh
```

This script will:
- Create a resource group named `cvat-aks` in `australiaeast` location
- Create an AKS cluster with auto-scaling enabled (2-10 nodes)
- Configure storage classes for Azure Managed Disks
- Create the `cvat` namespace

**Cluster Configuration:**
- Resource Group: `cvat-aks`
- Location: `australiaeast` (Australia East)
- Cluster Name: `cvat-aks-cluster`
- VM Size: `Standard_D4s_v3`
- Node Scaling: 2-10 nodes
- Availability Zones: 1, 2, 3

### 2. Deploy CVAT with Helm

```bash
chmod +x helm-deploy.sh
./helm-deploy.sh
```

This script will:
- Add required Helm repositories
- Update chart dependencies
- Deploy CVAT using the `azure-values.yaml` configuration
- Display deployment status

### 3. Configure Pod Auto-scaling

```bash
kubectl apply -f autoscaling.yaml -n cvat
```

This configures horizontal pod autoscalers (HPA) for:
- CVAT Server (3-10 replicas)
- Export Worker (2-8 replicas)
- Import Worker (2-8 replicas)
- Chunks Worker (2-8 replicas)
- Frontend (2-5 replicas)
- OPA (2-4 replicas)

## Configuration Files

### `aks-setup.sh`
Sets up the Azure AKS infrastructure in the `australiaeast` region.

**Key Configuration:**
```bash
RESOURCE_GROUP="cvat-aks"
LOCATION="australiaeast"
CLUSTER_NAME="cvat-aks-cluster"
VM_SIZE="Standard_D4s_v3"
MIN_NODES=2
MAX_NODES=10
```

### `azure-values.yaml`
Helm values configuration tailored for Azure AKS deployment.

**Key Features:**
- Multiple replicas for high availability
- Resource requests and limits for each component
- Pod anti-affinity for distributed scheduling
- Azure Managed Disks storage classes
- Pre-configured security and persistence settings

**Modifiable Settings:**
- PostgreSQL password: `changeme_cvat_postgresql`
- Redis password: `changeme_cvat_redis`
- ClickHouse password: `changeme_clickhouse_user`

⚠️ **IMPORTANT:** Change all default passwords before deploying to production!

### `helm-deploy.sh`
Automates the Helm deployment process.

**What it does:**
1. Adds all required Helm repositories
2. Updates chart dependencies
3. Creates the cvat namespace
4. Configures storage classes
5. Deploys CVAT using Helm
6. Displays deployment status

### `autoscaling.yaml`
Defines HorizontalPodAutoscaler (HPA) policies for automatic pod scaling.

**Scaling Policies:**
- **Server**: 3-10 replicas (70% CPU, 80% memory)
- **Export Worker**: 2-8 replicas (75% CPU, 80% memory)
- **Import Worker**: 2-8 replicas (75% CPU, 80% memory)
- **Chunks Worker**: 2-8 replicas (75% CPU, 80% memory)
- **Frontend**: 2-5 replicas (80% CPU, 85% memory)
- **OPA**: 2-4 replicas (80% CPU, 85% memory)

## Manual Deployment Steps

If you prefer to deploy manually:

### Step 1: Create Resource Group
```bash
az group create \
  --name cvat-aks \
  --location australiaeast
```

### Step 2: Create AKS Cluster
```bash
az aks create \
  --resource-group cvat-aks \
  --name cvat-aks-cluster \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin azure \
  --enable-cluster-autoscaling \
  --min-count 2 \
  --max-count 10 \
  --node-vm-size Standard_D4s_v3 \
  --zones 1 2 3 \
  --generate-ssh-keys
```

### Step 3: Get Cluster Credentials
```bash
az aks get-credentials \
  --resource-group cvat-aks \
  --name cvat-aks-cluster
```

### Step 4: Add Helm Repositories
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add nuclio https://nuclio.github.io/nuclio/charts
helm repo add vector https://helm.vector.dev
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
```

### Step 5: Update Chart Dependencies
```bash
cd helm-chart
helm dependency update
cd ..
```

### Step 6: Deploy CVAT
```bash
kubectl create namespace cvat
helm install cvat helm-chart \
  --namespace cvat \
  --values azure-deployment/azure-values.yaml
```

### Step 7: Apply Auto-scaling
```bash
kubectl apply -f azure-deployment/autoscaling.yaml
```

## Monitoring and Management

### Check Deployment Status
```bash
# Check pods
kubectl get pods -n cvat

# Check services
kubectl get svc -n cvat

# Check persistent volumes
kubectl get pvc -n cvat

# Check autoscalers
kubectl get hpa -n cvat
```

### View Logs
```bash
# Server logs
kubectl logs -f deployment/cvat-server -n cvat

# Frontend logs
kubectl logs -f deployment/cvat-frontend -n cvat

# Worker logs
kubectl logs -f deployment/cvat-worker-export -n cvat
```

### Port Forwarding
```bash
# Frontend access
kubectl port-forward -n cvat svc/cvat-frontend 8000:8000

# Backend API access
kubectl port-forward -n cvat svc/cvat 8080:8080

# Grafana analytics dashboard
kubectl port-forward -n cvat svc/grafana 3000:3000
```

### Scale Deployments Manually
```bash
# Scale server replicas
kubectl scale deployment cvat-server --replicas=5 -n cvat

# Scale export worker
kubectl scale deployment cvat-worker-export --replicas=5 -n cvat
```

### Watch Real-time Status
```bash
kubectl get pods -n cvat -w
```

### Get Resource Usage
```bash
kubectl top nodes
kubectl top pods -n cvat
```

## Networking and Ingress

### Configure Ingress for External Access

Create `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cvat-ingress
  namespace: cvat
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - cvat.yourdomain.com
    secretName: cvat-tls
  rules:
  - host: cvat.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cvat-frontend
            port:
              number: 8000
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: cvat
            port:
              number: 8080
```

Apply:
```bash
kubectl apply -f ingress.yaml
```

## Persistent Storage

The deployment uses Azure Managed Disks for persistent storage:

- **azure-managed-premium**: SSD storage for databases and critical data
- **azure-managed-standard**: Standard HDD storage for cache

Storage allocation:
- Backend data: 100Gi (Premium)
- KVRocks cache: 100Gi (Premium)
- PostgreSQL: 50Gi (Premium)
- ClickHouse: 50Gi (Premium)
- Redis: 10Gi (Standard)

## Security Considerations

⚠️ **Important Security Notes:**

1. **Change Default Passwords**: Update all default passwords in `azure-values.yaml`
   - `changeme_cvat_postgresql`
   - `changeme_cvat_redis`
   - `changeme_clickhouse_user`

2. **Enable RBAC**: The deployment uses service accounts with role-based access control

3. **Network Policies**: Consider implementing Kubernetes network policies

4. **Secret Management**: Store sensitive data in Azure Key Vault

5. **TLS/SSL**: Configure TLS for external access

## Updating and Maintenance

### Upgrade CVAT
```bash
helm upgrade cvat helm-chart \
  --namespace cvat \
  --values azure-deployment/azure-values.yaml
```

### Rollback to Previous Version
```bash
helm rollback cvat -n cvat
```

### Check Helm Release History
```bash
helm history cvat -n cvat
```

## Troubleshooting

### Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n cvat

# Check events
kubectl get events -n cvat --sort-by='.lastTimestamp'
```

### Persistent Volume Issues
```bash
# Check PVC status
kubectl get pvc -n cvat

# Describe PVC
kubectl describe pvc <pvc-name> -n cvat
```

### Resource Constraints
```bash
# Check node resources
kubectl top nodes

# Check pod resource usage
kubectl top pods -n cvat
```

### Ingress Not Working
```bash
# Check ingress status
kubectl get ingress -n cvat

# Describe ingress
kubectl describe ingress cvat-ingress -n cvat
```

## Cost Optimization

- **Use Standard VMs for non-critical workloads**: Change `Standard_D4s_v3` if needed
- **Enable cluster autoscaling**: Automatically scales nodes based on demand
- **Use spot instances**: For non-critical workloads (add `--priority Spot`)
- **Monitor resource usage**: Use Azure Monitor and Kubernetes Dashboard
- **Set resource quotas**: Prevent resource waste

## Support and Documentation

- [CVAT Documentation](https://docs.cvat.ai/)
- [Azure AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## License

CVAT is licensed under the MIT License. See the LICENSE file in the repository root for details.
