extends SceneTree
const World = preload("res://world/voxel_world.gd")
const Mesher = preload("res://world/chunk_mesh.gd")
func _initialize() -> void:
	var world := World.new(123)
	var thread := Thread.new()
	if thread.start(Mesher.generate.bind(world,Vector2i.ZERO)) != OK:
		quit(1)
		return
	var generated: Array = thread.wait_to_finish()
	var mesh := Mesher.upload(generated)
	var ok := mesh.get_surface_count() == 1
	if ok:
		var arrays := mesh.surface_get_arrays(0)
		ok = arrays[Mesh.ARRAY_VERTEX].size() > 0 and arrays[Mesh.ARRAY_INDEX].size() % 6 == 0
	print("Chunk mesh test: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
