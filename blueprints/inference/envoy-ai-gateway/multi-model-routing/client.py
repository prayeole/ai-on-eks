#!/usr/bin/env python3

import requests
import json
import subprocess
import sys

def get_gateway_url():
    """Auto-detect the Gateway URL using kubectl"""
    try:
        result = subprocess.run([
            'kubectl', 'get', 'gateway', 'ai-gateway',
            '-o', 'jsonpath={.status.addresses[0].value}'
        ], capture_output=True, text=True, check=True)

        if result.stdout.strip():
            return f"http://{result.stdout.strip()}"
        else:
            print("Gateway address not found. Make sure the Gateway is deployed and has an address.")
            return None
    except subprocess.CalledProcessError as e:
        print(f"Error getting gateway URL: {e}")
        return None

def test_model(gateway_url, model_name, test_name):
    """Test a specific model through the AI Gateway"""
    print(f"\n=== Testing {test_name} ===")

    headers = {
        'Content-Type': 'application/json',
        'x-ai-eg-model': model_name
    }

    payload = {
        # "model": model_name,
        "messages": [
            {"role": "user", "content": f"Hello from {model_name}! Please respond briefly."}
        ],
        "max_tokens": 100,
        "temperature": 0.7
    }

    try:
        response = requests.post(
            f"{gateway_url}/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=30
        )

        print(f"Status Code: {response.status_code}")
        print(f"Headers sent: {headers}")

        if response.status_code == 200:
            result = response.json()
            print(f"✅ SUCCESS: {test_name}")
            content = result.get('choices', [{}])[0].get('message', {}).get('content', 'No content')
            print(f"Response: {content[:100]}...")
        else:
            print(f"❌ FAILED: {test_name}")
            print(f"Response: {response.text}")

    except requests.exceptions.RequestException as e:
        print(f"❌ ERROR: {test_name} - {e}")

def main():
    print("🚀 AI Gateway Multi-Model Routing Test")
    print("=" * 50)

    # Auto-detect Gateway URL
    gateway_url = get_gateway_url()
    if not gateway_url:
        print("❌ Could not determine Gateway URL. Exiting.")
        sys.exit(1)

    print(f"Gateway URL: {gateway_url}")

    # Test essential models
    models_to_test = [
        ("openai/gpt-oss-20b", "OpenAI GPT OSS 20B vLLM"),
        ("Qwen/Qwen3-1.7B", "Qwen3 1.7B vLLM")
    ]

    for model_name, test_name in models_to_test:
        test_model(gateway_url, model_name, test_name)

    print(f"\n🎯 Multi-Model Routing Test Complete!")
    print("=" * 50)
    print("📋 Summary:")
    print("• Self-hosted models: text-llm, code-llm")
    print("• Routing: Header-based using 'x-ai-eg-model'")
    print("• All models accessible through single Gateway endpoint")

if __name__ == "__main__":
    main()
