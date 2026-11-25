extends SceneTree
const Online = preload("res://core/online_ai.gd")
const Identity = preload("res://core/cubot_identity.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	var req: Dictionary = Online.make_request("openai", "example-model", "test-key", "system", "hello")
	check(req.get("url") == "https://api.openai.com/v1/chat/completions", "OpenAI only HTTPS")
	check(not str(req.get("body", "")).contains("test-key"), "key not in body")
	check("Authorization: Bearer test-key" in req.get("headers", []), "bearer header")
	for provider in ["gemini", "openrouter", "groq", "https://evil.test"]:
		check(Online.make_request(provider, "m", "key", "s", "p").is_empty(), "reject other provider")
	check(Online.make_request("openai", "m", "key\r\nInjected: yes", "s", "p").is_empty(), "header injection rejected")
	check(Online.make_request("openai", "", "key", "s", "p").is_empty(), "missing model")
	check(Online.make_request("openai", "m", "", "s", "p").is_empty(), "missing key")
	var good: Dictionary = Online.parse_response(0, 200, '{"choices":[{"message":{"content":"hello"}}]}')
	check(good.get("ok") == true and good.get("text") == "hello", "parse chat")
	check(not Online.parse_response(0, 401, '{"error":"secret"}').get("ok", true), "auth error")
	check(not str(Online.parse_response(0, 401, '{"error":"secret"}')).contains("secret"), "no error body echo")
	check(not Online.parse_response(0, 200, '{"choices":[]}').get("ok", true), "empty result")
	check(not Online.parse_response(0, 200, '{"choices":[{"message":{"content":null}}]}').get("ok", true), "null result")
	check(not Online.parse_response(1, 200, "").get("ok", true), "transport error")
	var atlas := Identity.system_prompt("atlas", ["text"], {})
	var pixel := Identity.system_prompt("pixel", ["png"], {})
	check(atlas.contains("Your name is ATLAS") and atlas.contains("Manager"), "atlas identity")
	check(pixel.contains("Your name is PIXEL") and pixel.contains("Designer"), "pixel identity")
	check(atlas.contains("CUBYTE is the platform, not your name"), "platform distinction")
	check(Identity.system_prompt("unknown", [], {}).is_empty(), "unknown identity rejected")
	check(not Identity.system_prompt("mesh", [], {}).contains("private-note"), "no private context by default")
	check(Identity.system_prompt("mesh", [], {"memory":"private-note"}).contains("private-note"), "explicit shared context")
	print("CUBYTE online AI tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
