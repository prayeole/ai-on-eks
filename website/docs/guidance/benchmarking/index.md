---
sidebar_label: Benchmarking LLM Inference Performance on Amazon EKS
---

# Benchmarking Guide (With Inference Perf)

As more organizations deploy large language models (LLMs) on their own infrastructure, understanding how to measure performance has become a common challenge.

Customers often ask: *How do I benchmark my self-hosted LLM? Which metrics matter? And what do those numbers actually mean for real workloads?* Benchmarking LLMs is not as straightforward as testing traditional AI models. LLMs have billions of parameters and their performance depends on many factors—such as hardware setup, memory bandwidth, quantization, KV-cache behavior, and parallelism strategy. Even small changes in configuration, prompt length, or user behavior can produce large differences in throughput, latency. Production workloads can shift unexpectedly, if users suddenly max out your context length when you weren't testing for it, performance will degrade significantly.

Without a clear benchmarking framework, teams struggle to compare hardware options, tune models efficiently, or predict deployment costs. This guide focuses on **inference performance benchmarking; measuring throughput, latency, and resource utilization** to help customers optimize deployment configurations, understand key metrics in practice, and implement a structured approach to analyzing and improving inference performance.

## What This Guide Covers

This guide provides a comprehensive approach to benchmarking LLM inference performance:

- **[Understanding the Benchmark Challenge](./1-understanding-the-benchmark-challenge/)** - Why LLM benchmarking is complex and what makes it different from traditional AI models
- **[Key Metrics for Benchmarking LLMs](./2-key-metrics-for-benchmarking-llms/)** - Essential metrics (TTFT, ITL, TPS) and what they mean for your deployment
- **[Benchmarking with Inference Perf](./3-benchmarking-with-inference-perf/1-inference-perf)** - Using the standardized Inference Perf tool to measure performance
- **Test Scenarios** - Practical examples for baseline, saturation, production simulation, and real dataset testing
- **Resources** - Complete deployment examples and reference configurations
