extends RefCounted
## Versioned snapshots with a validated legacy import path.
var _root: String
var _file: String
var _db: Object
var ready := false
var native := false

func _init(root: String, filename: String) -> void:
	_root = root
	_file = root + "/" + filename
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return
	var db_path := root + "/state.sqlite3"
	if ClassDB.class_exists("CubyteStore"):
		_db = ClassDB.instantiate("CubyteStore")
		if _db == null or not _db.call("open", ProjectSettings.globalize_path(db_path)):
			return
		native = true
	elif FileAccess.file_exists(db_path):
		return
	ready = true

func read(key: String, legacy_path: String = "", max_bytes: int = 16777216) -> Dictionary:
	if not ready:
		return {"ok": false}
	if native:
		var result: Dictionary = _db.call("read", key)
		if not result.get("ok", false):
			return {"ok": false}
		if result.get("found", false):
			var value := str(result.get("value", ""))
			return {"ok": value.to_utf8_buffer().size() <= max_bytes, "found": true, "value": value}
	var path := _file if legacy_path.is_empty() else legacy_path
	if not FileAccess.file_exists(path):
		return {"ok": true, "found": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > max_bytes:
		return {"ok": false}
	var value := file.get_as_text()
	var ok := file.get_error() == OK or file.get_error() == ERR_FILE_EOF
	file.close()
	return {"ok": ok, "found": true, "value": value, "legacy": true}

func write(key: String, value: String, legacy_path: String = "") -> bool:
	if not ready:
		return false
	if native:
		return _db.call("write", key, value) == true
	var path := _file if legacy_path.is_empty() else legacy_path
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".tmp", path) == OK
