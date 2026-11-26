# CUBYTE AI access — offline-first + BYOK

The game defaults to offline AI. Download Qwen2.5 0.5B Instruct Q4_K_M (approximately 491 MB) through AI Settings. The app verifies the pinned file hash before installation, then selects offline mode. Native llama.cpp inference runs on the device with no cloud account or API quota.

## Personal cloud providers

Choose OpenAI, Google Gemini, Groq, OpenRouter or DeepSeek, enter your own restricted API key, fetch the provider's model list or enter a chat model ID, and use Test connection. Listing is bounded to the first returned page and 500 entries; not all listed models are compatible with text chat or available to every account. A generation test consumes provider quota and may incur a charge.

Keys and selected models are kept separately in memory for each provider for the current process only. Clearing a key removes that provider's session entry. No credential is written to disk; Android Keystore persistence is not implemented yet. Restarting the app requires entering the key again. Requests use fixed HTTPS origins, no HTTP redirects, and sanitized error messages. Do not use shared production credentials.

The game no longer calls the CUBYTE guest gateway for chat or requires Firebase authentication. The backend source remains available for maintenance; existing deployments must be disabled separately by their owner.

The optional local fallback applies only to eligible cloud transport, throttling, or transient service failures when a verified model is installed and the player opts in. It makes no second cloud request. All tool actions still require permission checks and player approval. Extra cloud context sharing remains optional.

## Validation

Godot protocol tests exercise fixed provider origins, credential headers, model-list parsing, Gemini response parsing, and safe error handling. CI builds the Linux and Android native bridge and checks APK packaging. Live calls require a user's own key; device model download and generation must be tested separately.
