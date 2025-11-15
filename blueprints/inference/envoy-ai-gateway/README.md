# Envoy AI Gateway Blueprint

This blueprint demonstrates how to deploy and configure Envoy AI Gateway on Amazon EKS for intelligent routing and management of AI/ML workloads.

## Overview

Envoy AI Gateway provides a unified entry point for multiple AI models with advanced routing, rate limiting, and observability features. This blueprint includes two practical use-cases that can be deployed independently or together.

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

## Prerequisites

- Amazon EKS cluster with Envoy Gateway v1.5.3+ installed
- Backend support enabled in Envoy Gateway: `config.envoyGateway.extensionApis.enableBackend: true`
- AI Gateway Controller v0.3.0 installed
- kubectl configured for your EKS cluster

## Quick Start

### 1. Deploy Common Infrastructure (Required Order)

```bash
# Step 1: Enable AI Gateway controller features
kubectl apply -f gateway.yaml

# Step 2: Create a Kubernetes secret with your Hugging Face token
kubectl create secret generic hf-token --from-literal=token=your_huggingface_token

# Step 3: Add and update helm chart repo
helm repo add ai-on-eks https://awslabs.github.io/ai-on-eks-charts/
helm repo update

# Step 4: Deploy gpt-oss-20b-vllm model using inference chart
helm install qwen3-1.7b ../inference-charts/. -f ../inference-charts/values-qwen3-1.7b-vllm.yaml \
  --set nameOverride=qwen3 \
  --set fullnameOverride=qwen3 \
  --set inference.serviceName=qwen3

# Step 5: Deploy llama-32-1b-vllm model using inference chart
helm install gpt-oss ../inference-charts/. -f ../inference-charts/values-gpt-oss-20b-vllm.yaml \
  --set nameOverride=gpt-oss \
  --set fullnameOverride=gpt-oss \
  --set inference.serviceName=gpt-oss

## Use-Cases

### 🎯 Multi-Model Routing
**Purpose**: Route requests to different AI models based on HTTP headers

**Features**:
- Header-based routing using `x-ai-eg-model`
- Support for self-hosted models
- Real AI model integration with OpenAI GPT OSS 20B, Qwen3-1.7B
- Auto-detecting test client

### Resource Dependencies & Purpose

**Core Infrastructure (Deploy First)**:
 `gateway.yaml` - Creates the main entry point for all AI traffic, deploys Envoy AI gateway

**Backend Services (Deploy Second)**:
 `model-backends.yaml` - Exposes existing vLLM service for AI Gateway routing and registers backend services with AI Gateway controller

**Use-Case Specific (Deploy Third)**:
- **Multi-Model Routing**: `multi-model-routing/ai-gateway-route.yaml`

## Configuration

### Gateway Configuration
- **Gateway Class**: `envoy-gateway`
- **Gateway Name**: `ai-gateway`
- **Namespace**: `default`
- **Ports**: HTTP (80), HTTPS (443)

## Testing

Each use-case includes a Python test client (`client.py`) that:
- Auto-detects the Gateway URL using kubectl
- Tests the specific functionality (routing or rate limiting)
- Provides detailed output and validation
- Includes usage examples

### Example Usage
```bash
# Test multi-model routing
cd multi-model-routing/
python3 client.py
```

## Monitoring

### Gateway Status
```bash
kubectl get gateway ai-gateway -o yaml
kubectl get aigatewayroute -o wide
kubectl get httproute -o wide
```

### AI Gateway Controller Logs
```bash
kubectl logs -n envoy-gateway-system deployment/ai-gateway-controller
```

### Envoy Gateway Logs
```bash
kubectl logs -n envoy-gateway-system deployment/envoy-gateway
```

### Validation Commands
```bash
# Check AI Gateway Route status
kubectl describe aigatewayroute multi-model-route

# Verify Backend resources
kubectl get backend -o wide

# Check AIServiceBackend status
kubectl get aiservicebackend -o wide

# Test Gateway connectivity
curl -H "x-ai-eg-model: text-llm" http://$GATEWAY_URL/v1/chat/completions
```

## Resources

- [Envoy AI Gateway Documentation](https://github.com/envoyproxy/ai-gateway)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [AI on EKS Website](https://awslabs.github.io/ai-on-eks/)
