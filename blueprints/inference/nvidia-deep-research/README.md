# NVIDIA AI-Q Research Assistant Blueprint - Application Deployment

This guide covers the application deployment steps for the NVIDIA AI-Q Research Assistant Blueprint on EKS

## Prerequisites

Before proceeding with application deployment, ensure the following infrastructure is deployed:

✅ **EKS Cluster** - Deployed with GPU node groups  
✅ **GPU Nodes**  
✅ **NVIDIA GPU Drivers** - Pre-installed  
✅ **OpenSearch Serverless** - Collection and IRSA service account configured  
✅ **EBS CSI Driver** - For persistent storage  
✅ **AWS Load Balancer Controller** - For external service access  

**Tools Required:**
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) - Kubernetes command-line tool
- [Helm](https://helm.sh/docs/intro/install/) - Kubernetes package manager
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) - Configured with credentials
- [NGC API Key](https://org.ngc.nvidia.com/setup/personal-keys) - For accessing NVIDIA container registry
- [Tavily API Key](https://tavily.com/) - For AIRA web search capabilities

## Table of Contents

- [Getting Started](#getting-started)
- [Step 1: Configure kubectl](#step-1-configure-kubectl)
- [Step 2: Set Environment Variables](#step-2-set-environment-variables)
- [Step 3: Verify Cluster is Ready](#step-3-verify-cluster-is-ready)
- [Step 4: Configure Karpenter NodePool Limits](#step-4-configure-karpenter-nodepool-limits)
- [NVIDIA RAG Blueprint Deployment](#nvidia-rag-blueprint-deployment)
  - [Step 5: Integrate OpenSearch and Build Docker Images](#step-5-integrate-opensearch-and-build-docker-images)
  - [Step 6: Deploy RAG Blueprint with OpenSearch](#step-6-deploy-rag-blueprint-with-opensearch)
  - [Step 7: Configure Load Balancers](#step-7-configure-load-balancers)
  - [Step 8: Verify RAG Deployment](#step-8-verify-rag-deployment)
- [AI-Q Components Deployment](#ai-q-components-deployment)
  - [Step 9: Setup Helm Repositories](#step-9-setup-helm-repositories)
  - [Step 10: Deploy AIRA Components](#step-10-deploy-aira-components)
  - [Step 11: Configure AIRA Load Balancer](#step-11-configure-aira-load-balancer)
  - [Step 12: Verify AIRA Deployment](#step-12-verify-aira-deployment)
  - [Step 13: Data Ingestion from S3](#step-13-data-ingestion-from-s3)
  - [Step 14: Access Services](#step-14-access-services)
- [Optional: Access RAG Frontend](#optional-access-rag-frontend)
- [Cleanup](#cleanup)
- [Additional Resources](#additional-resources)

## Architecture

The NVIDIA AI-Q Research Assistant Blueprint integrates multiple AI components to deliver an intelligent research assistant with RAG capabilities:

![AI-Q Architecture on AWS](imgs/aiq-aws.png)

## Getting Started

Navigate to the blueprint directory to begin the application deployment:

```bash
# Clone the repository if you haven't already
git clone https://github.com/awslabs/ai-on-eks.git
cd ai-on-eks

# Navigate to the NVIDIA AI-Q Blueprint directory
cd blueprints/inference/nvidia-deep-research

# All commands in this guide should be run from this directory
pwd  # Should show: .../ai-on-eks/blueprints/inference/nvidia-deep-research
```

## Step 1: Configure kubectl

Configure kubectl to access your EKS cluster:

```bash
# Set your cluster details
export CLUSTER_NAME="nvidia-deep-research"  # Or your cluster name
export REGION="us-west-2"                   # Or your region

# Configure kubectl
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
```

## Step 2: Set Environment Variables

```bash
# Get AWS Account ID
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)


# OpenSearch Configuration (should match Terraform deployment)
export OPENSEARCH_SERVICE_ACCOUNT="opensearch-access-sa"
export OPENSEARCH_NAMESPACE="nv-nvidia-blueprint-rag"
export COLLECTION_NAME="osv-vector-dev"

# Get OpenSearch endpoint from Terraform output
cd ../../../infra/nvidia-deep-research/terraform/_LOCAL
export OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint)
cd -

echo "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"

# NGC API Key (replace with your actual key)
export NGC_API_KEY="<YOUR_NGC_API_KEY>"

# Tavily API Key for AIRA (replace with your actual key)
export TAVILY_API_KEY="<YOUR_TAVILY_API_KEY>"
```

## Step 3: Verify Cluster is Ready

Verify all GPU nodes are healthy:

```bash
# Check cluster status
kubectl get nodes

# Verify Karpenter is running
kubectl get pods -n karpenter

# Check available Karpenter NodePools
kubectl get nodepools
```

> **Note**: GPU nodes will be automatically provisioned by Karpenter when you deploy GPU workloads. You don't need to pre-create static GPU node groups.

## Step 4: Configure Karpenter NodePool Limits

Increase the memory limit for the G5 GPU NodePool to accommodate multiple large models:

```bash
kubectl patch nodepool g5-gpu-karpenter --type='json' -p='[{"op": "replace", "path": "/spec/limits/memory", "value": "2000Gi"}]'
```

This command increases the g5-gpu-karpenter NodePool's memory limit from 1000Gi to 2000Gi, allowing Karpenter to provision sufficient GPU nodes for all the models being deployed.

## NVIDIA RAG Blueprint Deployment

### Step 5: Integrate OpenSearch and Build Docker Images

Clone the RAG source code and add OpenSearch implementation:

```bash
# Clone RAG source code
git clone -b v2.3.0 https://github.com/NVIDIA-AI-Blueprints/rag.git rag

# Download example OpenSearch implementation from NVIDIA repository
COMMIT_HASH="fe6ec2e5c53b6134d1743fc975e5eef56e660b04"
curl -L https://github.com/NVIDIA/nim-deploy/archive/${COMMIT_HASH}.tar.gz | tar xz --strip=5 nim-deploy-${COMMIT_HASH}/cloud-service-providers/aws/blueprints/deep-research-blueprint-eks/opensearch
```

Integrate OpenSearch support into RAG source:

```bash
# Copy OpenSearch implementation into RAG source
cp -r opensearch/vdb/opensearch rag/src/nvidia_rag/utils/vdb/
cp opensearch/main.py rag/src/nvidia_rag/ingestor_server/main.py 
cp opensearch/vdb/__init__.py rag/src/nvidia_rag/utils/vdb/__init__.py
cp opensearch/pyproject.toml rag/pyproject.toml
```

Build and push OpenSearch-enabled Docker images to ECR:

```bash
# Login to NGC registry
docker login nvcr.io  # username: $oauthtoken, password: NGC API Key

# Login to ECR
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Build and push OpenSearch-enabled RAG images to ECR
./opensearch/build-opensearch-images.sh
```

This script will build Docker images with OpenSearch integration, tag them with version `2.3.0-opensearch`, and push to your ECR registry

### Step 6: Deploy RAG Blueprint with OpenSearch

Deploy the RAG Blueprint using the OpenSearch-enabled images and IRSA service account:

> **Note**: The `helm/rag-values-os.yaml` file is pre-configured with Karpenter labels for automatic g5 instance provisioning. No manual node selection required.

```bash
# Set deployment variables
export ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
export IMAGE_TAG="2.3.0-opensearch"

# Deploy RAG with OpenSearch configuration
helm upgrade --install rag -n nv-nvidia-blueprint-rag \
  https://helm.ngc.nvidia.com/nvidia/blueprint/charts/nvidia-blueprint-rag-v2.3.0.tgz \
  --username '$oauthtoken' \
  --password "${NGC_API_KEY}" \
  --create-namespace \
  --set imagePullSecret.password=$NGC_API_KEY \
  --set ngcApiSecret.password=$NGC_API_KEY \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$OPENSEARCH_SERVICE_ACCOUNT \
  --set image.repository="${ECR_REGISTRY}/nvidia-rag-server" \
  --set image.tag="${IMAGE_TAG}" \
  --set ingestor-server.image.repository="${ECR_REGISTRY}/nvidia-rag-ingestor" \
  --set ingestor-server.image.tag="${IMAGE_TAG}" \
  --set envVars.APP_VECTORSTORE_URL="${OPENSEARCH_ENDPOINT}" \
  --set envVars.APP_VECTORSTORE_AWS_REGION="${REGION}" \
  --set ingestor-server.envVars.APP_VECTORSTORE_URL="${OPENSEARCH_ENDPOINT}" \
  --set ingestor-server.envVars.APP_VECTORSTORE_AWS_REGION="${REGION}" \
  -f helm/rag-values-os.yaml

# Patch ingestor-server deployment to use IRSA service account
kubectl patch deployment ingestor-server -n nv-nvidia-blueprint-rag \
  -p "{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$OPENSEARCH_SERVICE_ACCOUNT\"}}}}"
```

This deploys:
- **49B Nemotron Model** (8 GPUs) - Karpenter will provision g5.48xlarge
- **Embedding & Reranking Models** (1 GPU each) - Karpenter will provision g5.xlarge through g5.12xlarge
- **Data Ingestion Models** (1 GPU each) - Karpenter will provision g5.xlarge through g5.12xlarge
- **RAG Server** with OpenSearch Serverless integration
- **Frontend** for user interaction

### Step 7: Configure Load Balancers

Expose RAG services via AWS Network Load Balancers:

```bash
# Patch frontend service to LoadBalancer
kubectl patch svc rag-frontend -n nv-nvidia-blueprint-rag -p '{
  "spec": {
    "type": "LoadBalancer"
  },
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "tcp"
    }
  }
}'

# Patch ingestor-server service to LoadBalancer
kubectl patch svc ingestor-server -n nv-nvidia-blueprint-rag -p '{
  "spec": {
    "type": "LoadBalancer"
  },
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "tcp"
    }
  }
}'
```

### Step 8: Verify RAG Deployment

Check that all RAG components are running:

```bash
# Check all pods in RAG namespace
kubectl get all -n nv-nvidia-blueprint-rag

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=rag -n nv-nvidia-blueprint-rag --timeout=600s

# Check specific components
kubectl get pods -n nv-nvidia-blueprint-rag -o wide | grep -E "NAME|nim-llm|rag-server|ingestor|embedding|reranking"

# Verify service accounts are using IRSA
kubectl get pod -n nv-nvidia-blueprint-rag -l app.kubernetes.io/component=rag-server -o jsonpath='{.items[0].spec.serviceAccountName}' | xargs -I {} echo "RAG Server service account: {}"
kubectl get pod -n nv-nvidia-blueprint-rag -l app=ingestor-server -o jsonpath='{.items[0].spec.serviceAccountName}' | xargs -I {} echo "Ingestor Server service account: {}"
```

## AI-Q Components Deployment

### Step 9: Setup Helm Repositories

Add required Helm repositories for AIRA deployment:

```bash
# Add NGC Helm repositories (required for AIRA dependencies)
helm repo add nim https://helm.ngc.nvidia.com/nim \
  --username='$oauthtoken' \
  --password="${NGC_API_KEY}" \
  --force-update

helm repo add nvidia-nim https://helm.ngc.nvidia.com/nim/nvidia/ \
  --username='$oauthtoken' \
  --password="${NGC_API_KEY}" \
  --force-update

helm repo add nemo-microservices https://helm.ngc.nvidia.com/nvidia/nemo-microservices \
  --username='$oauthtoken' \
  --password="${NGC_API_KEY}" \
  --force-update

# Add observability repositories (optional)
helm repo add zipkin https://zipkin.io/zipkin-helm
helm repo add opentelemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update all repositories
helm repo update

# Update dependencies for the local AIRA chart
helm dependency update helm/aiq-aira
```

### Step 10: Deploy AIRA Components

Deploy the AI-Q Research Assistant:

> **Note**: The `helm/aira-values.eks.yaml` file is pre-configured with Karpenter labels to automatically provision a g5.48xlarge instance for the 70B model (8 GPUs).

```bash
# Verify TAVILY_API_KEY is set
echo "Tavily API Key: ${TAVILY_API_KEY:0:10}..."

# Deploy AIRA using local Helm chart
helm upgrade --install aira helm/aiq-aira \
  -n nv-aira --create-namespace \
  -f helm/aira-values.eks.yaml \
  --set imagePullSecret.password="$NGC_API_KEY" \
  --set ngcApiSecret.password="$NGC_API_KEY" \
  --set config.tavily_api_key="$TAVILY_API_KEY"
```

This deploys:
- **AIRA Backend**: Research assistant functionality
- **70B Instruct Model**: For report generation (8 GPUs) - Karpenter will provision g5.48xlarge
- **NGINX Proxy**: Routes requests to RAG and AIRA services
- **Frontend**: User interface

Karpenter will provision an additional g5.48xlarge instance for the AI-Q 70B model.

### Step 11: Configure AIRA Load Balancer

Expose AIRA frontend via AWS Network Load Balancer:

```bash
# Patch AIRA frontend service to LoadBalancer
kubectl patch svc aira-aira-frontend -n nv-aira -p '{
  "spec": {
    "type": "LoadBalancer"
  },
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "tcp"
    }
  }
}'
```

### Step 12: Verify AIRA Deployment

Check that all AIRA components are running:

```bash
# Check all AIRA components
kubectl get all -n nv-aira

# Wait for all components to be ready
kubectl wait --for=condition=ready pod -l app=aira -n nv-aira --timeout=300s

# Check pod distribution across g5 nodes
kubectl get pods -n nv-aira -o wide
```

### Step 13: Data Ingestion from S3

Ingest documents from an S3 bucket into the OpenSearch vector database using the provided batch ingestion script.

**Prerequisites**: This step assumes you have an S3 bucket with documents you want to process and query.

**Supported File Types**: The RAG pipeline supports multi-modal document ingestion including:
- PDF documents
- Text files (.txt, .md)
- Images (.jpg, .png)
- Office documents (.docx, .pptx)
- HTML files

The NeMo Retriever microservices will automatically extract text, tables, charts, and images from these documents.

**Batch Ingestion from S3:**

```bash
# Set required environment variables
export S3_BUCKET_NAME="your-pdf-bucket-name" # Replace with your S3 bucket name
export INGESTOR_URL=$(kubectl get svc ingestor-server -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Optional: Configure additional settings
export S3_PREFIX=""  # Optional: folder path (e.g., "documents/")
export RAG_COLLECTION_NAME="multimodal_data"
export UPLOAD_BATCH_SIZE="100"

# Run the data ingestion script
./data_ingestion.sh
```

> **Note**: For testing purposes, you can also upload individual documents directly through the RAG or AIRA frontend UI in the next step. For more details on script options and advanced usage, see the [batch_ingestion.py documentation](https://github.com/NVIDIA-AI-Blueprints/rag/tree/v2.3.0/scripts).

### Step 14: Access Services

Get the Frontend URL:

```bash
echo "AIRA Frontend: http://$(kubectl get svc aira-aira-frontend -n nv-aira -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):3001"
```

> **Note**: The load balancer endpoint may take up to 5 minutes to be provisioned and become accessible after deployment.

Access the application:
- **AIRA Research Assistant**: Generate comprehensive research reports

## Optional: Access RAG Frontend

If you want to test the RAG application directly, you can access the frontend:

### Get Service URLs

```bash
# Get the RAG frontend Load Balancer URL
export RAG_FRONTEND_URL=$(kubectl get svc rag-frontend -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "RAG Frontend: http://$RAG_FRONTEND_URL:3000"

# Get the Ingestor server Load Balancer URL
export INGESTOR_URL=$(kubectl get svc ingestor-server -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Ingestor API: http://$INGESTOR_URL:8082"
```

Open your browser and navigate to:
- **RAG Frontend**: `http://<RAG_FRONTEND_URL>:3000`
- **Ingestor API Docs**: `http://<INGESTOR_URL>:8082/docs`

## Observability

### Expose Monitoring Services

Expose observability services via AWS Network Load Balancers for external access:

**RAG Observability (Zipkin & Grafana):**

```bash
# Expose Zipkin for distributed tracing
kubectl patch svc rag-zipkin -n nv-nvidia-blueprint-rag -p '{
  "spec": {
    "type": "LoadBalancer"
  },
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "tcp"
    }
  }
}'

# Expose Grafana for metrics and dashboards
kubectl patch svc rag-grafana -n nv-nvidia-blueprint-rag -p '{
  "spec": {
    "type": "LoadBalancer"
  },
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "tcp"
    }
  }
}'
```

**AI-Q Observability (Phoenix):**

```bash
# Expose Phoenix for AI-Q tracing
kubectl patch svc aira-phoenix -n nv-aira -p '{
  "spec": {
    "type": "LoadBalancer"
  },
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol": "tcp"
    }
  }
}'
```

**Access Monitoring UIs:**

```bash
# Get Zipkin URL for RAG tracing
echo "Zipkin UI: http://$(kubectl get svc rag-zipkin -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9411"

# Get Grafana URL for RAG metrics
echo "Grafana UI: http://$(kubectl get svc rag-grafana -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):80"

# Get Phoenix URL for AI-Q tracing
echo "Phoenix UI: http://$(kubectl get svc aira-phoenix -n nv-aira -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):6006"
```

> **Note**: For detailed information on using these observability tools, refer to:
> - [Viewing Traces in Zipkin](https://github.com/NVIDIA-AI-Blueprints/rag/blob/main/docs/observability.md#view-traces-in-zipkin)
> - [Viewing Metrics in Grafana Dashboard](https://github.com/NVIDIA-AI-Blueprints/rag/blob/main/docs/observability.md#view-metrics-in-grafana)

## Cleanup

### Uninstall Applications

```bash
# Uninstall AIRA
helm uninstall aira -n nv-aira
kubectl delete namespace nv-aira

# Uninstall RAG Blueprint
helm uninstall rag -n nv-nvidia-blueprint-rag
kubectl delete namespace nv-nvidia-blueprint-rag
```

### Clean Up Infrastructure

To remove the EKS cluster and all infrastructure:

```bash
# From the blueprints directory, navigate to infra
cd ../../../infra/nvidia-deep-research

# Set OpenSearch to disabled in blueprint.tfvars (optional)
# enable_opensearch_serverless = false

# Run the cleanup script (recommended - handles dependencies)
./cleanup.sh
```

> **Warning**: This will permanently delete all data and resources. Backup important data before proceeding.

## Additional Resources

- [NVIDIA AI-Q Blueprint GitHub](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant)
- [NVIDIA RAG Blueprint Documentation](https://docs.nvidia.com/ai-enterprise/rag/)
- [OpenSearch Serverless Documentation](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)

