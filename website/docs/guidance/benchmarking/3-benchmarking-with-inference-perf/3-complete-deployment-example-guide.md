---
sidebar_label: Complete Deployment Example
---

# Complete Deployment Example

This example demonstrates a production-ready deployment with S3 storage, realistic load testing, and proper AWS integration. Follow these steps to deploy your benchmark.

### STEP 0: ENVIRONMENT SETUP (OPTIONAL)

Choose your deployment path:

Path A (Recommended): Use ai-on-eks blueprint

* Deploys kube-prometheus-stack automatically
* Fixed Prometheus URL: http://kube-prometheus-stack-prometheus.monitoring:9090
* Follow: https://awslabs.github.io/ai-on-eks/docs/infra/inference-ready-cluster 

Path B:  Existing EKS Cluster

If you have an existing cluster, ensure these prerequisites:

* EKS cluster with Kubernetes 1.28+
* Pod Identity or IRSA configured for S3 access
* kubectl configured with cluster access
* optional Prometheus pre-deployed

### STEP 1:  AWS Storage Setup (Using S3 - Recommendation)

Note: If you deployed your cluster using the ai-on-eks inference-ready-cluster blueprint, the EKS Pod Identity Agent addon is already installed. You can skip the addon installation command below and proceed directly to creating the IAM role and pod identity association.

```bash
# Install EKS Pod Identity Agent (already deployed on the blueprint reference - https://awslabs.github.io/ai-on-eks/docs/infra/inference-ready-cluster)

aws eks create-addon \
  --cluster-name my-cluster \
  --addon-name eks-pod-identity-agent \
  --addon-version v1.3.0-eksbuild.1

# Create IAM role with S3 permissions

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "pods.eks.amazonaws.com"
    },
    "Action": [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }]
}
EOF

aws iam create-role \
  --role-name InferencePerfRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name InferencePerfRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Link the role to your Kubernetes service account

aws eks create-pod-identity-association \
  --cluster-name my-cluster \
  --namespace benchmarking \
  --service-account inference-perf-sa \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/InferencePerfRole
```

### STEP 2: Deploy Kubernetes Resources

This single manifest creates everything you need: namespace, service account, configuration, and the benchmark job itself.

#### Handling Model Dependencies

Some models require additional Python packages that aren’t included in the base inference-perf container. The most common requirement is sentencepiece for Mistral and Llama models.

##### Two approaches:

###### Approach A: Runtime Installation (Recommended - Simple)

Install dependencies as part of the main container startup before running the benchmark:

```yaml
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
      
      ...
      
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
```

###### Approach B: Custom Container Image (Advanced)

Build a custom image with dependencies pre-installed:

```yaml
FROM quay.io/inference-perf/inference-perf:v0.2.0
RUN pip install --no-cache-dir sentencepiece==0.2.0 protobuf==5.29.2
```

#### Create HuggingFace Token Secret (Optional but Recommended)

If your model requires authentication to download tokenizers from HuggingFace, create a secret using the command below. This approach is more secure than defining secrets in YAML files that might accidentally be committed to version control.

```bash
kubectl create secret generic hf-token \
  --from-literal=token=YOUR_HUGGINGFACE_TOKEN_HERE \
  --namespace=benchmarking
```

#### Create Job & configMap

```yaml
cat <<EOF | kubectl apply -f -
# Benchmark Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-perf-config
  namespace: benchmarking
data:
  config.yml: |
    # API Configuration
    api:
      type: chat
      streaming: true
    # Data Generation - synthetic with realistic distributions
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
    # Load Pattern - Poisson arrivals at 10 QPS for 5 minutes
    load:
      type: poisson
      stages:
        - rate: 10
          duration: 300
      num_workers: 4
    # Model Server
    server:
      type: vllm
      model_name: Qwen/Qwen2.5-Omni-7B
      base_url: http://vllm-service.default:8000
      ignore_eos: true
    # Storage - Results automatically saved to S3
    storage:
      simple_storage_service:
        bucket_name: "inference-perf-results"
        path: "inference-perf/results"
    # Optional: Prometheus metrics collection
    # metrics:
    #   type: prometheus
    #   prometheus:
    #     url: http://kube-prometheus-stack-prometheus.monitoring:9090
    #     scrape_interval: 15
EOF
---

cat <<EOF | kubectl apply -f -
# Benchmark Job
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
                app.kubernetes.io/component: mistral-vllm
            topologyKey: topology.kubernetes.io/zone     
      
      # InitContainer for model dependencies
      initContainers:
      - name: install-deps
        image: quay.io/inference-perf/inference-perf:v0.2.0
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Installing dependencies for Mistral/Llama models..."
            pip install --target=/deps --no-cache-dir sentencepiece==0.2.0 protobuf==5.29.2
            echo "Dependencies installed"
        volumeMounts:
          - name: python-deps
            mountPath: /deps
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
      containers:
      - name: inference-perf
        image: quay.io/inference-perf/inference-perf:v0.2.0
        command: ["inference-perf"]
        args:
          - "--config_file"
          - "/workspace/config.yml"
        volumeMounts:
          - name: config
            mountPath: /workspace/config.yml
            subPath: config.yml
          - name: python-deps
            mountPath: /deps
        env:
          - name: PYTHONPATH
            value: "/deps"
          - name: HF_TOKEN
            valueFrom:
              secretKeyRef:
                name: hf-token
                key: token
                optional: true
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
        - name: python-deps
          emptyDir: {}
EOF
```

### STEP 3: Retrieve Results

With S3 Storage (Recommended) the results are automatically uploaded to your S3 bucket. Access them directly:

```bash
aws s3 cp s3://inference-perf-results/inference-perf/results/summary_lifecycle_metrics.json .
```

With local storage, copy the results before the pod terminates, if 

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n benchmarking -l app=inference-perf -o jsonpath='{.items[0].metadata.name}')

# Copy results from pod
kubectl cp benchmarking/$POD_NAME:/reports-* ./local-reports/
```