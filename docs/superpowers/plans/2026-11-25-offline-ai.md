# Offline AI v0.3 — implementation plan
Base: verified v0.2, separate feature branch. Goal: actual CPU-only GGUF inference via a Godot GDExtension; no network permission, server, or Termux.
- Native bridge: godot-cpp 4.4.1, llama.cpp b5046 (initial compatibility pin), NDK arm64, CMake, static llama dependencies; one model, fresh inference context per request, bounded context and thread counts, cancellable generation.
- GDScript model path validation, per-robot bounded chat history in memory, profile and active skill context, one worker thread; explicit load/unload and generate. No model bundled.
- Model output is never trusted as authorization. Structured JSON proposal is parsed only for known native tools, rechecked against roster permissions, shown to user and executed only on explicit confirmation.
- Headless tests validate GGUF header and proposal schema, then existing tests. Native build must compile and APK must include arm64 extension. Test actual model on device separately. File chooser initially uses accessible filesystem paths; Android Storage Access Framework integration remains a follow-up if needed.
- Model runtime is optional for core game; native load failures are visible. No claims of device performance before measurements.
