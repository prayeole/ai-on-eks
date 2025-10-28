---
title: NVIDIA AI-Q Research Assistant on Amazon EKS
sidebar_position: 9
---

import CollapsibleContent from '../../../../src/components/CollapsibleContent';

:::warning
Deployment of AI-Q Research Assistant on EKS requires access to GPU instances (g5, p4, or p5 families). If your deployment isn't working, it's often due to missing access to these resources. This blueprint relies on Karpenter autoscaling for dynamic GPU provisioning.
:::

:::info
AI-Q is a research assistant powered by advanced reasoning models, NeMo Retriever microservices, and web search, designed to help you research any topic. This implementation provides deployment on Amazon EKS with dynamic GPU autoscaling.

Source: [NVIDIA AI-Q Research Assistant Blueprint](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant)
:::

# NVIDIA AI-Q Research Assistant on Amazon EKS

## What is NVIDIA AI-Q Research Assistant?

[NVIDIA AI-Q Research Assistant](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant) is a research assistant powered by advanced reasoning models, designed to help you research any topic. The platform combines:

- **Advanced Reasoning Models**: Uses [Llama-3.3-Nemotron-Super-49B-v1.5](https://build.nvidia.com/nvidia/llama-3_3-nemotron-super-49b-v1_5) reasoning model with FP8 precision for high-quality report generation
- **Multi-Modal RAG**: NVIDIA RAG Blueprint with NeMo Retriever microservices for document understanding across text, images, tables, and charts
- **Web Search Integration**: Real-time web search powered by Tavily API to supplement on-premise sources
- **NVIDIA NIM Microservices**: Optimized inference containers for LLMs and vision models

### Key Components

Per the [official architecture](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant):

**1. NVIDIA AI Workbench**
- Simplified development environment
- Local testing and customization
- Easy configuration of different LLMs

**2. NVIDIA RAG Blueprint**
- Solution for querying large sets of on-premise multi-modal documents
- Supports text, images, tables, and charts extraction
- Semantic search and retrieval

**3. NVIDIA NeMo Retriever Microservices**
- Multi-modal document ingestion
- Graphic elements detection
- Table structure extraction  
- PaddleOCR for text recognition

**4. NVIDIA NIM Microservices**
- Inference containers for LLMs and vision models
- [Llama-3.3-Nemotron-Super-49B-v1.5](https://build.nvidia.com/nvidia/llama-3_3-nemotron-super-49b-v1_5) reasoning model
- Llama-3.3-70B-Instruct model for report generation

**5. Web Search (Tavily)**
- Supplements on-premise sources with real-time web search
- Expands research beyond internal documents

## Overview

This blueprint implements the **[NVIDIA AI-Q Research Assistant](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant)** on Amazon EKS, combining the [NVIDIA RAG Blueprint](https://github.com/NVIDIA-AI-Blueprints/rag) with AI-Q components for comprehensive research capabilities.

### Deployment Approach

**Why This Setup Process?**
While this implementation involves multiple steps, it provides several advantages:

- **Complete Infrastructure**: Automatically provisions VPC, EKS cluster, OpenSearch Serverless, and monitoring stack
- **Enterprise Features**: Includes security, monitoring, and scalability features
- **AWS Integration**: Leverages Karpenter autoscaling, IRSA authentication, and managed AWS services
- **Reproducible**: Infrastructure as Code ensures consistent deployments across environments

### Key Features

**Performance Optimizations:**
- **Karpenter Autoscaling**: Dynamic GPU node provisioning based on workload demands
- **Intelligent Instance Selection**: Automatically chooses optimal GPU instance types (G5, P4, P5)
- **Bin-Packing**: Efficient GPU utilization across multiple workloads

**Enterprise Ready:**
- **OpenSearch Serverless**: Managed vector database with automatic scaling
- **IRSA Authentication**: IAM Roles for Service Accounts for secure AWS access
- **Observability Stack**: Prometheus, Grafana, and DCGM for GPU monitoring
- **Load Balancing**: AWS Load Balancer Controller for external access

## Architecture

The deployment uses Amazon EKS with Karpenter-based dynamic provisioning:

![NVIDIA AI-Q on EKS](../img/nvidia-deep-research-arch.png)

**Infrastructure Components:**
- **VPC and Networking**: Standard VPC with secondary CIDR for extended pod networking
- **EKS Cluster**: Managed Kubernetes with Karpenter for GPU autoscaling
- **OpenSearch Serverless**: Vector database with IRSA integration
- **Monitoring Stack**: Prometheus, Grafana, and NVIDIA DCGM
- **Storage**: Amazon EFS for shared data and model caching

### RAG Pipeline Architecture

![RAG Pipeline with OpenSearch](../img/nvidia-rag-opensearch-arch.png)

The [RAG pipeline](https://github.com/NVIDIA-AI-Blueprints/rag) processes documents through multiple specialized NIM microservices:

**1. Llama-3.3-Nemotron-Super-49B-v1.5**
- [Advanced reasoning model](https://build.nvidia.com/nvidia/llama-3_3-nemotron-super-49b-v1_5)
- Primary reasoning and generation for both RAG and report writing
- Query rewriting and decomposition
- Filter expression generation

**2. Embedding & Reranking**
- LLama 3.2 NV-EmbedQA: 2048-dim embeddings
- LLama 3.2 NV-RerankQA: Relevance scoring

**3. NV-Ingest Pipeline**
- **PaddleOCR**: Text extraction from images
- **Page Elements**: Document layout understanding
- **Graphic Elements**: Chart and diagram detection
- **Table Structure**: Tabular data extraction

**4. AI-Q Research Assistant Components**
- Llama-3.3-70B-Instruct model for report generation (optional, 2 GPUs)
- Web search via Tavily API
- React frontend with NGINX proxy
- Backend orchestration for research workflows

### Karpenter-Based GPU Scheduling

:::tip GPU Instance Flexibility
This blueprint is pre-configured with **G5 instances (A10G GPUs)** to provide a cost-effective starting point. However, **you can easily switch to P4 (A100) or P5 (H100) instances** by modifying the Helm values files. The infrastructure includes Karpenter NodePools for G5, G6, G6e, P4, and P5 instance families - simply change the `nodeSelector` labels to match your performance and budget requirements.
:::

All components use Karpenter labels for automatic provisioning. **Default configuration (G5 instances)**:

```yaml
# Example: 8-GPU workloads (49B/70B models)
nodeSelector:
  karpenter.k8s.aws/instance-family: g5  # Use G5 (A10G GPUs)
  karpenter.k8s.aws/instance-size: 48xlarge  # 8x A10G
  karpenter.sh/capacity-type: on-demand

# Example: 1-GPU workloads (embedding, reranking, OCR)
nodeSelector:
  karpenter.k8s.aws/instance-family: g5  # Use G5 (A10G GPUs)
  karpenter.k8s.aws/instance-size: 12xlarge  # Up to 4x A10G
```

**To use different GPU types**, update the `instance-family` in your Helm values:

```yaml
# For P5 (H100 GPUs) - highest performance
nodeSelector:
  karpenter.k8s.aws/instance-family: p5
  karpenter.k8s.aws/instance-size: 48xlarge  # 8x H100

# For P4 (A100 GPUs) - high performance
nodeSelector:
  karpenter.k8s.aws/instance-family: p4d
  karpenter.k8s.aws/instance-size: 24xlarge  # 8x A100

# For G6e (L40S GPUs) - balanced performance
nodeSelector:
  karpenter.k8s.aws/instance-family: g6e
  karpenter.k8s.aws/instance-size: 48xlarge  # 8x L40S
```

**No manual node creation required** - Karpenter automatically provisions the right instances based on your `nodeSelector` configuration!

## Prerequisites

**System Requirements**: Any Linux/macOS system with AWS CLI access

Install the following tools:

- **AWS CLI**: Configured with appropriate permissions ([installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **kubectl**: Kubernetes command-line tool ([installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/))
- **helm**: Kubernetes package manager ([installation guide](https://helm.sh/docs/intro/install/))
- **terraform**: Infrastructure as code tool ([installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli))
- **git**: Version control ([installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git))

### Required API Tokens

- **[NGC API Token](https://org.ngc.nvidia.com/setup/personal-keys)**: Required for accessing NVIDIA NIM containers and AI Foundation models
  - Sign up at [NVIDIA NGC](https://org.ngc.nvidia.com/)
  - Generate an API key from your account settings
  - Set as `NGC_API_KEY` environment variable
  - Note: NVIDIA AI Enterprise license required for local hosting of NIM microservices
- **[Tavily API Key](https://tavily.com/)**: Required for AI-Q web search functionality
  - Create account at [Tavily](https://tavily.com/)
  - Generate API key from dashboard
  - Set as `TAVILY_API_KEY` environment variable

### GPU Instance Access

Ensure your AWS account has access to GPU instances. This blueprint supports multiple instance families through Karpenter NodePools:

**Supported GPU Instance Families:**

| Instance Family | GPU Type | Performance Profile | Use Case |
|----------------|----------|---------------------|----------|
| **G5** (default) | NVIDIA A10G | Cost-effective, 24GB VRAM | General workloads, development |
| **G6e** | NVIDIA L40S | Balanced, 48GB VRAM | High-memory models |
| **P4d/P4de** | NVIDIA A100 | High-performance, 40/80GB VRAM | Large-scale deployments |
| **P5/P5e/P5en** | NVIDIA H100 | Ultra-high performance, 80GB VRAM | Maximum performance |

**Instance Sizing:**
- **8-GPU workloads** (49B/70B models): Use `.48xlarge` (G5/P5) or `.24xlarge` (P4)
- **1-4 GPU workloads** (microservices): Use `.xlarge` through `.12xlarge` (G5/G6e)

> **Note**: G5 instances are pre-configured in the Helm values to provide an accessible starting point. You can switch to P4/P5/G6e instances by editing the `nodeSelector` in the Helm values files - no infrastructure changes required.

<CollapsibleContent header={<h2><span>Deploying the Solution</span></h2>}>

Complete the following steps to deploy NVIDIA Deep Research on Amazon EKS:

### Step 1: Clone the Repository

```bash
git clone https://github.com/awslabs/ai-on-eks.git && cd ai-on-eks
```

### Step 2: Deploy Infrastructure

Navigate to the infrastructure directory and run the installation script:

```bash
cd infra/nvidia-deep-research
./install.sh
```

This command provisions your complete environment:
- **VPC**: Subnets, security groups, NAT gateways, and internet gateway
- **EKS Cluster**: With Karpenter for dynamic GPU provisioning
- **OpenSearch Serverless**: Vector database with IRSA authentication
- **Monitoring Stack**: Prometheus, Grafana, and AI/ML observability
- **Karpenter NodePools**: G5, G6, G6e, P4, P5 instance support

**Duration**: 15-30 minutes

### Step 3: Configure kubectl

```bash
aws eks --region us-west-2 update-kubeconfig --name nvidia-deep-research
```

**Verify Cluster is Ready:**

```bash
# Verify Karpenter is running
kubectl get pods -n karpenter

# Check available NodePools
kubectl get nodepools

# Check EC2NodeClass
kubectl get ec2nodeclasses
```

Expected NodePools:
- `default` - For non-GPU workloads
- `g5-gpu-karpenter` - For G5 GPU instances
- `g6-gpu-karpenter` - For G6 GPU instances (optional)
- `p4-gpu-karpenter` - For P4d/P4de GPU instances (A100)
- `p5-gpu-karpenter` - For P5/P5e/P5en GPU instances (H100)

### Step 4: Configure Karpenter NodePool Limits

Increase the memory limit for the GPU NodePool to accommodate multiple large models:

```bash
kubectl patch nodepool g5-gpu-karpenter --type='json' -p='[{"op": "replace", "path": "/spec/limits/memory", "value": "2000Gi"}]'
```

This command increases the g5-gpu-karpenter NodePool's memory limit from 1000Gi to 2000Gi, allowing Karpenter to provision sufficient GPU nodes for all the models being deployed.

### Step 5: Set Environment Variables

```bash
# Navigate to terraform directory
cd terraform/_LOCAL

# Get OpenSearch endpoint from Terraform output
export OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint)

# Navigate to blueprint directory
cd ../../../../blueprints/inference/nvidia-deep-research

# Get AWS Account ID and Region
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION="us-west-2"

# OpenSearch Configuration
export OPENSEARCH_SERVICE_ACCOUNT="opensearch-access-sa"
export OPENSEARCH_NAMESPACE="nv-nvidia-blueprint-rag"

# Verify OpenSearch endpoint was captured
echo "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"

# NGC API Key
export NGC_API_KEY="<your-ngc-api-key>"

# Tavily API Key for AI-Q
export TAVILY_API_KEY="<your-tavily-api-key>"
```

### Step 6: Integrate OpenSearch and Build Docker Images

Clone the RAG source code and add OpenSearch implementation:

```bash
# Clone RAG source code
git clone -b v2.3.0 https://github.com/NVIDIA-AI-Blueprints/rag.git rag

# Download OpenSearch implementation from NVIDIA nim-deploy repository
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

### Step 7: Deploy RAG Blueprint with OpenSearch

Deploy the RAG Blueprint using OpenSearch-enabled images:

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

# Patch ingestor-server to use IRSA service account
kubectl patch deployment ingestor-server -n nv-nvidia-blueprint-rag \
  -p "{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$OPENSEARCH_SERVICE_ACCOUNT\"}}}}"
```

**Verify RAG Deployment:**

```bash
# Check all pods in RAG namespace
kubectl get all -n nv-nvidia-blueprint-rag

# Wait for all pods to be ready (this may take 10-20 minutes for model downloads)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=rag -n nv-nvidia-blueprint-rag --timeout=1200s

# Verify service accounts are using IRSA
kubectl get pod -n nv-nvidia-blueprint-rag -l app.kubernetes.io/component=rag-server -o jsonpath='{.items[0].spec.serviceAccountName}'
kubectl get pod -n nv-nvidia-blueprint-rag -l app=ingestor-server -o jsonpath='{.items[0].spec.serviceAccountName}'
```

### Step 8: Configure RAG Load Balancers

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

### Step 9: Setup Helm Repositories for AI-Q

Add required Helm repositories:

```bash
# Add NGC Helm repositories
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

# Update all repositories
helm repo update

# Update dependencies for the local AI-Q chart
helm dependency update helm/aiq-aira
```

### Step 10: Deploy AI-Q Research Assistant

```bash
# Verify TAVILY_API_KEY is set
echo "Tavily API Key: ${TAVILY_API_KEY:0:10}..."

# Deploy AI-Q using local Helm chart
helm upgrade --install aira helm/aiq-aira \
  -n nv-aira --create-namespace \
  -f helm/aira-values.eks.yaml \
  --set imagePullSecret.password="$NGC_API_KEY" \
  --set ngcApiSecret.password="$NGC_API_KEY" \
  --set config.tavily_api_key="$TAVILY_API_KEY"
```

This deploys:
- **AI-Q Backend**: Research assistant functionality
- **70B Instruct Model**: For report generation
- **NGINX Proxy**: Routes requests to RAG and AI-Q services
- **Frontend**: User interface

Karpenter provisions an additional GPU instance for the AI-Q 70B model (default: g5.48xlarge).

**Verify AI-Q Deployment:**

```bash
# Check all AI-Q components
kubectl get all -n nv-aira

# Wait for all components to be ready
kubectl wait --for=condition=ready pod -l app=aira -n nv-aira --timeout=600s

# Check pod distribution across GPU nodes
kubectl get pods -n nv-aira -o wide
```

### Step 11: Configure AI-Q Load Balancer

Expose AI-Q frontend via AWS Network Load Balancer:

```bash
# Patch AI-Q frontend service to LoadBalancer
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

### Step 12: Data Ingestion from S3

Ingest documents from an S3 bucket into the OpenSearch vector database:

```bash
# Set required environment variables
export S3_BUCKET_NAME="your-pdf-bucket-name"  # Replace with your S3 bucket
export INGESTOR_URL=$(kubectl get svc ingestor-server -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Optional: Configure additional settings
export S3_PREFIX=""  # Optional: folder path (e.g., "documents/")
export RAG_COLLECTION_NAME="multimodal_data"
export UPLOAD_BATCH_SIZE="100"

# Run the data ingestion script
./data_ingestion.sh
```

> **Note**: For more details on script options and advanced usage, see the [batch_ingestion.py documentation](https://github.com/NVIDIA-AI-Blueprints/rag/tree/v2.3.0/scripts).

### Step 13: Access Services

```bash
# Get AI-Q frontend URL
echo "AI-Q Frontend: http://$(kubectl get svc aira-aira-frontend -n nv-aira -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):3001"

# Get RAG frontend URL (optional)
echo "RAG Frontend: http://$(kubectl get svc rag-frontend -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):3000"

# Get Ingestor API URL (for data ingestion)
echo "Ingestor API: http://$(kubectl get svc ingestor-server -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):8082"
```

> **Note**: The load balancer endpoints may take up to 5 minutes to be provisioned and become accessible after deployment.

**Access the application:**
- **AI-Q Research Assistant**: Open the AI-Q Frontend URL in your browser to generate comprehensive research reports
- **RAG Frontend** (optional): Test the RAG application directly
- **Ingestor API** (optional): Upload documents for processing

</CollapsibleContent>

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

## Test and Validate

### Verify Deployment

Check that all components are running:

```bash
# Check RAG pods
kubectl get pods -n nv-nvidia-blueprint-rag

# Check AIRA pods
kubectl get pods -n nv-aira

# Check Karpenter provisioned GPU nodes
kubectl get nodes -l nvidia.com/gpu.present=true
```

### Access Frontend

```bash
# Get the AI-Q frontend URL
AI_Q_URL=$(kubectl get svc aira-aira-frontend -n nv-aira -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "AI-Q Frontend: http://${AI_Q_URL}:3001"

# Get the RAG frontend URL (optional)
RAG_URL=$(kubectl get svc rag-frontend -n nv-nvidia-blueprint-rag -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "RAG Frontend: http://${RAG_URL}:3000"

# Open AI-Q in your browser
open http://${AI_Q_URL}:3001  # macOS
# xdg-open http://${AI_Q_URL}:3001  # Linux
```

## Advanced Configuration

### Switching GPU Instance Types

The blueprint is pre-configured with G5 instances, but you can easily switch to other GPU types by editing the Helm values files.

**Step 1: Edit Helm Values**

For RAG components, edit `helm/rag-values-os.yaml`:

```yaml
# Example: Switch 49B model from G5 to P5 (H100)
nim-llm:
  nodeSelector:
    karpenter.k8s.aws/instance-family: p5     # Change from g5 to p5
    karpenter.k8s.aws/instance-size: 48xlarge # 8x H100
    karpenter.sh/capacity-type: on-demand
```

For AI-Q components, edit `helm/aira-values.eks.yaml`:

```yaml
# Example: Switch 70B model to P4 (A100)
nim-llm:
  nodeSelector:
    karpenter.k8s.aws/instance-family: p4d    # Change from g5 to p4d
    karpenter.k8s.aws/instance-size: 24xlarge # 8x A100
    karpenter.sh/capacity-type: on-demand
```

**Step 2: Redeploy**

After updating the Helm values, simply re-run the `helm upgrade` command:

```bash
# Redeploy RAG with new instance type
helm upgrade rag -n nv-nvidia-blueprint-rag \
  https://helm.ngc.nvidia.com/nvidia/blueprint/charts/nvidia-blueprint-rag-v2.3.0.tgz \
  -f helm/rag-values-os.yaml \
  --username '$oauthtoken' --password "${NGC_API_KEY}" \
  # ... (other --set flags)

# Redeploy AI-Q with new instance type
helm upgrade aira helm/aiq-aira -n nv-aira \
  -f helm/aira-values.eks.yaml \
  # ... (other --set flags)
```

Karpenter will automatically provision the new instance type. No infrastructure changes required!

## GPU Instance Support

### Available Karpenter NodePools

The infrastructure automatically provisions Karpenter NodePools for multiple GPU instance families:

| NodePool | Instance Families | GPU Type | VRAM | Deployment Status |
|----------|------------------|----------|------|------------------|
| g5-gpu-karpenter | G5 | NVIDIA A10G | 24GB | **Pre-configured (default)** |
| g6-gpu-karpenter | G6 | NVIDIA L4 | 24GB | Available |
| g6e-gpu-karpenter | G6e | NVIDIA L40S | 48GB | Available |
| p4-gpu-karpenter | P4d, P4de | NVIDIA A100 | 40/80GB | Available |
| p5-gpu-karpenter | P5, P5e, P5en | NVIDIA H100 | 80GB | Available |

**All NodePools are deployed by default** - you only need to update your Helm values to use a different instance family. No Terraform changes required.

### Choosing the Right GPU

**Performance Tiers:**
- **G5 (A10G)**: Default configuration, cost-effective, suitable for most workloads
- **G6e (L40S)**: Higher memory (48GB), better for memory-intensive models
- **P4 (A100)**: 2-3x performance over A10G, recommended for large-scale deployments
- **P5 (H100)**: 4-6x performance over A10G, maximum throughput for demanding workloads

**Selection Method:**

Use `instance-family` label in Helm values to target specific GPU types:

```yaml
# Method 1: Target by instance family (recommended)
nodeSelector:
  karpenter.k8s.aws/instance-family: p5     # Targets P5/P5e/P5en

# Method 2: Target by GPU type label
nodeSelector:
  gpuType: h100  # Karpenter chooses any H100-equipped instance
```

## Clean Up

```bash
# Delete applications
helm uninstall aira -n nv-aira
helm uninstall rag -n nv-nvidia-blueprint-rag

# Wait for Karpenter to terminate idle nodes (5-10 minutes)
# Or manually delete GPU nodes (replace instance-family as needed)
kubectl delete nodes -l nvidia.com/gpu.present=true

# Destroy infrastructure
cd infra/nvidia-deep-research/terraform/_LOCAL
terraform destroy -var-file=../blueprint.tfvars
```

**Duration**: ~10-15 minutes for complete teardown

## References

### Official NVIDIA Resources

**📚 Documentation:**
- [NVIDIA AI-Q Research Assistant GitHub](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant): Official AI-Q blueprint repository
- [NVIDIA AI-Q on AI Foundation](https://build.nvidia.com/nvidia/aiq): AI-Q blueprint card and hosted version
- [NVIDIA RAG Blueprint](https://github.com/NVIDIA-AI-Blueprints/rag): Complete RAG platform documentation
- [NVIDIA NIM Documentation](https://docs.nvidia.com/nim/): NIM microservices reference
- [NVIDIA AI Enterprise](https://www.nvidia.com/en-us/data-center/products/ai-enterprise/): Enterprise AI platform

**🤖 Models:**
- [Llama-3.3-Nemotron-Super-49B-v1.5](https://build.nvidia.com/nvidia/llama-3_3-nemotron-super-49b-v1_5): Advanced reasoning model (49B parameters, FP8)
- [Llama-3.3-70B-Instruct](https://huggingface.co/meta-llama/Llama-3.3-70B-Instruct): Instruction-following model

**📦 Container Images & Helm Charts:**
- [NVIDIA NGC Catalog](https://catalog.ngc.nvidia.com/): Official container registry
- [RAG Blueprint Helm Chart](https://helm.ngc.nvidia.com/nvidia/blueprint/charts/nvidia-blueprint-rag): Kubernetes deployment
- [NVIDIA NIM Containers](https://catalog.ngc.nvidia.com/orgs/nim): Optimized inference containers

### AI-on-EKS Blueprint Resources

**🏗️ AI-on-EKS Blueprint Resources:**
- [AI-on-EKS Repository](https://github.com/awslabs/ai-on-eks): Main blueprint repository
- [AI-Q Blueprint on EKS](https://github.com/awslabs/ai-on-eks/tree/main/blueprints/inference/nvidia-deep-research): EKS deployment code
- [Infrastructure Code](https://github.com/awslabs/ai-on-eks/tree/main/infra/nvidia-deep-research): Terraform automation with Karpenter

**📖 Documentation:**
- [Detailed Deployment Guide](https://github.com/awslabs/ai-on-eks/tree/main/blueprints/inference/nvidia-deep-research/README.md): Step-by-step EKS instructions
- [OpenSearch Integration](https://github.com/awslabs/ai-on-eks/tree/main/infra/nvidia-deep-research/terraform/opensearch-serverless.tf): IRSA authentication setup
- [Karpenter Configuration](https://github.com/awslabs/ai-on-eks/tree/main/infra/nvidia-deep-research/terraform/custom_karpenter.tf): P4/P5 GPU support

### Related Technologies

**☸️ Kubernetes & AWS:**
- [Amazon EKS](https://aws.amazon.com/eks/): Managed Kubernetes service
- [Karpenter](https://karpenter.sh/): Kubernetes node autoscaling
- [OpenSearch Serverless](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html): Managed vector database
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/): Kubernetes ingress

**🤖 AI/ML Tools:**
- [NVIDIA DCGM](https://developer.nvidia.com/dcgm): GPU monitoring
- [Prometheus](https://prometheus.io/): Metrics collection
- [Grafana](https://grafana.com/): Visualization dashboards

## Next Steps

1. **Explore Features**: Test multi-modal document processing with various file types
2. **Scale Deployments**: Configure multi-region or multi-cluster setups
3. **Integrate Applications**: Connect your applications to the RAG API endpoints
4. **Monitor Performance**: Use Grafana dashboards for ongoing monitoring
5. **Custom Models**: Swap in your own fine-tuned models
6. **Security Hardening**: Add authentication, rate limiting, and disaster recovery

---

This deployment provides an [NVIDIA AI-Q Research Assistant](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant) environment on Amazon EKS with enterprise-grade features including Karpenter automatic scaling, OpenSearch Serverless integration, and seamless AWS service integration.

**Additional Resources:**
- [AI-Q on NVIDIA AI Foundation](https://build.nvidia.com/nvidia/aiq): Try the hosted version
- [AI-Q GitHub Repository](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant): Official source code and documentation
- [Get Started Notebook](https://github.com/NVIDIA-AI-Blueprints/aiq-research-assistant): Interactive deployment guide
