extends RefCounted
const Tools = preload("res://core/tool_registry.gd")
static func valid_model_path(path: String) -> bool:
	if not path.to_lower().ends_with(".gguf"):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 25:
		return false
	return f.get_buffer(4).get_string_from_ascii() == "GGUF" and f.get_32() in [2, 3]

static func proposal(response: String) -> Dictionary:
	if response.to_utf8_buffer().size() > 16384:
		return {}
	var candidate := response.strip_edges()
	# Accept a single fenced JSON proposal even when the model adds prose.
	# Never scan arbitrary braces, multiple code blocks or execute automatically.
	var fence := candidate.find("```")
	if fence >= 0:
		var end := candidate.find("```", fence + 3)
		if end < 0 or candidate.find("```", end + 3) >= 0:
			return {}
		var block := candidate.substr(fence + 3, end - fence - 3)
		var newline := block.find("\n")
		if newline < 0 or block.left(newline).strip_edges().to_lower() not in ["", "json"]:
			return {}
		candidate = block.substr(newline + 1).strip_edges()
	var parsed: Variant = JSON.parse_string(candidate)
	if not parsed is Dictionary or parsed.size() != 2 or not parsed.get("tool") is String or not parsed.get("payload") is String:
		return {}
	if parsed["tool"] not in Tools.IDS or parsed["payload"].to_utf8_buffer().size() > 4096:
		return {}
	if parsed["tool"] == "png" and parsed["payload"] != "":
		return {}
	return parsed
