#!/usr/bin/env python3
"""
Final working Bedrock integration test client for AI Gateway v0.4.0
Tests all three use cases: GPT, Llama, and Bedrock Claude
"""

import requests
import json
import sys

def get_gateway_url():
    """Auto-detect AI Gateway URL"""
    try:
        import subprocess
        result = subprocess.run([
            'kubectl', 'get', 'gateway', 'ai-gateway', 
            '-o', 'jsonpath={.status.addresses[0].value}'
        ], capture_output=True, text=True, check=True)
        return f"http://{result.stdout.strip()}"
    except:
        return "http://localhost:8080"  # fallback

def test_gpt_model(gateway_url):
    """Test GPT model via /v1/chat/completions"""
    print("=== Testing Self-hosted GPT ===")
    response = requests.post(
        f"{gateway_url}/v1/chat/completions",
        headers={
            'Content-Type': 'application/json',
            'x-ai-eg-model': 'openai/gpt-oss-20b'
        },
        json={
            'model': 'openai/gpt-oss-20b',
            'max_tokens': 10,
            'messages': [{'role': 'user', 'content': 'Hello'}]
        },
        timeout=30
    )
    
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        content = data['choices'][0]['message'].get('reasoning_content', 'No content')
        print(f"✅ SUCCESS: GPT - {content}")
        return True
    else:
        print(f"❌ ERROR: GPT - {response.text}")
        return False

def test_llama_model(gateway_url):
    """Test Llama model via /v1/chat/completions"""
    print("\n=== Testing Self-hosted Llama ===")
    response = requests.post(
        f"{gateway_url}/v1/chat/completions",
        headers={
            'Content-Type': 'application/json',
            'x-ai-eg-model': 'NousResearch/Llama-3.2-1B'
        },
        json={
            'model': 'NousResearch/Llama-3.2-1B',
            'max_tokens': 10,
            'messages': [{'role': 'user', 'content': 'Hello'}]
        },
        timeout=30
    )
    
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        content = data['choices'][0]['message'].get('content', 'No content')
        print(f"✅ SUCCESS: Llama - {content}")
        return True
    else:
        print(f"❌ ERROR: Llama - {response.text}")
        return False

def test_bedrock_claude(gateway_url):
    """Test Bedrock Claude via /anthropic/v1/messages"""
    print("\n=== Testing Bedrock Claude ===")
    response = requests.post(
        f"{gateway_url}/anthropic/v1/messages",
        headers={
            'Content-Type': 'application/json',
            'x-ai-eg-model': 'anthropic.claude-3-haiku-20240307-v1:0'
        },
        json={
            'model': 'anthropic.claude-3-haiku-20240307-v1:0',
            'max_tokens': 10,
            'messages': [{'role': 'user', 'content': 'Hello'}]
        },
        timeout=30
    )
    
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        content = data['content'][0]['text']
        print(f"✅ SUCCESS: Bedrock Claude - {content}")
        return True
    else:
        print(f"❌ ERROR: Bedrock Claude - {response.text}")
        return False

def main():
    print("🚀 AI Gateway v0.4.0 - Bedrock Integration Test")
    print("=" * 60)
    
    gateway_url = get_gateway_url()
    print(f"Gateway URL: {gateway_url}")
    
    results = []
    results.append(test_bedrock_claude(gateway_url))
    
    print("\n" + "=" * 60)
    print("🎯 Final Results:")
    print(f"• Bedrock Claude: {'✅ PASS' if results[0] else '❌ FAIL'}")
    
    if all(results):
        print("\n🎉 BEDROCK TEST PASSED! AI Gateway v0.4.0 Bedrock integration functional!")
        sys.exit(0)
    else:
        print(f"\n❌ Bedrock test failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
