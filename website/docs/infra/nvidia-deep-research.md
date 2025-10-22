---
sidebar_label: NVIDIA Deep Research
sidebar_position: 7
---

# NVIDIA Deep Research Infrastructure on EKS

The NVIDIA Deep Research infrastructure provides a production-ready EKS cluster optimized for deploying NVIDIA's AI-Q Research Assistant Blueprint with RAG (Retrieval-Augmented Generation) capabilities.

## Overview

This infrastructure solution combines multiple AWS services and NVIDIA technologies to deliver a comprehensive AI research platform:

- **Amazon EKS**: Kubernetes cluster for container orchestration
- **Karpenter**: Dynamic GPU node provisioning with instance-family based scheduling
- **OpenSearch Serverless**: Vector database for embeddings and semantic search
- **EFS**: Shared storage for data ingestion workflows
- **AWS Load Balancer Controller**: External access to services
- **NVIDIA GPU Operator**: Automated GPU driver management

An expanded [README](https://github.com/awslabs/ai-on-eks/tree/main/infra/nvidia-deep-research/README.md) is available with detailed infrastructure specifications.

## Architecture

![NVIDIA Deep Research Architecture](./img/nvidia-deep-research-arch.png)

The infrastructure is designed around Karpenter-based dynamic provisioning rather than static node groups:

- **g5-gpu-karpenter NodePool**: Provisions g5 instances (A10G GPUs) dynamically based on workload requirements
- **Secondary CIDR**: 100.64.0.0/16 for extended pod networking
- **OpenSearch Serverless**: Managed vector database with IRSA authentication
- **Observability Stack**: Prometheus, Grafana, and DCGM for GPU monitoring

### GPU Node Provisioning Strategy

The infrastructure uses Karpenter with intelligent bin-packing:

1. **49B LLM workloads** → g5.48xlarge (8 GPUs, exclusive use)
2. **1-GPU workloads** → g5.xlarge through g5.12xlarge (cost-optimized)
3. **On-demand for critical workloads** → Ensures stability for large models
4. **Spot for auxiliary workloads** → Cost savings where appropriate

## Key Components

### 1. OpenSearch Serverless Integration

The infrastructure provisions:
- **OpenSearch Collection**: Vector search collection for embeddings
- **IRSA Service Account**: Kubernetes service account with IAM role for pod-level authentication
- **Security Policies**: Encryption, network access, and data access policies
- **Automatic Configuration**: Collection endpoint automatically injected into deployments

### 2. Karpenter GPU NodePools

Pre-configured NodePools for different GPU workloads:

| NodePool | Instance Family | GPU Type | Use Case |
|----------|----------------|----------|----------|
| g5-gpu-karpenter | g5 (A10G) | NVIDIA A10G | General-purpose inference |
| g6-gpu-karpenter | g6 (L4) | NVIDIA L4 | Cost-effective inference |
| g6e-gpu-karpenter | g6e (L40S) | NVIDIA L40S | High-performance inference |

### 3. GPU Node Configuration

- **AMI**: AL2023 or Bottlerocket with NVIDIA drivers
- **EBS Volumes**: 500Gi gp3 volumes for model storage
- **Security Groups**: Proper DNS and cluster communication rules
- **Taints**: `nvidia.com/gpu=Exists:NoSchedule` for GPU workload isolation

### 4. Observability & Monitoring

- **NVIDIA DCGM Exporter**: GPU metrics collection
- **Prometheus**: Metrics aggregation
- **Grafana**: Visualization dashboards
- **Amazon Managed Prometheus** (optional): For production workloads

## Deployment

### Prerequisites

- AWS CLI configured
- kubectl installed
- Terraform >= 1.0

### Quick Start

```bash
cd infra/nvidia-deep-research

# Configure your deployment
vim terraform/blueprint.tfvars

# Deploy infrastructure
./install.sh
```

### Configuration Options

Key variables in `blueprint.tfvars`:

```hcl
# Cluster Configuration
name = "nvidia-deep-research"
region = "us-west-2"
enable_argocd = true

# OpenSearch Serverless
enable_opensearch_serverless = true
opensearch_collection_name = "osv-vector-dev"
opensearch_allow_public_access = true
opensearch_namespace = "nv-nvidia-blueprint-rag"

# GPU Node Groups (if using static nodes - optional)
gpu_nodegroup_1_enabled = false  # Set to true for static nodes
gpu_nodegroup_1_instance_types = ["g5.48xlarge"]
```

## Cost Optimization

### Dynamic Provisioning vs Static Node Groups

**Karpenter Dynamic Provisioning** (Recommended):
- ✅ Provisions nodes only when needed
- ✅ Automatically selects optimal instance sizes
- ✅ Consolidates underutilized nodes
- ✅ Mix of spot and on-demand based on workload

**Static Node Groups** (Optional):
- Set `gpu_nodegroup_X_enabled = true` in `blueprint.tfvars`
- Pre-provisions fixed number of nodes
- Useful for predictable workloads

### Memory Limits for GPU NodePools

GPU instances have high memory-to-CPU ratios. For deployments with multiple GPU workloads (RAG + AIRA), increase the Karpenter NodePool memory limit:

```bash
kubectl patch nodepool g5-gpu-karpenter --type='json' \
  -p='[{"op": "replace", "path": "/spec/limits/memory", "value": "2000Gi"}]'
```

## Security

- **IRSA**: IAM Roles for Service Accounts for OpenSearch access
- **Encryption**: EBS volumes encrypted at rest
- **Network Policies**: Security groups for pod communication
- **Secrets Management**: Kubernetes secrets for NGC API keys

## Monitoring

Access monitoring dashboards:

```bash
# Port-forward to Grafana
kubectl port-forward -n kube-prometheus-stack svc/kube-prometheus-stack-grafana 3000:80

# Default credentials: admin/prom-operator
```

## Next Steps

Once infrastructure is deployed, proceed to deploy the [NVIDIA Deep Research Blueprint](../blueprints/inference/GPUs/nvidia-deep-research.md).

## Cleanup

```bash
cd infra/nvidia-deep-research/terraform/_LOCAL
terraform destroy -var-file=../blueprint.tfvars
```

## Additional Resources

- [NVIDIA AI Enterprise](https://www.nvidia.com/en-us/data-center/products/ai-enterprise/)
- [Karpenter Documentation](https://karpenter.sh/)
- [OpenSearch Serverless](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html)
- [EKS Best Practices for AI/ML](https://aws.github.io/aws-eks-best-practices/machine-learning/)

