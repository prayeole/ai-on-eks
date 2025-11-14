# Multi-Model Routing

Route requests to different AI models based on the `x-ai-eg-model` header.

## Prerequisites

Deploy common infrastructure first:
```bash
cd ../
kubectl apply -f gateway.yaml
```

## Deploy

```bash
kubectl apply -f ai-gateway-route.yaml
```

## Test

```bash
python3 client.py
```

## Manual Testing

```bash
# Test gpt-oss-20b
curl -X POST http://$GATEWAY_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-ai-eg-model: openai/gpt-oss-20b" \
  -d '{"model": "openai/gpt-oss-20b", "messages": [{"role": "user", "content": "Hello!"}], "max_tokens": 50}'

# Test llama-3b
curl -X POST http://$GATEWAY_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-ai-eg-model: NousResearch/Llama-3.2-1B" \
  -d '{"model": "NousResearch/Llama-3.2-1B", "messages": [{"role": "user", "content": "Hello!"}], "max_tokens": 50}'
```

## Troubleshooting

- **404 errors**: Check if `ai-gateway-route.yaml` is applied
- **Model not responding**: Verify backend services are running

```bash
# Check route status
kubectl get aigatewayroute multi-model-route -o yaml

# Check backend services
kubectl get svc | grep -E "(llama|gpt-oss)"
```
