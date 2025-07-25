#!/usr/bin/env python3
"""
Quick Test Script for AI Observability
======================================

Test the configuration and connectivity to observability stack
and Azure OpenAI without running full analysis.
"""

import os
import asyncio
import aiohttp
from dotenv import load_dotenv
from openai import AzureOpenAI

async def test_connectivity():
    """Test connectivity to all endpoints"""
    load_dotenv()
    
    print("🧪 Testing AI Observability Configuration\n")
    
    # Test Azure OpenAI
    print("1. Testing Azure OpenAI connection...")
    try:
        client = AzureOpenAI(
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview"),
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
        )
        
        response = client.chat.completions.create(
            model=os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4"),
            messages=[{"role": "user", "content": "Test message"}],
            max_tokens=10
        )
        print("   ✅ Azure OpenAI connection successful")
        
    except Exception as e:
        print(f"   ❌ Azure OpenAI connection failed: {e}")
    
    # Test Loki
    print("\n2. Testing Loki connection...")
    try:
        loki_endpoint = os.getenv("LOKI_ENDPOINT")
        if loki_endpoint:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{loki_endpoint}/ready") as response:
                    if response.status == 200:
                        print("   ✅ Loki connection successful")
                    else:
                        print(f"   ⚠️  Loki returned status {response.status}")
        else:
            print("   ❌ LOKI_ENDPOINT not configured")
    except Exception as e:
        print(f"   ❌ Loki connection failed: {e}")
    
    # Test Prometheus
    print("\n3. Testing Prometheus connection...")
    try:
        prometheus_endpoint = os.getenv("PROMETHEUS_ENDPOINT")
        if prometheus_endpoint:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{prometheus_endpoint}/-/healthy") as response:
                    if response.status == 200:
                        print("   ✅ Prometheus connection successful")
                    else:
                        print(f"   ⚠️  Prometheus returned status {response.status}")
        else:
            print("   ❌ PROMETHEUS_ENDPOINT not configured")
    except Exception as e:
        print(f"   ❌ Prometheus connection failed: {e}")
    
    # Test simple Loki query
    print("\n4. Testing Loki query...")
    try:
        loki_endpoint = os.getenv("LOKI_ENDPOINT")
        if loki_endpoint:
            url = f"{loki_endpoint}/loki/api/v1/labels"
            async with aiohttp.ClientSession() as session:
                async with session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()
                        print(f"   ✅ Loki query successful - {len(data.get('data', []))} labels found")
                    else:
                        print(f"   ❌ Loki query failed with status {response.status}")
    except Exception as e:
        print(f"   ❌ Loki query failed: {e}")
    
    # Test simple Prometheus query
    print("\n5. Testing Prometheus query...")
    try:
        prometheus_endpoint = os.getenv("PROMETHEUS_ENDPOINT")
        if prometheus_endpoint:
            url = f"{prometheus_endpoint}/api/v1/query"
            params = {"query": "up"}
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        results = data.get('data', {}).get('result', [])
                        print(f"   ✅ Prometheus query successful - {len(results)} metrics found")
                    else:
                        print(f"   ❌ Prometheus query failed with status {response.status}")
    except Exception as e:
        print(f"   ❌ Prometheus query failed: {e}")
    
    print("\n🏁 Test completed!")
    print("\nIf any tests failed, check your .env configuration:")
    print("- AZURE_OPENAI_ENDPOINT")
    print("- AZURE_OPENAI_API_KEY")
    print("- LOKI_ENDPOINT") 
    print("- PROMETHEUS_ENDPOINT")

if __name__ == "__main__":
    asyncio.run(test_connectivity())
