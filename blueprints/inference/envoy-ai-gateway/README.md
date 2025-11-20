# Envoy AI Gateway Blueprint

This blueprint demonstrates how to deploy and configure Envoy AI Gateway v0.4.0 on Amazon EKS for intelligent routing and management of AI/ML workloads.

## Overview

Envoy AI Gateway provides a unified entry point for multiple AI models with advanced routing, rate limiting, and observability features. This blueprint includes three practical use-cases that can be deployed independently or together.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Client Apps   │───▶│  Envoy Gateway   │───▶│   AI Model Services │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  AI Gateway      │
                       │  Controller      │
                       └──────────────────┘
```


## Quick Start

### 1. Deploy Infrastructure (One-Time Setup)

```bash
# Deploy the inference-ready-cluster with Envoy AI Gateway enabled
cd infra/solutions/inference-ready-cluster/terraform
# Set enable_envoy_ai_gateway = true in blueprint.tfvars
terraform apply
```

This automatically deploys:
- Envoy Gateway with AI Gateway support
- AI Gateway Controller
- Redis for rate limiting
- Required IAM roles and Pod Identity associations

### 2. Deploy AI Models

```bash
# Create Hugging Face token secret
kubectl create secret generic hf-token --from-literal=token=your_huggingface_token

# Add helm chart repository
helm repo add ai-on-eks https://awslabs.github.io/ai-on-eks-charts/
helm repo update

# Deploy qwen3 model
helm install qwen3-1.7b ai-on-eks/inference-charts \
  -f https://raw.githubusercontent.com/awslabs/ai-on-eks/refs/heads/main/blueprints/inference/inference-charts/values-qwen3-1.7b-vllm.yaml \
  --set nameOverride=qwen3 \
  --set fullnameOverride=qwen3 \
  --set inference.serviceName=qwen3

# Deploy gpt-oss model  
helm install gpt-oss ai-on-eks/inference-charts \
  -f https://raw.githubusercontent.com/awslabs/ai-on-eks/refs/heads/main/blueprints/inference/inference-charts/values-gpt-oss-20b-vllm.yaml \
  --set nameOverride=gpt-oss \
  --set fullnameOverride=gpt-oss \
  --set inference.serviceName=gpt-oss
```

### 3. Configure Gateway and Backends

```bash
# Deploy gateway and model backend configurations
kubectl apply -f gateway.yaml
kubectl apply -f model-backends.yaml
```

## Use Cases

### 🎯 Multi-Model Routing
**Purpose**: Route requests to different AI models based on HTTP headers

**Features**:
- Header-based routing using `x-ai-eg-model`
- Support for self-hosted models (qwen3, gpt-oss)
- Real AI model integration with OpenAI GPT OSS 20B, Qwen3-1.7B
- Auto-detecting test client


**Deploy**:
```bash
cd multi-model-routing
kubectl apply -f ai-gateway-route.yaml
```

**Test**:
```bash
# Test multi-model routing (requires actual AI models)
python3 client.py
```

### 🚦 Rate Limiting
**Purpose**: Token-based rate limiting with automatic tracking for AI workloads

**Features**:
- Token-based rate limiting (input, output, and total tokens)
- User-based rate limiting using `x-user-id` header
- Redis backend for distributed rate limiting (automatically deployed)
- Configurable limits per user per time window

**Prerequisites**:
- AI models deployed and returning token usage data
- Redis automatically available via ArgoCD infrastructure

**Deploy**:
```bash
cd rate-limiting
kubectl apply -f ai-gateway-route.yaml
kubectl apply -f ai-gateway-rate-limit.yaml
kubectl apply -f backend-traffic-policy.yaml
```

**Test**:
```bash
# Test rate limiting (requires actual AI models with token usage)
python3 client.py
```

### 🤖 Bedrock Integration
**Purpose**: Route requests to Amazon Bedrock models alongside self-hosted models

**Features**:
- Native Bedrock support using AWSAnthropic schema
- Anthropic Claude models via `/anthropic/v1/messages` endpoint
- Pod Identity authentication (automatically configured)
- TLS configuration for secure HTTPS endpoints


**Deploy**:
```bash
cd bedrock-integration
kubectl apply -f pod-identity-setup.yaml
kubectl apply -f ai-gateway-route.yaml
kubectl apply -f backend-security-policy.yaml
```

**Test**:
```bash
# Test Bedrock integration (requires AWS Bedrock access)
python3 client.py
```

**Key Configuration Notes**:
- **Authentication**: Pod Identity automatically configured via Terraform
- **Endpoint**: Use `/anthropic/v1/messages` (Anthropic Messages API format)
- **Schema**: `AWSAnthropic`

## Resources

- [Envoy AI Gateway Documentation](https://github.com/envoyproxy/ai-gateway)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [AI on EKS Website](https://awslabs.github.io/ai-on-eks/)

## Important Notes

- **Multi-Model Routing**: Requires deployed AI model services (qwen3, gpt-oss)
- **Rate Limiting**: Requires actual AI models that return real token usage data and Redis for storage
- **Bedrock Integration**: Requires AWS Bedrock API access, proper IAM setup, and Pod Identity configuration

These are working configuration examples that demonstrate AI Gateway capabilities with real AI model deployments and AWS Bedrock integration.
