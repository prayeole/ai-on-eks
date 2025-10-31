# NVIDIA Enterprise RAG & AI-Q Research Assistant - Application Deployment

This guide covers deployment of the NVIDIA Enterprise RAG Blueprint and AI-Q Research Assistant on Amazon EKS. Choose the deployment option that matches your use case.

## Deployment Options

This blueprint supports two deployment modes based on your use case:

**Option 1: Enterprise RAG Blueprint** (Steps 1-8)
- Deploy NVIDIA Enterprise RAG Blueprint with multi-modal document processing
- Includes NeMo Retriever microservices and OpenSearch integration
- Best for: Building custom RAG applications, document Q&A systems, knowledge bases

**Option 2: Full AI-Q Research Assistant** (Steps 1-13)
- Includes everything from Option 1 plus AI-Q components
- Adds automated research report generation with web search capabilities via Tavily API
- Best for: Comprehensive research tasks, automated report generation, web-augmented research

Both deployments include Karpenter autoscaling and enterprise security features. You can start with Option 1 and add AI-Q components later as your needs evolve.

## Prerequisites

Before proceeding with application deployment, ensure the following infrastructure is deployed:

✅ **EKS Cluster** - Deployed with GPU node groups
✅ **GPU Nodes**
✅ **NVIDIA GPU Drivers** - Pre-installed
✅ **OpenSearch Serverless** - Collection and Pod Identity service account configured
✅ **EBS CSI Driver** - For persistent storage
✅ **EKS Pod Identity Agent** - For secure AWS IAM access

**Tools Required:**
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) - Kubernetes command-line tool
- [Helm](https://helm.sh/docs/intro/install/) - Kubernetes package manager
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) - Configured with credentials
- **NGC API Key** - For accessing NVIDIA container registry. You must first sign up through one of these options:
  - **Option 1 (Quick Start):** [NVIDIA Developer Program](https://build.nvidia.com/) - Free account for POCs and development
  - **Option 2 (Production):** [NVIDIA AI Enterprise](https://aws.amazon.com/marketplace/pp/prodview-ozgjkov6vq3l6) - AWS Marketplace subscription for enterprise support
  - After signing up, generate your API key at: [NGC Personal Keys](https://org.ngc.nvidia.com/setup/personal-keys)
- [Tavily API Key](https://tavily.com/) - **Required for Option 2: Full AI-Q deployment (Steps 9-13).** Not needed for Option 1: Enterprise RAG deployment (Steps 1-8)

## Table of Contents

- [Getting Started](#getting-started)
- [Step 1: Configure kubectl](#step-1-configure-kubectl)
- [Step 2: Set Environment Variables](#step-2-set-environment-variables)
- [Step 3: Verify Cluster is Ready](#step-3-verify-cluster-is-ready)
- [Step 4: Configure Karpenter NodePool Limits](#step-4-configure-karpenter-nodepool-limits)
- [NVIDIA Enterprise RAG Blueprint Deployment](#nvidia-enterprise-rag-blueprint-deployment)
  - [Step 5: Integrate OpenSearch and Build Docker Images](#step-5-integrate-opensearch-and-build-docker-images)
  - [Step 6: Deploy Enterprise RAG Blueprint with OpenSearch](#step-6-deploy-enterprise-rag-blueprint-with-opensearch)
  - [Step 7: Setup Port Forwarding for RAG Services](#step-7-setup-port-forwarding-for-rag-services)
  - [Step 8: Verify RAG Deployment](#step-8-verify-rag-deployment)
- [AI-Q Components Deployment](#ai-q-components-deployment)
  - [Step 9: Deploy AIRA Components](#step-9-deploy-aira-components)
  - [Step 10: Setup Port Forwarding for AIRA Services](#step-10-setup-port-forwarding-for-aira-services)
  - [Step 11: Verify AIRA Deployment](#step-11-verify-aira-deployment)
  - [Step 12: Data Ingestion from S3](#step-12-data-ingestion-from-s3)
  - [Step 13: Access Services](#step-13-access-services)
- [Optional: Access RAG Frontend](#optional-access-rag-frontend)
- [Cleanup](#cleanup)
- [Additional Resources](#additional-resources)

## Architecture

The NVIDIA AI-Q Research Assistant Blueprint integrates multiple AI components to deliver an intelligent research assistant with RAG capabilities:

![AI-Q Architecture on AWS](imgs/aiq-aws.png)

### RAG Pipeline Architecture

The RAG pipeline processes documents through multiple specialized NIM microservices with OpenSearch Serverless integration:

![RAG Pipeline with OpenSearch](imgs/rag-opensearch.png)

**Key Components:**
- **Llama-3.3-Nemotron-Super-49B-v1.5**: Advanced reasoning model for query processing and generation
- **NeMo Retriever Microservices**: Multi-modal document ingestion and processing
- **OpenSearch Serverless**: Vector database with Pod Identity authentication
- **NIM Microservices**: Optimized inference containers for embeddings, reranking, and vision models

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
export OPENSEARCH_NAMESPACE="rag"
export COLLECTION_NAME="osv-vector-dev"

# Get OpenSearch endpoint from Terraform output
cd ../../../infra/nvidia-deep-research/terraform/_LOCAL
export OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint)
cd -

echo "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"

# NGC API Key (replace with your actual key)
export NGC_API_KEY="<YOUR_NGC_API_KEY>"

# Tavily API Key for AI-Q (required for Option 2 - Steps 9-13)
export TAVILY_API_KEY="<YOUR_TAVILY_API_KEY>"  # Skip if deploying Option 1 only (Steps 1-8)
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

## NVIDIA Enterprise RAG Blueprint Deployment

### Step 5: Integrate OpenSearch and Build Docker Images

Clone the RAG source code and add OpenSearch implementation:

```bash
# Clone RAG source code
git clone -b v2.3.0 https://github.com/NVIDIA-AI-Blueprints/rag.git rag

# Download example OpenSearch implementation from NVIDIA repository
COMMIT_HASH="47cd8b345e5049d49d8beb406372de84bd005abe"
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

### Step 6: Deploy Enterprise RAG Blueprint with OpenSearch

Deploy the Enterprise RAG Blueprint using the OpenSearch-enabled images and the OpenSearch service account:

> **Note**: The `helm/rag-values-os.yaml` file is pre-configured with Karpenter labels for automatic g5 instance provisioning. No manual node selection required.

```bash
# Set deployment variables
export ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
export IMAGE_TAG="2.3.0-opensearch"

# Deploy RAG with OpenSearch configuration
helm upgrade --install rag -n rag \
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

# Patch ingestor-server deployment to use OpenSearch service account
# This service account has IAM permissions via Pod Identity
kubectl patch deployment ingestor-server -n rag \
  -p "{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$OPENSEARCH_SERVICE_ACCOUNT\"}}}}"
```

This deploys:
- **49B Nemotron Model** (8 GPUs) - Karpenter will provision g5.48xlarge
- **Embedding & Reranking Models** (1 GPU each) - Karpenter will provision g5.xlarge through g5.12xlarge
- **Data Ingestion Models** (1 GPU each) - Karpenter will provision g5.xlarge through g5.12xlarge
- **RAG Server** with OpenSearch Serverless integration
- **Frontend** for user interaction

### Step 7: Setup Port Forwarding for RAG Services

To securely access RAG services, use kubectl port-forward:

```bash
# Port-forward RAG frontend (run in a separate terminal)
kubectl port-forward -n rag svc/rag-frontend 3001:3000

# Port-forward ingestor server (run in another separate terminal)
kubectl port-forward -n rag svc/ingestor-server 8082:8082
```

> **Note**: These commands will run in the foreground. Open separate terminal windows for each port-forward command, or run them in the background.

> **Alternative**: If you need to expose services publicly, you can create an Ingress resource with appropriate authentication and security controls instead of using port-forward.

### Step 8: Verify RAG Deployment

Check that all RAG components are running:

```bash
# Check all pods in RAG namespace
kubectl get all -n rag

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=rag -n rag --timeout=600s

# Check specific components
kubectl get pods -n rag -o wide | grep -E "NAME|nim-llm|rag-server|ingestor|embedding|reranking"

# Verify service accounts are configured correctly
kubectl get pod -n rag -l app.kubernetes.io/component=rag-server -o jsonpath='{.items[0].spec.serviceAccountName}' | xargs -I {} echo "RAG Server service account: {}"
kubectl get pod -n rag -l app=ingestor-server -o jsonpath='{.items[0].spec.serviceAccountName}' | xargs -I {} echo "Ingestor Server service account: {}"
```

## AI-Q Components Deployment

> **📝 Deployment Choice**: The following steps deploy AI-Q Research Assistant components. If your use case only requires the Enterprise RAG Blueprint, you can stop after Step 8. If you need automated research report generation with web search capabilities, continue with these steps to deploy the full AI-Q solution on top of the Enterprise RAG foundation.

### Step 9: Deploy AIRA Components

Deploy the AI-Q Research Assistant:

> **Note**: The `helm/aira-values.eks.yaml` file is pre-configured with Karpenter labels to automatically provision a g5.48xlarge instance for the 70B model (8 GPUs).

```bash
# Verify TAVILY_API_KEY is set
echo "Tavily API Key: ${TAVILY_API_KEY:0:10}..."

# Deploy AIRA using NGC Helm chart
helm upgrade --install aira https://helm.ngc.nvidia.com/nvidia/blueprint/charts/aiq-aira-v1.2.0.tgz \
  --username='$oauthtoken' \
  --password="${NGC_API_KEY}" \
  -n nv-aira --create-namespace \
  -f helm/aira-values.eks.yaml \
  --set imagePullSecret.password="$NGC_API_KEY" \
  --set ngcApiSecret.password="$NGC_API_KEY" \
  --set tavilyApiSecret.password="$TAVILY_API_KEY"
```

This deploys:
- **AIRA Backend**: Research assistant functionality
- **70B Instruct Model**: For report generation (8 GPUs) - Karpenter will provision g5.48xlarge
- **NGINX Proxy**: Routes requests to RAG and AIRA services
- **Frontend**: User interface

Karpenter will provision an additional g5.48xlarge instance for the AI-Q 70B model.

> **⏱️ Deployment Time**: The 70B Instruct LLM can take **up to 20 minutes** to download and deploy. Monitor deployment progress in Step 11.

### Step 10: Setup Port Forwarding for AIRA Services

To securely access the AIRA frontend, use kubectl port-forward:

```bash
# Port-forward AIRA frontend (run in a separate terminal)
kubectl port-forward -n nv-aira svc/aira-aira-frontend 3000:3000
```

> **Note**: This command will run in the foreground. Open a separate terminal window or run it in the background.

> **Alternative**: If you need to expose the service publicly, you can create an Ingress resource with appropriate authentication and security controls instead of using port-forward.

### Step 11: Verify AIRA Deployment

Check that all AIRA components are running:

```bash
# Check all AIRA components
kubectl get all -n nv-aira

# Wait for all components to be ready (70B model download can take up to 20 minutes)
kubectl wait --for=condition=ready pod -l app=aira -n nv-aira --timeout=1200s

# Check pod distribution across g5 nodes
kubectl get pods -n nv-aira -o wide
```

### Step 12: Data Ingestion from S3

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

First, ensure the ingestor server port-forward is running from Step 7:

```bash
# If not already running, start port-forward in a separate terminal
kubectl port-forward -n rag svc/ingestor-server 8082:8082
```

Then run the data ingestion script:

```bash
# Set required environment variables
export S3_BUCKET_NAME="your-pdf-bucket-name" # Replace with your S3 bucket name
export INGESTOR_URL="localhost:8082"  # Using port-forward from Step 7

# Optional: Configure additional settings
export S3_PREFIX=""  # Optional: folder path (e.g., "documents/")
export RAG_COLLECTION_NAME="multimodal_data"
export UPLOAD_BATCH_SIZE="100"

# Run the data ingestion script
./data_ingestion.sh
```

> **Note**: For testing purposes, you can also upload individual documents directly through the RAG or AIRA frontend UI in the next step. For more details on script options and advanced usage, see:
> - [RAG batch_ingestion.py documentation](https://github.com/NVIDIA-AI-Blueprints/rag/tree/v2.3.0/scripts)
> - [AIQ bulk data ingestion documentation](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant/blob/main/data/readme.md#bulk-upload-via-python)

### Step 13: Access Services

With port-forwarding enabled from previous steps, access the services locally:

**AIRA Research Assistant:**
- URL: http://localhost:3000
- Use this to generate comprehensive research reports

**RAG Frontend** (optional):
- URL: http://localhost:3001
- Use this to test the RAG application directly

**Ingestor API** (optional):
- URL: http://localhost:8082
- API docs available at: http://localhost:8082/docs

> **Note**: Ensure the corresponding port-forward commands from Steps 7 and 10 are running in separate terminal windows to access these services.

## Observability

### Access Monitoring Services

To access observability dashboards, use kubectl port-forward:

**RAG Observability (Zipkin & Grafana):**

```bash
# Port-forward Zipkin for distributed tracing (run in a separate terminal)
kubectl port-forward -n rag svc/rag-zipkin 9411:9411

# Port-forward Grafana for metrics and dashboards (run in another separate terminal)
kubectl port-forward -n rag svc/rag-grafana 8080:80
```

**AI-Q Observability (Phoenix):**

```bash
# Port-forward Phoenix for AI-Q tracing (run in a separate terminal)
kubectl port-forward -n nv-aira svc/aira-phoenix 6006:6006
```

**Access Monitoring UIs:**

- **Zipkin UI** (RAG tracing): http://localhost:9411
- **Grafana UI** (RAG metrics): http://localhost:8080
- **Phoenix UI** (AI-Q tracing): http://localhost:6006

> **Note**: For detailed information on using these observability tools, refer to:
> - [Viewing Traces in Zipkin](https://github.com/NVIDIA-AI-Blueprints/rag/blob/main/docs/observability.md#view-traces-in-zipkin)
> - [Viewing Metrics in Grafana Dashboard](https://github.com/NVIDIA-AI-Blueprints/rag/blob/main/docs/observability.md#view-metrics-in-grafana)

> **Alternative**: If you need to expose monitoring services publicly, you can create an Ingress resource with appropriate authentication and security controls.

## Cleanup

### Uninstall Applications

```bash
# Uninstall AIRA
helm uninstall aira -n nv-aira
kubectl delete namespace nv-aira

# Uninstall Enterprise RAG Blueprint
helm uninstall rag -n rag
kubectl delete namespace rag
```

### Clean Up Infrastructure

To remove the EKS cluster and all infrastructure:

```bash
# From the blueprints directory, navigate to infra
cd ../../../infra/nvidia-deep-research

# Run the cleanup script (handles proper teardown sequence)
./cleanup.sh
```

> **Warning**: This will permanently delete all data and resources. Backup important data before proceeding.

## Additional Resources

**NVIDIA Blueprints:**
- [NVIDIA Enterprise RAG Blueprint](https://build.nvidia.com/nvidia/build-an-enterprise-rag-pipeline)
- [NVIDIA Enterprise RAG Blueprint Github](https://github.com/NVIDIA-AI-Blueprints/rag)
- [NVIDIA AI-Q Research Assistant](https://build.nvidia.com/nvidia/aiq)
- [NVIDIA AI-Q Research Assistant Github](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant)

**AWS Services:**
- [OpenSearch Serverless Documentation](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
