---
sidebar_label: Scenario 1 - Baseline Performance
---

# SCENARIO 1: Baseline Performance

## When to use this scenario:
Use baseline testing when establishing your system's optimal performance with zero contention—essentially taking your infrastructure's vital signs. This is your starting point before any capacity planning or optimization work, ideal when you've just deployed a new endpoint or made infrastructure changes. It answers "what's the best performance this system can deliver?" without queueing or resource competition, giving you a clean reference point for all future testing.

## Configuration:

```bash
cat > 01-scenario-baseline.yaml <<'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-perf-baseline
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
        std_dev: 0
        min: 512
        max: 512
      output_distribution:
        mean: 128
        std_dev: 0
        min: 128
        max: 128

    load:
      type: constant
      stages:
        - rate: 1
          duration: 300
      num_workers: 4

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
        path: "baseline-test/{timestamp}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: inference-perf-baseline
  namespace: benchmarking
  labels:
    app: inference-perf
    scenario: baseline
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: inference-perf
        scenario: baseline
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
          echo "Starting Baseline Performance Test..."
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
          name: inference-perf-baseline
EOF

kubectl apply -f 01-scenario-baseline.yaml
```

## Key Configuration:

* Fixed-length synthetic data (512 input / 128 output tokens)
* Constant load at 1 QPS for 300 seconds
* Streaming enabled

## Understanding the results:
Your TTFT and ITL at 1 QPS represent the theoretical minimum latency, the absolute fastest your system can respond with zero queueing or contention. If baseline TTFT is 800ms, users will never see faster response times regardless of optimizations, like adding replicas, load balancers, or autoscaling, because these improve **throughput and concurrency**, not single-request speed. Focus on these metrics as your performance floor: schedule delay should be near zero (<10ms), and any deviation indicates the test runner itself needs more resources. Compare baseline numbers against your Service Level Agreement (SLA)  targets—if baseline performance doesn't meet requirements, you need model/hardware optimization before worrying about scale, as adding capacity won't improve fundamental inference speed.
