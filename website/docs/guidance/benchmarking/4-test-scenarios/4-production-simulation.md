---
sidebar_label: Scenario 4 - Production Simulation
---

# SCENARIO 4: Production Simulation

## When to use this scenario:
Deploy production simulation as your final validation before launch—it replicates real-world traffic chaos with variable request sizes and Poisson (bursty) arrivals instead of uniform load. Use this after optimizing based on baseline and saturation tests to answer "will users have a good experience under realistic conditions?" Real production traffic doesn't consist of identical 512-token requests arriving like clockwork; users send varying lengths at random intervals, and this test validates your system handles that heterogeneity while maintaining acceptable percentile latencies for SLA setting.

## Configuration:

```bash
cat > 04-scenario-production.yaml <<'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-perf-production
  namespace: benchmarking
data:
  config.yml: |
    api:
      type: chat
      streaming: true

    data:
      type: synthetic
      input_distribution:
        mean: 1024
        std_dev: 512
        min: 128
        max: 4096
      output_distribution:
        mean: 512
        std_dev: 256
        min: 50
        max: 2048

    load:
      type: poisson  # Realistic bursty arrivals
      stages:
        - rate: 15
          duration: 600
      num_workers: 8

    server:
      type: vllm
      model_name: mistral-7b
      base_url: http://mistral-vllm.vllm-benchmark:8000
      ignore_eos: true

    tokenizer:
      pretrained_model_name_or_path: mistralai/Mistral-7B-Instruct-v0.3

    storage:
      simple_storage_service:
        bucket_name: "inference-perf-results"
        path: "production-sim/{timestamp}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: inference-perf-production
  namespace: benchmarking
  labels:
    app: inference-perf
    scenario: production
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: inference-perf
        scenario: production
    spec:
      restartPolicy: Never
      serviceAccountName: inference-perf-sa

      # Co-locate benchmark with inference pods for reproducible results
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: mistral-vllm
            topologyKey: topology.kubernetes.io/zone

      containers:
      - name: inference-perf
        image: quay.io/inference-perf/inference-perf:v0.2.0
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Installing dependencies for Mistral models..."
          pip install --no-cache-dir sentencepiece==0.2.0 protobuf==5.29.2
          echo "Dependencies installed successfully"
          echo "Starting Production Simulation Test..."
          inference-perf --config_file /workspace/config.yml
        volumeMounts:
        - name: config
          mountPath: /workspace/config.yml
          subPath: config.yml
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"

      volumes:
      - name: config
        configMap:
          name: inference-perf-production
EOF

kubectl apply -f 04-scenario-production.yaml
```

## Key Configuration:

* Variable synthetic data (Gaussian distributions for input/output)
* Poisson (bursty) arrivals instead of uniform load
* Streaming enabled

## Understanding the results:
Focus exclusively on P99 and P95 latency—these percentiles represent the worst experience that 99% and 95% of users encounter, unlike averages that hide poor tail performance. The wide input/output distributions create natural variability, so expect higher variance than baseline tests; this is normal and reflects production reality. Poisson bursts cause temporary queue buildup even at sustainable average rates, so if P99 is significantly worse than uniform-load testing suggested, you need more headroom than expected. Set SLAs based on these realistic percentiles, not averages—if P99 TTFT is 1200ms, don't promise sub-second latency even though mean might be 400ms.
