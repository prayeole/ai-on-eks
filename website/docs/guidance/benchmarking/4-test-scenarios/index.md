---
sidebar_label: Test Scenarios
---

# Test Scenarios

This section provides practical test scenarios for benchmarking LLM inference performance. Each scenario addresses specific testing objectives and use cases.

## Available Scenarios

### [Choosing Between Synthetic and Real Dataset Testing](./0-choosing-synthetic-vs-real)
Understand when to use synthetic vs. real-world data for benchmarking and best practices for dataset selection.

### [Scenario 1: Baseline Performance](./1-baseline-performance)
Establish your system's optimal performance with zero contention. Ideal for understanding the best-case performance without queueing or resource competition.

**Use when:**
- Just deployed a new endpoint
- Made infrastructure changes
- Need a clean reference point for optimization

### [Scenario 2: Saturation Testing](./2-saturation-testing)
Determine maximum sustainable throughput before performance degrades through multi-stage load testing.

**Use when:**
- Planning capacity
- Setting autoscaling thresholds
- Validating before production launch

### [Scenario 3: Automatic Saturation Detection](./3-automatic-saturation-detection)
Use sweep mode for automated capacity discovery without manual QPS guessing.

**Use when:**
- Initial deployments
- CI/CD pipelines
- Quick capacity re-validation

### [Scenario 4: Production Simulation](./4-production-simulation)
Replicate real-world traffic with variable request sizes and bursty (Poisson) arrivals.

**Use when:**
- Final validation before launch
- Setting SLA targets
- Validating realistic workload handling

### [Scenario 5: Real Dataset Testing](./5-real-dataset-testing)
Validate production-ready performance using actual user prompts and query patterns.

**Use when:**
- Model fine-tuned for specific patterns
- Comparing model versions
- Need authentic performance guarantees

## Implementation Notes

All scenarios in this section use **runtime dependency installation** (Approach A) for simplicity and flexibility. Dependencies are installed in the main container at startup, not through init-containers.

For production deployments requiring faster startup times, consider building a custom container image with pre-installed dependencies as described in the [Complete Deployment Example](../3-benchmarking-with-inference-perf/3-complete-deployment-example-guide#approach-b-custom-container-image-advanced).
