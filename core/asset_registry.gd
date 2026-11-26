extends Node
const CATALOG = "res://assets/ASSET_CATALOG.txt"
var paths: Dictionary = {}

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	paths.clear()
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	if file == null:
		push_error("Asset catalog unavailable")
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("assets/library/") and line.get_extension().to_lower() in ["glb", "gltf"]:
			paths[line] = "res://" + line

func instantiate_asset(id: String) -> Node3D:
	if not paths.has(id):
		return null
	var resource := load(paths[id]) as PackedScene
	if resource == null:
		return null
	var node := resource.instantiate()
	if node is Node3D:
		return node
	node.free()
	return null
