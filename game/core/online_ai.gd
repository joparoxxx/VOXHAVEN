extends RefCounted
## Fixed HTTPS origins; no arbitrary URL, redirects or remote tool execution.
const ENDPOINT := "https://api.openai.com/v1/chat/completions"
static func make_request(provider: String, model: String, key: String, system: String, prompt: String) -> Dictionary:
	model = model.strip_edges()
	key = key.strip_edges()
	if provider != "openai" or model.is_empty() or model.length() > 200 or key.is_empty() or key.length() > 4096:
		return {}
	for ch in key:
		if ch.unicode_at(0) < 33 or ch.unicode_at(0) > 126:
			return {}
	if system.to_utf8_buffer().size() > 32768 or prompt.to_utf8_buffer().size() > 2048:
		return {}
	var body := {"model": model, "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}], "stream": false}
	body["max_completion_tokens"] = 1024
	return {"url": ENDPOINT, "headers": PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + key]), "body": JSON.stringify(body)}

static func parse_response(transport: int, code: int, raw: String) -> Dictionary:
	if transport != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Network/TLS/timeout error (" + str(transport) + ")."}
	if code != 200:
		var detail := "HTTP " + str(code) + "."
		match code:
			400, 404: detail += " Check the model ID and provider compatibility."
			401, 403: detail += " Check API key and access."
			402: detail += " Provider requires credits."
			429: detail += " Rate limit or quota reached."
		return {"ok": false, "error": detail}
	if raw.to_utf8_buffer().size() > 262144:
		return {"ok": false, "error": "Response too large."}
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary or not parsed.get("choices") is Array or parsed["choices"].is_empty():
		return {"ok": false, "error": "No chat completion returned."}
	var choice: Variant = parsed["choices"][0]
	if not choice is Dictionary or not choice.get("message") is Dictionary:
		return {"ok": false, "error": "Invalid completion."}
	var response: Variant = choice["message"].get("content")
	if not response is String or response.strip_edges().is_empty():
		return {"ok": false, "error": "No text returned. Try another chat model."}
	if response.to_utf8_buffer().size() > 16384:
		return {"ok": false, "error": "Completion exceeds local limit."}
	return {"ok": true, "text": response}
