---
sidebar_label: Running Inference Perf on EKS
---

# Running Inference Perf on EKS

Inference Perf is a GenAI inference performance benchmarking tool designed specifically for measuring LLM inference endpoint performance on Kubernetes. It runs as a Kubernetes Job and supports multiple model servers ([vLLM](https://github.com/vllm-project/vllm), [SGLang](https://github.com/sgl-project/sglang), [TGI](https://github.com/huggingface/text-generation-inference)) with standardized metrics.

Why use a [Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)? Jobs run once and terminate when complete, making them ideal for benchmarking tasks. Results are stored locally or in cloud storage ([S3](https://aws.amazon.com/s3/)).


## Prerequisites

* Kubernetes cluster with kubectl access (version 1.21+)
* A deployed inference endpoint with OpenAI-compatible API (vLLM, SGLang, TGI, or compatible)
* Namespace for running benchmarks
* Container image: quay.io/inference-perf/inference-perf:v0.2.0
* (Optional) HuggingFace token for downloading tokenizers
* (Optional) AWS credentials for S3 storage


## Model-Specific Dependencies

⚠️ IMPORTANT: Different models require different tokenizer packages:

| Model Family | Requires sentencepiece? | Examples |
|--------------|------------------------|----------|
| Mistral (all versions) | ✅ YES | mistralai/Mistral-7B-Instruct-v0.3 |
| Llama 2 | ✅ YES | meta-llama/Llama-2-7b-hf |
| Llama 3.1 | ✅ YES | meta-llama/Meta-Llama-3.1-8B |
| SmolLM2 | ❌ NO | HuggingFaceTB/SmolLM2-135M-Instruct |
| GPT models | ❌ NO | Various GPT variants |

If using Mistral or Llama models, you must install the sentencepiece package. See "Handling Model Dependencies" section below for implementation.


### Understanding the Inference Benchmark Framework architecture

Before deploying, it’s important to understand the key configuration components that define your benchmark test.

#### API Configuration

Defines how the tool communicates with your inference endpoint. You’ll specify whether you’re using completion or chat API, and whether streaming is enabled (required for measuring TTFT and ITL metrics).

```yaml
api:
  type: completion # completion or chat (default: completion)
  streaming: true # Enable for TTFT/ITL metrics
```

#### Data Generation

Controls what data is sent to your inference endpoint. You can use real datasets (ShareGPT) or synthetic data with controlled distributions. Synthetic data is useful when you need specific input/output length patterns for testing.

```yaml
data:

  type: synthetic # shareGPT, synthetic, random, shared_prefix, etc.  
  
  input_distribution:
    mean: 512      # Average input prompt length in tokens
    std_dev: 128   # Variation in prompt length (68% within ±128 tokens of mean)
    min: 128       # Minimum input tokens (clips distribution lower bound)
    max: 2048      # Maximum input tokens (clips distribution upper bound)
  
  output_distribution:
    mean: 256      # Average generated response length in tokens
    std_dev: 64    # Variation in response length (68% within ±64 tokens of mean)
    min: 32        # Minimum output tokens (clips distribution lower bound)
    max: 512       # Maximum output tokens (clips distribution upper bound)
```


#### Load Generation

Defines your load pattern - how many requests per second and for how long. You can use multiple stages to test different load levels, or use sweep mode for automatic saturation detection.

```yaml
load:
  type: constant              # Use 'constant' for uniform arrival (predictable load) or 'poisson' for bursty traffic (realistic production)
  stages:
    - rate: 10                # Requests per second (QPS) - increase to test higher throughput, decrease for baseline/minimal load
      duration: 300           # How long to sustain this rate in seconds - longer durations (300-600s) ensure stable measurements
  num_workers: 4              # Concurrent workers generating load - increase if inference-perf can't achieve target rate (check scheduling delay in results)
```

Note on `num_workers`: This controls the benchmark tool's internal parallelism, not concurrent users. The default value of 4 works for most scenarios. Only increase if results show high schedule_delay (> 10ms), indicating the tool cannot maintain the target rate.

#### Server Configuration

Specifies your inference endpoint details - server type, model name, and URL. The base URL is the Kubernetes service address (<service-name>.<namespace-name>.svc.cluster.local).

```yaml
server:
  type: vllm # vllm, sglang, or tgi
  model_name: mistralai/Mistral-7B-Instruct-v0.3
  base_url: http://vllm-service.default:8000
  ignore_eos: true
```

#### Storage Configuration

Determines where benchmark results are saved. Local storage saves to the pod filesystem (requires manual copy), while S3 storage automatically persists results to your AWS bucket.

```yaml
storage:
  local_storage: # Default: saves in pod
    path: "reports-my-perf"
    
  # ⚠️ Warning: local_storage results are lost when pod terminates 
  # To retrieve results, add '&& sleep infinity' to the Job args and use: 
  # kubectl cp <pod-name>:/workspace/reports-* ./local-results -n benchmarking
  # We recommend to use s3 as the storage solution - see below

  # OR

  simple_storage_service:
    bucket_name: "my-results-bucket"
    path: "inference-perf/my-perf"
```

#### Metrics Collection (Optional)

Enables advanced metrics collection from Prometheus if your inference server exposes metrics.

```yaml
metrics:
  type: prometheus
  prometheus:
    url: http://kube-prometheus-stack-prometheus.monitoring:9090 # For ai-on-eks Path A; adjust service name/namespace for custom Prometheus
    scrape_interval: 15
```

#### Infrastructure Topology for Reproducible Results

For accurate, comparable benchmarks across multiple runs, the inference-perf Job MUST be co-located with your inference deployment in the same Availability Zone.

##### Why This Matters:

Without proper placement, benchmark results become unreliable:

* Cross-AZ network latency adds 1-2ms per request
* Results vary unpredictably across benchmark runs
* You cannot determine if performance changes are real or due to infrastructure placement
* Optimization decisions become impossible

All benchmark examples in this guide include `affinity` configuration to enforce same-AZ placement using the standard Kubernetes topology label `topology.kubernetes.io/zone`.


