extends SceneTree
const Policy = preload("res://core/ai_policy.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	check(Policy.proposal('{"tool":"text","payload":"hello"}').get("tool") == "text", "valid proposal")
	check(Policy.proposal('{"tool":"shell","payload":"ls"}').is_empty(), "reject unknown tool")
	check(Policy.proposal('{"tool":"text","payload":123}').is_empty(), "reject invalid payload")
	check(Policy.proposal('{"tool":"png","payload":"","extra":true}').is_empty(), "reject extra fields")
	check(Policy.proposal('{"tool":"png","payload":"unexpected"}').is_empty(), "reject png payload")
	check(Policy.proposal("not JSON").is_empty(), "reject malformed response")
	check(Policy.proposal(JSON.stringify({"tool":"text","payload":"a".repeat(4097)})).is_empty(), "bound output")
	check(not Policy.valid_model_path("user://missing.gguf"), "missing model")
	var path := "user://ai_test_" + str(Time.get_ticks_usec()) + ".gguf"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("GGUF".to_utf8_buffer())
	file.store_32(3)
	file.store_64(1)
	file.store_64(1)
	file.store_8(0)
	file.close()
	check(Policy.valid_model_path(path), "valid header only")
	DirAccess.remove_absolute(path)
	print("CUBYTE AI policy tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
