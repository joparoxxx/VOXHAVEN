extends RefCounted
## Keys are session-only; fixed provider HTTPS origins; no redirects.
const PROVIDERS := ["openai", "gemini", "groq", "openrouter", "deepseek"]
const BASE := {
	"openai": "https://api.openai.com/v1",
	"gemini": "https://generativelanguage.googleapis.com/v1beta",
	"groq": "https://api.groq.com/openai/v1",
	"openrouter": "https://openrouter.ai/api/v1",
	"deepseek": "https://api.deepseek.com"
}
const MAX_BODY := 4194304

static func _headers(provider: String, key: String) -> PackedStringArray:
	key = key.strip_edges()
	if provider not in PROVIDERS or key.is_empty() or key.length() > 4096:
		return PackedStringArray()
	for ch in key:
		if ch.unicode_at(0) < 33 or ch.unicode_at(0) > 126:
			return PackedStringArray()
	return PackedStringArray(["Content-Type: application/json", ("x-goog-api-key: " if provider == "gemini" else "Authorization: Bearer ") + key])

static func models_request(provider: String, key: String) -> Dictionary:
	var headers := _headers(provider, key)
	if headers.is_empty():
		return {}
	return {"url": str(BASE[provider]) + "/models" + ("?pageSize=100" if provider == "gemini" else ""), "headers": headers}

static func make_request(provider: String, model: String, key: String, system: String, prompt: String) -> Dictionary:
	model = model.strip_edges()
	var headers := _headers(provider, key)
	if headers.is_empty() or model.is_empty() or model.length() > 200:
		return {}
	if system.to_utf8_buffer().size() > 32768 or prompt.to_utf8_buffer().size() > 2048:
		return {}
	var url: String = str(BASE[provider]) + "/chat/completions"
	var body := {"model": model, "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}], "stream": false}
	if provider == "gemini":
		model = model.trim_prefix("models/")
		for ch in model:
			if not ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._":
				return {}
		if model.is_empty() or not model.begins_with("gemini-"):
			return {}
		url = str(BASE[provider]) + "/models/" + model + ":generateContent"
		body = {"systemInstruction": {"parts": [{"text": system}]}, "contents": [{"role": "user", "parts": [{"text": prompt}]}], "generationConfig": {"maxOutputTokens": 1024}}
	elif provider in ["openai", "groq"]:
		body["max_completion_tokens"] = 1024
	else:
		body["max_tokens"] = 1024
	return {"url": url, "headers": headers, "body": JSON.stringify(body)}

static func _error(transport: int, code: int, raw: String) -> String:
	if transport != HTTPRequest.RESULT_SUCCESS:
		return "Network/TLS/timeout error (%d)." % transport
	if code == 200:
		return ""
	var detail := "HTTP %d." % code
	match code:
		400, 404: detail += " Check the model ID and provider compatibility."
		401, 403: detail += " Check API key, access and region."
		402: detail += " Provider requires credits."
		429:
			var parsed: Variant = JSON.parse_string(raw) if raw.length() < MAX_BODY else null
			var reason := ""
			if parsed is Dictionary and parsed.get("error") is Dictionary:
				reason = str(parsed["error"].get("code", ""))
			detail += " API credits exhausted." if reason == "insufficient_quota" else " Provider rate limit or quota reached."
		500, 502, 503, 504: detail += " Provider temporarily unavailable."
	return detail

static func parse_models(provider: String, transport: int, code: int, raw: String) -> Dictionary:
	var err := _error(transport, code, raw)
	if not err.is_empty():
		return {"ok": false, "error": err}
	if raw.to_utf8_buffer().size() > MAX_BODY:
		return {"ok": false, "error": "Model list too large. Enter a model ID manually."}
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return {"ok": false, "error": "Invalid model list."}
	var items: Variant = parsed.get("models" if provider == "gemini" else "data", [])
	var ids: Array[String] = []
	if items is Array:
		for item in items:
			if not item is Dictionary:
				continue
			var id := str(item.get("name" if provider == "gemini" else "id", ""))
			if provider == "gemini":
				if not "generateContent" in item.get("supportedGenerationMethods", []):
					continue
				id = id.trim_prefix("models/")
				if not id.begins_with("gemini-"):
					continue
			if not id.is_empty() and id.length() <= 200 and id not in ids:
				ids.append(id)
			if ids.size() >= 500:
				break
	ids.sort()
	return {"ok": true, "models": ids}

static func parse_response(transport: int, code: int, raw: String, provider: String = "openai") -> Dictionary:
	var err := _error(transport, code, raw)
	if not err.is_empty():
		return {"ok": false, "error": err}
	if raw.to_utf8_buffer().size() > MAX_BODY:
		return {"ok": false, "error": "Response too large."}
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return {"ok": false, "error": "Invalid completion."}
	var response: Variant = null
	if provider == "gemini":
		var candidates: Variant = parsed.get("candidates", [])
		if candidates is Array and not candidates.is_empty() and candidates[0] is Dictionary:
			var candidate: Dictionary = candidates[0]
			if candidate.get("finishReason") in ["SAFETY", "BLOCKLIST", "PROHIBITED_CONTENT", "SPII", "RECITATION"]:
				return {"ok": false, "error": "Provider blocked the response."}
			var content: Variant = candidate.get("content", {})
			var parts: Variant = content.get("parts", []) if content is Dictionary else []
			var reply := ""
			if parts is Array:
				for part in parts:
					if part is Dictionary and part.get("thought", false) != true and part.get("text") is String:
						reply += str(part["text"])
			response = reply
	else:
		var choices: Variant = parsed.get("choices", [])
		if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
			var message: Variant = choices[0].get("message", {})
			if message is Dictionary:
				response = message.get("content")
	if not response is String or response.strip_edges().is_empty():
		return {"ok": false, "error": "No text returned. Try another chat model."}
	if response.to_utf8_buffer().size() > 16384:
		return {"ok": false, "error": "Completion exceeds local limit."}
	return {"ok": true, "text": response}
