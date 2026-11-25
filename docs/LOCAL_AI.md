# CUBYTE hybrid AI (v0.4 experimental)

Online is the default UI selection; nothing is sent until Ask or Test connection. Offline GGUF remains available. Android INTERNET permission is now enabled for this build, but native artifact tasks still work offline.

## Online setup

Open Talk to robot / AI settings. Select Gemini, OpenRouter, Groq, or OpenAI. Enter a currently supported chat model ID and your own provider API key. Test connection sends a small chat request, which may consume quota or credits. Ask robot sends the entered prompt; robot memory, imported skill excerpt, personality and recent chat are sent only if the optional context checkbox is enabled. Provider policies apply. No automatic provider fallback, downloads or background requests.

Credentials are masked and held only for this app session; Clear key or change provider to remove the field. No credential files or shared developer key. Persistent Android Keystore storage is deferred. Do not put credentials in chat prompts, imported skills, or source code. TLS uses the platform's normal validation and HTTP redirects are disabled. Cancellation stops waiting locally, not necessarily provider execution or billing.

Provider model IDs and quotas change; use the provider's model catalog. API plans may be separate from consumer chat subscriptions. Only supported text chat completion models are targeted. The initial test suite checks request construction and response validation without a live API key.

Both AI modes use the same local permission checks and require explicit approval of a parsed TXT or fixed sample PNG proposal. Local artifacts and profile data stay local unless you deliberately include them in a prompt or enable context sharing.

## Offline GGUF
The Android ARM64 APK is built with a CPU-only llama.cpp GDExtension. No model is included, the offline mode does not require a connection, and the core office works without a model. Use only trusted, compatible instruction/chat GGUF files; the first implementation pins llama.cpp b5046 and godot-cpp 4.4.1. This is an initial compatibility pin, not a current-security audit.

Select Offline AI (GGUF) in AI settings, choose a readable local GGUF file path, Load, select context and threads, and ask. Model files are opened in place rather than copied; Android scoped storage can prevent access to Downloads. SAF content URI import and persistent model library are not yet implemented. Start with a small supported quantized instruction model, e.g. Qwen2.5 0.5B Instruct Q4; actual performance and compatibility must be tested on device. The 3 GiB file limit is not a RAM guarantee. Smaller context, two threads and 192 output tokens are defaults. Cancel requests cooperative cancellation; there is no hard kill.

Each request allocates a fresh context, using one shared model and bounded per-robot in-session chat, profile memory and active skill excerpt. Chat history is not persisted. Imported skills are untrusted data. Model output may be incorrect, and only strict JSON proposals for existing TXT or fixed sample PNG tools can be approved manually. Permissions are checked again on enqueue and execution. No arbitrary code, autonomous planning or remote calls.

CI checks compilation, extension registration and no-model error paths, policy validation and APK packaging. It does not yet run model inference with a real GGUF or test Android device performance. Debug signing is ephemeral; back up important app data before changing builds.
