# SPEED, ROUTING AND LATENCY REQUIREMENTS

This file is intentionally separate because response speed is a critical requirement.

## Goals

Simple messages should not wait 20-25 seconds unless the upstream provider itself is
unavailable/slow.

Target:
- immediate local message echo
- immediate UI state change
- first token in ~1-3 seconds when possible
- continuously streamed text

## Mode routing

### Fast
Use the lowest-latency healthy conversational model.

### Auto
Classify the task cheaply:
- simple chat -> Fast
- code -> Coding
- reasoning -> Smart/Reasoning
- image -> Vision
- research -> Research

### Coding
Prefer coding/reasoning quality over raw speed, but stream early.

### Reasoning
Use stronger model and allow longer completion.

### Research
Use search/tools and source aggregation.

## Technical Rules

- persistent HTTP client
- HTTP/2 where supported
- keep-alive
- streaming
- request cancellation
- configurable connect timeout
- configurable first-token timeout
- circuit breaker
- provider health cache
- avoid retrying 5 slow providers sequentially
- max one fast fallback before showing an actionable error for simple chat
- let user Retry

## Timeout policy suggestion

Simple chat:
- connection timeout: 3-5s
- first-token timeout: 6-8s
- fallback once to next healthy route

Coding:
- first-token timeout can be longer, e.g. 12-20s

Generation jobs:
- asynchronous polling / WebSocket status

Do not hardcode these values if better provider-specific values are discovered.
