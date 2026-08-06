# Langfuse Tracing (opt-in)

hf.app's creed is **zero telemetry** — your prompts, conversations, and
downloaded weights stay on your machine. This repository ships an **opt-in**
Langfuse tracer (`Sources/HFMac/LangfuseTracer.swift`) that sends nothing
unless you explicitly enable it.

## Status: OFF by default

Tracing is **disabled** unless *all three* environment variables are set and
non-empty:

| Variable | Purpose |
|---|---|
| `LANGFUSE_HOST` | Base URL of your Langfuse instance (cloud or self-hosted) |
| `LANGFUSE_PUBLIC_KEY` | Langfuse public key |
| `LANGFUSE_SECRET_KEY` | Langfuse secret key |

If any of the three is missing, `LangfuseTracer.isEnabled` is `false` and
every tracer method is a no-op: no request is built, no network connection is
made, and your chats never leave the machine.

## Enabling

Run the app with the variables set in the environment:

```bash
LANGFUSE_HOST=https://cloud.langfuse.com \
LANGFUSE_PUBLIC_KEY=pk-... \
LANGFUSE_SECRET_KEY=sk-... \
swift run
```

or set them in your shell profile / launchd plist / Xcode scheme environment.

## What is traced

When enabled, each non-streaming `OsaurusClient.chat` completion posts a
single trace to `{LANGFUSE_HOST}/api/public/trace`:

- trace name, timestamp, and duration
- the model id and the assistant's reply (`output`)
- input token count when known, and the error message on failure

**The prompt itself is not included** — only the model, reply, timing, and
error metadata go out, keeping the payload minimal.

## Privacy stance

Opt-in only. The default build is identical to the zero-telemetry creed: no
analytics SDK, no tracking, no hidden calls. The tracer uses the platform
`URLSession` only after you have set all three `LANGFUSE_*` variables
yourself, and it swallows every error — tracing can never break a chat.
