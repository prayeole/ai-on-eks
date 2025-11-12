# Envoy AI Gateway Blueprint

This blueprint demonstrates how to deploy and configure Envoy AI Gateway v0.3.0 on Amazon EKS for intelligent routing and management of AI/ML workloads.

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

### 1. Deploy Common Infrastructure

```bash
# Step 1: Enable AI Gateway controller features
kubectl apply -f gateway.yaml

# Step 2: Deploy gpt-oss-20b-vllm model
helm install text-llm . -f values-gpt-oss-20b-vllm.yaml \
  --set nameOverride=text-llm \
  --set fullnameOverride=text-llm \
  --set inference.serviceName=text-llm

# Step 3: Deploy llama-32-1b-vllm model
helm install llama-backend . -f values-llama-32-1b-vllm.yaml \                                             
      --set nameOverride=llama-backend \
      --set fullnameOverride=llama-backend \
      --set inference.serviceName=llama-backend
```

## Use-Cases

### Multi-Model Routing
Route requests to different AI models based on HTTP headers
#### Features:
- Header-based routing using `x-ai-eg-model`
- Support for self-hosted models (gpt-oss-20b-vllm, llama-32-1b-vllm)
- Auto-detecting test client

#### Prerequisites
Deploy common infrastructure first model and gateway resources.

#### Deploy
```bash
cd multi-model-routing
kubectl apply -f ai-service-backend.yaml
kubectl apply -f ai-gateway-route.yaml
```

#### Test
Each use-case includes a Python test client (`client.py`) that:
- Auto-detects the Gateway URL using kubectl
- Tests the specific functionality (routing or rate limiting)
- Provides detailed output and validation
- Includes usage examples

```bash
# Test multi-model routing
python3 client.py
```

## Resources

- [Envoy AI Gateway Documentation](https://github.com/envoyproxy/ai-gateway)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [AI on EKS Website](https://awslabs.github.io/ai-on-eks/)
