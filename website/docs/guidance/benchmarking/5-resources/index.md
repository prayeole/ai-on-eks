---
sidebar_label: Resources
---

# Resources

## Custom Container with SentencePiece

```bash
# Create a custom Dockerfile
cat > Dockerfile <<'EOF'
FROM quay.io/inference-perf/inference-perf:v0.2.0

# Install sentencepiece
RUN pip install --no-cache-dir sentencepiece protobuf

USER 1000
EOF

# Build and push to your registry
docker build -t <your-registry>/inference-perf:v0.2.0-sentencepiece .
docker push <your-registry>/inference-perf:v0.2.0-sentencepiece

# Update your Job to use the new image
kubectl patch job inference-perf-run -n benchmarking \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"<your-registry>/inference-perf:v0.2.0-sentencepiece"}]'
```

## Deployment file

```bash
cat > inference-perf-fixed.yaml <<'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: benchmarking
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inference-perf-sa
  namespace: benchmarking
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-perf-config
  namespace: benchmarking
data:
  config.yml: |
    load_generator:
      concurrency: 10
      duration: 60

    model:
      model_name: mistral-7b
      base_url: http://mistral-vllm.vllm-benchmark:8000
      ignore_eos: true

      tokenizer:
        pretrained_model_name_or_path: mistralai/Mistral-7B-Instruct-v0.3

    storage:
      simple_storage_service:
        bucket_name: "inference-perf-results-877558825016"
        path: "inference-perf/{timestamp}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: inference-perf-run
  namespace: benchmarking
  labels:
    app: inference-perf
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: inference-perf
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
            echo "Installing dependencies..."
            pip install --no-cache-dir sentencepiece==0.2.0 protobuf==5
            echo "Dependencies installed successfully"
            echo "Starting inference-perf..."
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
            name: inference-perf-config
EOF
```

## Execution

```bash
kubectl apply -f inference-perf-fixed.yaml
```
