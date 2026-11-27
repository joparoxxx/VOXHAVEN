extends SceneTree

func _initialize() -> void:
	var registry = load("res://core/asset_registry.gd").new()
	registry.rebuild()
	var ok: bool = registry.paths.size() == 1183
	for path in registry.paths.values():
		if not ResourceLoader.exists(path):
			printerr("Missing imported resource: ", path)
			ok = false
	registry.free()
	quit(0 if ok else 1)
