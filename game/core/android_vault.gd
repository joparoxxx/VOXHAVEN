extends RefCounted
## Android-only opt-in credential vault. No plaintext fallback.
const PROVIDERS := ["gemini", "openai", "groq", "openrouter", "deepseek"]
const ROOT := "user://cubyte/vault"
var java: Object

func available() -> bool:
	if OS.get_name() != "Android" or not Engine.has_singleton("JavaClassWrapper"):
		return false
	java = Engine.get_singleton("JavaClassWrapper")
	return java != null

func _ok() -> bool:
	return java != null and java.call("get_exception") == null

func _class(name_: String):
	return java.call("wrap", name_)

func _store():
	var cls = _class("java.security.KeyStore")
	if cls == null:
		return null
	var ks = cls.getInstance("AndroidKeyStore")
	if ks == null or not _ok():
		return null
	ks.load(null)
	if not _ok():
		return null
	return ks

func _alias(provider: String) -> String:
	return "cubyte.credentials.v1." + provider

func _secret(provider: String, create: bool):
	var ks = _store()
	if ks == null:
		return null
	var alias := _alias(provider)
	var exists: bool = ks.containsAlias(alias)
	if not _ok():
		return null
	if exists:
		var entry = ks.getEntry(alias, null)
		if entry == null or not _ok():
			return null
		var secret = entry.getSecretKey()
		return secret if _ok() else null
	if not create:
		return null
	var builder_class = _class("android.security.keystore.KeyGenParameterSpec$Builder")
	var generator_class = _class("javax.crypto.KeyGenerator")
	if builder_class == null or generator_class == null:
		return null
	# PURPOSE_ENCRYPT | PURPOSE_DECRYPT; randomized encryption required.
	var builder = builder_class.Builder(alias, 3)
	if builder == null or not _ok():
		return null
	builder.setBlockModes(PackedStringArray(["GCM"]))
	if not _ok():
		return null
	builder.setEncryptionPaddings(PackedStringArray(["NoPadding"]))
	if not _ok():
		return null
	builder.setKeySize(256)
	if not _ok():
		return null
	builder.setRandomizedEncryptionRequired(true)
	if not _ok():
		return null
	var spec = builder.build()
	if spec == null or not _ok():
		return null
	var gen = generator_class.getInstance("AES", "AndroidKeyStore")
	if gen == null or not _ok():
		return null
	gen.init(spec)
	if not _ok():
		return null
	var generated = gen.generateKey()
	return generated if _ok() else null

func _cipher():
	var cls = _class("javax.crypto.Cipher")
	if cls == null:
		return null
	var cipher = cls.getInstance("AES/GCM/NoPadding")
	return cipher if _ok() else null

func _path(provider: String) -> String:
	return ROOT + "/" + provider + ".json"

func save(provider: String, key: String, model: String) -> bool:
	if provider not in PROVIDERS or key.is_empty() or key.length() > 4096 or model.length() > 200 or not available():
		return false
	var secret = _secret(provider, true)
	var cipher = _cipher()
	if secret == null or cipher == null:
		return false
	cipher.init(1, secret)
	if not _ok():
		return false
	cipher.updateAAD(_alias(provider).to_utf8_buffer())
	if not _ok():
		return false
	var data: PackedByteArray = JSON.stringify({"key": key, "model": model}).to_utf8_buffer()
	var encrypted = cipher.doFinal(data)
	data.fill(0)
	if not _ok() or not encrypted is PackedByteArray or encrypted.size() < 16:
		return false
	var iv = cipher.getIV()
	if not _ok() or not iv is PackedByteArray or iv.size() != 12:
		return false
	if DirAccess.make_dir_recursive_absolute(ROOT) != OK:
		return false
	var path := _path(provider)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "iv": Marshalls.raw_to_base64(iv), "data": Marshalls.raw_to_base64(encrypted)}))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_saved(provider: String) -> Dictionary:
	if provider not in PROVIDERS or not available():
		return {}
	var file := FileAccess.open(_path(provider), FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return {}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("iv") is String or not raw.get("data") is String:
		return {}
	var iv := Marshalls.base64_to_raw(raw["iv"])
	var encrypted := Marshalls.base64_to_raw(raw["data"])
	if iv.size() != 12 or encrypted.size() < 16:
		return {}
	var secret = _secret(provider, false)
	var cipher = _cipher()
	var spec_class = _class("javax.crypto.spec.GCMParameterSpec")
	if secret == null or cipher == null or spec_class == null:
		return {}
	var spec = spec_class.GCMParameterSpec(128, iv)
	if spec == null or not _ok():
		return {}
	cipher.init(2, secret, spec)
	if not _ok():
		return {}
	cipher.updateAAD(_alias(provider).to_utf8_buffer())
	if not _ok():
		return {}
	var plain = cipher.doFinal(encrypted)
	if not _ok() or not plain is PackedByteArray:
		return {}
	var value: Variant = JSON.parse_string(plain.get_string_from_utf8())
	plain.fill(0)
	if not value is Dictionary or not value.get("key") is String or not value.get("model") is String or value["key"].is_empty() or value["key"].length() > 4096 or value["model"].length() > 200:
		return {}
	return value

func forget(provider: String) -> bool:
	if provider not in PROVIDERS or not available():
		return false
	var ks = _store()
	if ks == null:
		return false
	ks.deleteEntry(_alias(provider))
	if not _ok():
		return false
	var path := _path(provider)
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(path + suffix) != OK:
			return false
	return true
