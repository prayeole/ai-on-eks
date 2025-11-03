# Multi-Model Routing

Route requests to different AI models based on the `x-ai-eg-model` header.

## Prerequisites

Deploy common infrastructure first:
```bash
cd ../
kubectl apply -f gateway.yaml
kubectl apply -f text-llm.yaml
kubectl apply -f deepseek.yaml
```

## Deploy

```bash
kubectl apply -f ai-gateway-route.yaml
kubectl apply -f reference-grant.yaml
```

## Test

```bash
python3 client.py
```

## Supported Models

| Header Value | Model | Status |
|-------------|-------|---------|
| `text-llm` | vLLM on Inferentia2 | ✅ Working |
| `deepseek-r1-distill-llama-8b` | DeepSeek R1 Distill | ✅ Working |

## Manual Testing

```bash
# Test text-llm
curl -X POST http://$GATEWAY_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-ai-eg-model: text-llm" \
  -d '{"model": "text-llm", "messages": [{"role": "user", "content": "Hello!"}], "max_tokens": 50}'

# Test deepseek
curl -X POST http://$GATEWAY_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-ai-eg-model: deepseek-r1-distill-llama-8b" \
  -d '{"model": "deepseek-r1-distill-llama-8b", "messages": [{"role": "user", "content": "Hello!"}], "max_tokens": 50}'
```

## Troubleshooting

- **404 errors**: Check if `ai-gateway-route.yaml` is applied
- **Cross-namespace access**: Ensure `reference-grant.yaml` is applied
- **Model not responding**: Verify backend services are running

```bash
# Check route status
kubectl get aigatewayroute multi-model-route -o yaml

# Check backend services
kubectl get svc | grep -E "(text-llm|deepseek)"
```
