# Experimental local AI (v0.3)

The Android ARM64 APK is built with a CPU-only llama.cpp GDExtension. No model is included, no internet permission is requested, and the core office works without a model. Use only trusted, compatible instruction/chat GGUF files; the first implementation pins llama.cpp b5046 and godot-cpp 4.4.1. This is an initial compatibility pin, not a current-security audit.

Open Talk to robot / Local AI, choose a readable local GGUF file path, Load, select context and threads, and ask. Model files are opened in place rather than copied; Android scoped storage can prevent access to Downloads. SAF content URI import and persistent model library are not yet implemented. Start with a small supported quantized instruction model, e.g. Qwen2.5 0.5B Instruct Q4; actual performance and compatibility must be tested on device. The 3 GiB file limit is not a RAM guarantee. Smaller context, two threads and 192 output tokens are defaults. Cancel requests cooperative cancellation; there is no hard kill.

Each request allocates a fresh context, using one shared model and bounded per-robot in-session chat, profile memory and active skill excerpt. Chat history is not persisted. Imported skills are untrusted data. Model output may be incorrect, and only strict JSON proposals for existing TXT or fixed sample PNG tools can be approved manually. Permissions are checked again on enqueue and execution. No arbitrary code, autonomous planning or remote calls.

CI checks compilation, extension registration and no-model error paths, policy validation and APK packaging. It does not yet run model inference with a real GGUF or test Android device performance. Debug signing is ephemeral; back up important app data before changing builds.
