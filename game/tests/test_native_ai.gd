extends SceneTree
func _initialize() -> void:
	if not ClassDB.class_exists("CubyteLlama"):
		printerr("Native runtime not registered")
		quit(1)
		return
	var bridge: Object = ClassDB.instantiate("CubyteLlama")
	if bridge == null:
		quit(1)
		return
	var empty: Dictionary = bridge.call("generate", "Test", "Hello", 512, 1, 8)
	var missing: Dictionary = bridge.call("load_model", "/nonexistent/cubyte-test.gguf")
	if empty.get("ok", true) or missing.get("ok", true):
		printerr("Expected explicit errors without a model")
		quit(1)
		return
	var unloaded: Dictionary = bridge.call("unload_model")
	if not unloaded.get("ok", false):
		quit(1)
		return
	print("CUBYTE native AI bridge smoke: passed (no model)")
	quit(0)
