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
	var ok: bool = World.CHUNK_SIZE == 16 and mesh.get_surface_count() == 1
	if ok:
		var arrays := mesh.surface_get_arrays(0)
		ok = arrays[Mesh.ARRAY_VERTEX].size() > 0 and arrays[Mesh.ARRAY_INDEX].size() % 6 == 0
		# Chunk mesh uses only local x/z within its 16x16 world footprint.
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			ok = ok and vertex.x >= 0.0 and vertex.x <= float(World.CHUNK_SIZE)
			ok = ok and vertex.z >= 0.0 and vertex.z <= float(World.CHUNK_SIZE)
	print("Chunk mesh test: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
