#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <llama.h>
#include <sqlite3.h>
#include <algorithm>
#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

using namespace godot;
class CubyteLlama : public RefCounted {
    GDCLASS(CubyteLlama, RefCounted)
    llama_model *model = nullptr;
    std::atomic<bool> cancelled{false};
    std::mutex mutex;
    static Dictionary result(bool ok, const String &text, const String &error) {
        Dictionary d; d["ok"] = ok; d["text"] = text; d["error"] = error; return d;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("load_model", "path"), &CubyteLlama::load_model);
        ClassDB::bind_method(D_METHOD("unload_model"), &CubyteLlama::unload_model);
        ClassDB::bind_method(D_METHOD("generate", "system", "prompt", "context", "threads", "max_tokens"), &CubyteLlama::generate);
        ClassDB::bind_method(D_METHOD("cancel"), &CubyteLlama::cancel);
        ClassDB::bind_method(D_METHOD("reset_cancel"), &CubyteLlama::reset_cancel);
    }
public:
    ~CubyteLlama() override { if (model) llama_model_free(model); }
    void cancel() { cancelled.store(true); }
    void reset_cancel() { cancelled.store(false); }
    Dictionary unload_model() {
        std::lock_guard<std::mutex> guard(mutex);
        if (model) { llama_model_free(model); model = nullptr; }
        return result(true, "", "");
    }
    Dictionary load_model(const String &path) {
        std::lock_guard<std::mutex> guard(mutex);
        if (model) { llama_model_free(model); model = nullptr; }
        auto params = llama_model_default_params();
        params.n_gpu_layers = 0;
        params.use_mmap = true;
        params.use_mlock = false;
        params.progress_callback = [](float, void *p) { return !static_cast<std::atomic<bool> *>(p)->load(); };
        params.progress_callback_user_data = &cancelled;
        auto p = path.utf8();
        model = llama_model_load_from_file(p.get_data(), params);
        if (!model) return result(false, "", cancelled.load() ? "Cancelled" : "GGUF load failed or unsupported model");
        if (llama_model_has_encoder(model) || !llama_model_has_decoder(model)) {
            llama_model_free(model); model = nullptr;
            return result(false, "", "Only decoder-only text models are supported");
        }
        return result(true, "", "");
    }
    Dictionary generate(const String &system, const String &prompt, int context, int threads, int max_tokens) {
        std::lock_guard<std::mutex> guard(mutex);
        if (!model) return result(false, "", "No model loaded");
        if (cancelled.load()) return result(false, "", "Cancelled");
        auto sys = system.utf8(), user = prompt.utf8();
        if (sys.length() + user.length() > 32768) return result(false, "", "Prompt too large");
        const char *tmpl = llama_model_chat_template(model, nullptr);
        if (!tmpl) return result(false, "", "Model lacks a supported chat template");
        llama_chat_message messages[] = {{"system", sys.get_data()}, {"user", user.get_data()}};
        std::vector<char> formatted(65536);
        int length = llama_chat_apply_template(tmpl, messages, 2, true, formatted.data(), formatted.size());
        if (length <= 0 || length >= (int)formatted.size()) return result(false, "", "Unsupported or oversized chat template");
        auto vocab = llama_model_get_vocab(model);
        auto cp = llama_context_default_params();
        cp.n_ctx = std::clamp(context, 512, 4096);
        cp.n_batch = cp.n_ctx;
        cp.n_ubatch = std::min(cp.n_ctx, 128u);
        cp.n_threads = cp.n_threads_batch = std::clamp(threads, 1, 4);
        cp.abort_callback = [](void *p) { return static_cast<std::atomic<bool> *>(p)->load(); };
        cp.abort_callback_data = &cancelled;
        std::vector<llama_token> tokens(cp.n_ctx);
        int n = llama_tokenize(vocab, formatted.data(), length, tokens.data(), tokens.size(), true, true);
        int budget = std::clamp(max_tokens, 1, 256);
        if (n <= 0 || n + budget > (int)cp.n_ctx) return result(false, "", "Prompt exceeds context budget");
        std::unique_ptr<llama_context, decltype(&llama_free)> ctx(llama_init_from_model(model, cp), llama_free);
        if (!ctx) return result(false, "", "Context allocation failed");
        std::unique_ptr<llama_sampler, decltype(&llama_sampler_free)> sampler(llama_sampler_init_greedy(), llama_sampler_free);
        if (!sampler) return result(false, "", "Sampler allocation failed");
        if (llama_decode(ctx.get(), llama_batch_get_one(tokens.data(), n)) != 0)
            return result(false, "", cancelled.load() ? "Cancelled" : "Prompt decoding failed");
        std::string output;
        for (int i = 0; i < budget; ++i) {
            if (cancelled.load()) return result(false, "", "Cancelled");
            llama_token token = llama_sampler_sample(sampler.get(), ctx.get(), -1);
            if (llama_vocab_is_eog(vocab, token)) break;
            std::vector<char> piece(256);
            int bytes = llama_token_to_piece(vocab, token, piece.data(), piece.size(), 0, false);
            if (bytes < 0) {
                piece.resize(-bytes);
                bytes = llama_token_to_piece(vocab, token, piece.data(), piece.size(), 0, false);
            }
            if (bytes < 0) return result(false, "", "Token decoding failed");
            output.append(piece.data(), bytes);
            if (i + 1 < budget && llama_decode(ctx.get(), llama_batch_get_one(&token, 1)) != 0)
                return result(false, "", cancelled.load() ? "Cancelled" : "Generation failed");
        }
        return result(true, String::utf8(output.c_str(), output.size()), "");
    }
};

// A narrow storage API: no caller-provided SQL, no extensions, no network.
class CubyteStore : public RefCounted {
    GDCLASS(CubyteStore, RefCounted)
    sqlite3 *db = nullptr;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("open", "path"), &CubyteStore::open);
        ClassDB::bind_method(D_METHOD("read", "key"), &CubyteStore::read);
        ClassDB::bind_method(D_METHOD("write", "key", "value"), &CubyteStore::write);
    }
public:
    ~CubyteStore() override { if (db) sqlite3_close(db); }
    bool open(const String &path) {
        if (db) return false;
        auto p = path.utf8();
        int rc = sqlite3_open_v2(p.get_data(), &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nullptr);
        if (rc == SQLITE_OK) {
            sqlite3_busy_timeout(db, 1500);
            sqlite3_db_config(db, SQLITE_DBCONFIG_DEFENSIVE, 1, nullptr);
            sqlite3_db_config(db, SQLITE_DBCONFIG_TRUSTED_SCHEMA, 0, nullptr);
            rc = sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS snapshots (key TEXT PRIMARY KEY, value TEXT NOT NULL)", nullptr, nullptr, nullptr);
        }
        if (rc != SQLITE_OK) { if (db) sqlite3_close(db); db = nullptr; return false; }
        return true;
    }
    Dictionary read(const String &key) {
        Dictionary out; out["ok"] = false; out["found"] = false;
        if (!db || key.is_empty() || key.length() > 128) return out;
        sqlite3_stmt *raw = nullptr;
        if (sqlite3_prepare_v2(db, "SELECT value FROM snapshots WHERE key=?1", -1, &raw, nullptr) != SQLITE_OK) return out;
        std::unique_ptr<sqlite3_stmt, decltype(&sqlite3_finalize)> stmt(raw, sqlite3_finalize);
        auto k = key.utf8();
        if (sqlite3_bind_text(raw, 1, k.get_data(), k.length(), SQLITE_TRANSIENT) != SQLITE_OK) return out;
        int rc = sqlite3_step(raw);
        if (rc == SQLITE_ROW) {
            int bytes = sqlite3_column_bytes(raw, 0);
            if (bytes > 32 * 1024 * 1024) return out;
            const auto *value = sqlite3_column_text(raw, 0);
            if (!value) return out;
            out["value"] = String::utf8(reinterpret_cast<const char *>(value), bytes);
            out["found"] = true;
        } else if (rc != SQLITE_DONE) return out;
        out["ok"] = true;
        return out;
    }
    bool write(const String &key, const String &value) {
        if (!db || key.is_empty() || key.length() > 128) return false;
        auto k = key.utf8(), v = value.utf8();
        if (v.length() > 32 * 1024 * 1024) return false;
        sqlite3_stmt *raw = nullptr;
        if (sqlite3_prepare_v2(db, "INSERT INTO snapshots(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value", -1, &raw, nullptr) != SQLITE_OK) return false;
        std::unique_ptr<sqlite3_stmt, decltype(&sqlite3_finalize)> stmt(raw, sqlite3_finalize);
        if (sqlite3_bind_text(raw, 1, k.get_data(), k.length(), SQLITE_TRANSIENT) != SQLITE_OK ||
            sqlite3_bind_text(raw, 2, v.get_data(), v.length(), SQLITE_TRANSIENT) != SQLITE_OK) return false;
        return sqlite3_step(raw) == SQLITE_DONE;
    }
};

static void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    llama_backend_init();
    GDREGISTER_CLASS(CubyteLlama);
    GDREGISTER_CLASS(CubyteStore);
}
static void uninitialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) llama_backend_free();
}
extern "C" GDExtensionBool GDE_EXPORT cubyte_llama_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
