extends SceneTree
## Regression for old version-1 saved worlds, cached immutable chunk snapshots
## and non-destructive archive before creating a fresh world.
const World = preload("res://world/voxel_world.gd")
const Save = preload("res://world/world_save.gd")
const View = preload("res://world/world_view.gd")

func _initialize() -> void:
	var save_path := "user://voxhaven-legacy-cache-test.json"
	var seed_value := 894
	var previous := World.new(seed_value)
	var edits: Array = []
	for x in range(40):
		var p := Vector3i(x,32,3)
		previous.set_block(p,World.Block.STONE)
		edits.append([p.x,p.y,p.z,World.Block.STONE])
	# A legacy v1 file has no optional dig/roles fields.
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write legacy save fixture")
		quit(1)
		return
	file.store_string(JSON.stringify({"version":1,"seed":seed_value,"edits":edits}))
	file.close()
	var restored := Save.restore(save_path)
	if restored == null:
		push_error("Legacy version-1 save no longer loads")
		quit(1)
		return
	var ok: bool = restored.world_seed == seed_value and restored.edits.size() == edits.size()
	ok = ok and restored.generate_chunk(Vector2i.ZERO) == previous.generate_chunk(Vector2i.ZERO)
	var view := View.new()
	view.world = restored
	var snapshot1 := view._mesh_world_snapshot()
	var snapshot2 := view._mesh_world_snapshot()
	ok = ok and snapshot1 == snapshot2
	ok = ok and snapshot1.edits.size() == restored.edits.size()
	var target := Vector3i(0,32,3)
	var previous_block: int = snapshot1.block_at(target)
	restored.set_block(target,World.Block.AIR)
	var snapshot3 := view._mesh_world_snapshot()
	ok = ok and snapshot3 != snapshot2
	ok = ok and snapshot1.block_at(target) == previous_block
	ok = ok and snapshot3.block_at(target) == World.Block.AIR
	ok = ok and view._mesh_world_snapshot() == snapshot3
	# Replacing the loaded World object also invalidates snapshot even if seed
	# and revision match; otherwise a new world could reuse old meshes.
	view.world = World.new(seed_value)
	var fresh := view._mesh_world_snapshot()
	ok = ok and fresh != snapshot3 and fresh.edits.is_empty()
	view.free()
	# Archiving must leave a full recoverable original, not silently delete it.
	var archive_path := Save.archive(save_path)
	ok = ok and not archive_path.is_empty()
	ok = ok and not FileAccess.file_exists(save_path)
	ok = ok and FileAccess.file_exists(archive_path)
	var from_backup := Save.restore(archive_path)
	ok = ok and from_backup != null and from_backup.edits.size() == edits.size()
	if not archive_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archive_path))
	if not ok:
		print("Saved world diagnostic: path=",archive_path," original_count=",edits.size()," snapshot_count=",snapshot1.edits.size())
	print("Legacy save, immutable mesh cache and backup recovery: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
