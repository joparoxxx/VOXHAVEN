extends Node
## Explicit model download, verified install, single background CPU inference.
signal changed(message: String)
signal completed(result: Dictionary)
const Policy = preload("res://core/ai_policy.gd")
const MODEL_NAME := "Qwen2.5 0.5B Instruct Q4_K_M"
const URL := "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/6dd44a1/qwen2.5-0.5b-instruct-q4_k_m.gguf"
const SIZE := 491400032
const SHA := "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db"
const ROOT := "user://cubyte/models"
const PATH := ROOT + "/qwen2.5-0.5b-q4_k_m.gguf"
const TEMP := ROOT + "/download.part"
var http: HTTPRequest
var thread: Thread
var bridge: Object
var busy := false
var downloading := false
var loaded := false
var verifying := false

func _ready() -> void:
	http = HTTPRequest.new()
	http.use_threads = true
	http.max_redirects = 6
	http.body_size_limit = SIZE
	http.timeout = 3600.0
	add_child(http)
	http.request_completed.connect(_download_done)
	if ClassDB.class_exists("CubyteLlama"):
		bridge = ClassDB.instantiate("CubyteLlama")

func available() -> bool:
	return is_instance_valid(bridge)

func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1

func installed() -> bool:
	return Policy.valid_model_path(PATH) and _size(PATH) == SIZE

func progress() -> float:
	return clampf(float(http.get_downloaded_bytes()) / float(SIZE), 0.0, 1.0) if downloading else 0.0

func start_download() -> void:
	if busy:
		return
	if not available():
		changed.emit("Offline runtime unavailable in this build.")
		return
	if installed():
		changed.emit("Model installed. Select offline AI to use it.")
		return
	if DirAccess.make_dir_recursive_absolute(ROOT) != OK:
		changed.emit("Cannot create model folder.")
		return
	var dir := DirAccess.open(ROOT)
	if dir == null or dir.get_space_left() < SIZE + 134217728:
		changed.emit("Free at least 630 MB of storage first.")
		return
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(TEMP)
	http.download_file = TEMP
	busy = true
	downloading = true
	changed.emit("Downloading model…")
	var err := http.request(URL)
	if err != OK:
		downloading = false
		busy = false
		changed.emit("Cannot start download.")

func _download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not downloading:
		return
	downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(TEMP)
		busy = false
		changed.emit("Download failed (HTTP %d). Retry when connected." % code)
		return
	verifying = true
	changed.emit("Verifying downloaded model…")
	thread = Thread.new()
	if thread.start(_verify_install) != OK:
		verifying = false
		busy = false
		changed.emit("Cannot start model verification.")

func _verify_install() -> Dictionary:
	if _size(TEMP) != SIZE or FileAccess.get_sha256(TEMP) != SHA:
		DirAccess.remove_absolute(TEMP)
		return {"ok": false, "error": "Model checksum mismatch."}
	if DirAccess.rename_absolute(TEMP, PATH) != OK:
		return {"ok": false, "error": "Cannot install verified model."}
	return {"ok": true}

func generate(system: String, prompt: String) -> bool:
	if busy or not available() or not installed():
		return false
	busy = true
	bridge.call("reset_cancel")
	thread = Thread.new()
	if thread.start(_generate.bind(system, prompt, loaded)) != OK:
		busy = false
		return false
	return true

func _generate(system: String, prompt: String, already_loaded: bool) -> Dictionary:
	if not already_loaded:
		if FileAccess.get_sha256(PATH) != SHA:
			return {"ok": false, "error": "Model checksum mismatch. Delete and download again."}
		var load_result: Dictionary = bridge.call("load_model", ProjectSettings.globalize_path(PATH))
		if not load_result.get("ok", false):
			return load_result
	var result: Dictionary = bridge.call("generate", system, prompt, 2048, 3, 160)
	result["loaded"] = true
	return result

func cancel() -> void:
	if downloading:
		http.cancel_request()
		downloading = false
		busy = false
		DirAccess.remove_absolute(TEMP)
		changed.emit("Download cancelled.")
	elif busy and not verifying and available():
		bridge.call("cancel")

func remove_model() -> void:
	if busy:
		return
	if available():
		bridge.call("unload_model")
	loaded = false
	if FileAccess.file_exists(PATH) and DirAccess.remove_absolute(PATH) != OK:
		changed.emit("Could not delete model.")
	else:
		changed.emit("Local model removed.")

func _process(_delta: float) -> void:
	if thread == null or thread.is_alive():
		return
	var result: Dictionary = thread.wait_to_finish()
	thread = null
	busy = false
	if verifying:
		verifying = false
		changed.emit("Model installed. Offline AI ready." if result.get("ok", false) else str(result.get("error", "Verification failed.")))
	else:
		loaded = result.get("loaded", false)
		completed.emit(result)

func _exit_tree() -> void:
	cancel()
	if thread != null:
		thread.wait_to_finish()
		thread = null
