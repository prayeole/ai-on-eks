---
sidebar_label: Scenario 2 - Saturation Testing
---

# SCENARIO 2: Saturation Testing

## When to use this scenario:
Deploy saturation testing when you need to determine maximum sustainable throughput before performance degrades—critical for capacity planning, autoscaling thresholds, and preventing production overload. This multi-stage approach methodically increases load so you can observe exactly where your system transitions from healthy operation to overload, answering "how many requests per second can we handle while maintaining acceptable latency?" Use this before launches, after infrastructure changes, or when setting monitoring alerts and autoscaling policies.

## Configuration:

```bash
cat > 02-scenario-saturation.yaml <<'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-perf-saturation
  namespace: benchmarking
data:
  config.yml: |
    api:
      type: chat
      streaming: true

    data:
      type: synthetic
      input_distribution:
        mean: 512
        std_dev: 128
        min: 128
        max: 2048
      output_distribution:
        mean: 256
        std_dev: 64
        min: 32
        max: 512

    load:
      type: constant
      stages:
        - rate: 5
          duration: 180
        - rate: 10
          duration: 180
        - rate: 20
          duration: 180
        - rate: 40
          duration: 180
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
        path: "saturation-test/{timestamp}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: inference-perf-saturation
  namespace: benchmarking
  labels:
    app: inference-perf
    scenario: saturation
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: inference-perf
        scenario: saturation
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
          echo "Starting Saturation Test..."
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
          name: inference-perf-saturation
EOF

kubectl apply -f 02-scenario-saturation.yaml
```

## Key Configuration:

* Fixed-length synthetic data (512 input / 128 output tokens)
* Stepped constant load: 5, 10, 20, 40 QPS (180s each stage)
* Streaming enabled

## Understanding the results:
Look for the inflection point where TTFT suddenly spikes (2-3x baseline), TPS plateaus or drops, and error rates appear—this is your saturation point. In early stages, TTFT should stay near baseline with TPS increasing linearly; as you approach saturation, queueing causes latency to climb exponentially while throughput gains diminish. Set your production target at 50-70% of saturation (if saturating at 20 QPS, operate at 10-14 QPS) to maintain headroom for traffic bursts and ensure predictable latency. Pay attention to degradation patterns: gradual latency increases indicate good queue management, while sudden failures suggest poor overload handling.
