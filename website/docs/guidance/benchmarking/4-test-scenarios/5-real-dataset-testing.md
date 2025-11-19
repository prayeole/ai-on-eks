---
sidebar_label: Scenario 5 - Real Dataset Testing
---

# SCENARIO 5: Real Dataset Testing

## When to use this scenario:
Use real dataset testing to validate production-ready performance with actual user prompts and query patterns. This is essential when your model is fine-tuned for specific conversation patterns, when comparing model versions with real-world performance guarantees, or when you need to tell stakeholders "this is how it performs on actual conversations, not theoretical data." The tradeoff is less control over distributions, but you gain authenticity and the ability to discover edge cases that synthetic data misses.

## Configuration:

```bash
cat > 05-scenario-sharegpt.yaml <<'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-perf-sharegpt
  namespace: benchmarking
data:
  config.yml: |
    api:
      type: chat
      streaming: true

    data:
      type: shareGPT

    load:
      type: constant
      stages:
        - rate: 10
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
        path: "sharegpt-test/{timestamp}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: inference-perf-sharegpt
  namespace: benchmarking
  labels:
    app: inference-perf
    scenario: sharegpt
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: inference-perf
        scenario: sharegpt
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
          echo "Starting ShareGPT Real Data Test..."
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
          name: inference-perf-sharegpt
EOF

kubectl apply -f 05-scenario-sharegpt.yaml
```

## Key Configuration:

* ShareGPT real conversation dataset
* Constant load at 10 QPS for 300 seconds
* Streaming enabled

## Understanding the results:
Real conversations reveal natural complexity patterns and edge cases absent from synthetic data—look for latency outliers that expose problematic conversation structures or phrasings causing slow processing. Compare real data performance against synthetic tests at similar QPS; significant degradation suggests real conversations are more complex than your synthetic parameters assumed, helping calibrate future synthetic tests. TTFT variability will be higher due to natural context length variance from multi-turn dialogues, and any consistent error patterns with specific conversation types reveal production vulnerabilities worth targeted optimization. Use these results as ground truth for stakeholder commitments—base your "P99 latency will be X" promises on real data, not synthetic.

**⚠️ Critical:** Regularly update your test dataset with recent anonymized production samples to prevent drift. If your benchmark dataset is 6 months old but user behavior has shifted to longer prompts, your performance predictions will be inaccurate.
