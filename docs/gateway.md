# Unified gateway setup and adapter contract

Build-time `UNIFIED_GATEWAY_BASE_URL` includes `/v1`. The app appends `/models`, `/chat/completions` and optionally `/capabilities`. Supply a reachable HTTPS endpoint; none was included with the prompt pack. Never put an API key in build configuration or source.

Normal setup has Unified API Key and Connect/Test. Advanced endpoint, capability and model metadata overrides require the master password under Developer / API Vault. A destination change clears its previous key. Dedicated generation/research/STT endpoints can have separate keys; these are optional.

## Chat contract

GET `/models` returns `{"data":[{"id":"actual-model-id","capabilities":["chat","coding","vision"],"context_length":32000,"latency_ms":500}]}`. Metadata is optional; absent metadata never implies vision support. Developer model metadata is an object keyed by actual model IDs. Tags include chat/coding/reasoning/vision/research/smart. Quality hints such as `coding_score` or `reasoning_score` rank models in their modes. Models are dynamically discovered, not hardcoded.

POST `/chat/completions` uses bearer authentication and OpenAI-compatible messages/model/stream. SSE data events are incrementally decoded, including fragmented Unicode and CRLF. Usage reporting is requested only for models advertising `supports_usage_stream:true`. Fast defaults to an 8-second first-token timeout, deeper modes 20 seconds, configurable 3–120 seconds. Connect timeout is 5 seconds. At most one fallback is allowed, only before visible output; failed routes cool down for 45 seconds. Upstream speed cannot be guaranteed.

## Optional capabilities

The following is an example schema, not a claim that an arbitrary gateway supports these paths. GET `/capabilities` can advertise the object, or the owner can enter it in Capability adapters JSON:

```json
{
  "research":{"path":"/search"},
  "stt":{"path":"/audio/transcriptions","model":"actual-stt-model"},
  "image_generation":{"path":"/images/generations","model":"actual-image-model"},
  "video_generation":{"path":"/videos","status_path":"/videos/{id}","cancel_path":"/videos/{id}/cancel","model":"actual-video-model"}
}
```

Research takes `{query}` and returns `sources:[{title,url,text}]`. URLs are deduplicated. Without a configured search adapter, Research fails clearly and does not pretend to browse.

STT accepts multipart file/model/response_format:verbose_json. Return text or `segments:[{start,end,text}]`. Android system STT/TTS is the default voice path; proprietary cloud TTS integration is not implemented.

Image generation takes prompt/aspect_ratio/quality/n/optional style. Video takes prompt/aspect_ratio/quality/duration/optional JPEG data URL image. Gateway adapters must normalize proprietary vendor schemas to this contract. A dedicated provider is not assumed to use a generic OpenAI endpoint.

Return synchronous `data:[{b64_json}]` or `data:[{url}]`, or an asynchronous `{id,status,progress}`. Poll GET status_path with escaped ID. Completion supplies `data` or `outputs`. Only an advertised cancel_path triggers remote cancellation. Local interruption retains remote IDs for resume and does not resubmit generation automatically.

Output URLs are public HTTPS, no redirects or credentials. Private/link-local destinations are blocked and the validated IP is used for connection. PNG/JPEG/MP4 byte signatures and a 100 MB limit apply. Missing capabilities show Provider not configured. Nothing is simulated.

## Optional semantic retrieval

Advertise `embeddings:{"path":"/embeddings","model":"actual-embedding-model"}` for semantic reranking of bounded source chunks. It accepts `{model,input:[text...]}` and returns OpenAI-compatible `data:[{index,embedding:[numbers]}]`. Vectors are cached locally and excluded from ordinary backup. This optional feature can consume provider tokens; no service/billing is auto-enabled. Without it, filename/keyword retrieval works.
