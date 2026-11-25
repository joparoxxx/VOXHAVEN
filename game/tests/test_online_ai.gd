extends SceneTree
const Online = preload("res://core/online_ai.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	for provider in ["gemini", "openrouter", "groq", "openai"]:
		var req: Dictionary = Online.make_request(provider, "example-model", "test-key", "system", "hello")
		check(str(req.get("url", "")).begins_with("https://"), "HTTPS " + provider)
		check(not str(req.get("body", "")).contains("test-key"), "key not in body")
		check("Authorization: Bearer test-key" in req.get("headers", []), "bearer header")
	check(Online.make_request("https://evil.test", "m", "key", "s", "p").is_empty(), "unknown provider rejected")
	check(Online.make_request("groq", "m", "key\r\nInjected: yes", "s", "p").is_empty(), "header injection rejected")
	check(Online.make_request("groq", "", "key", "s", "p").is_empty(), "missing model")
	check(Online.make_request("groq", "m", "", "s", "p").is_empty(), "missing key")
	var good: Dictionary = Online.parse_response(0, 200, '{"choices":[{"message":{"content":"hello"}}]}')
	check(good.get("ok") == true and good.get("text") == "hello", "parse chat")
	check(not Online.parse_response(0, 401, '{"error":"secret"}').get("ok", true), "auth error")
	check(not str(Online.parse_response(0, 401, '{"error":"secret"}')).contains("secret"), "no error body echo")
	check(not Online.parse_response(0, 200, '{"choices":[]}').get("ok", true), "empty result")
	check(not Online.parse_response(0, 200, '{"choices":[{"message":{"content":null}}]}').get("ok", true), "null result")
	check(not Online.parse_response(1, 200, "").get("ok", true), "transport error")
	print("CUBYTE online AI tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
