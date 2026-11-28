extends RefCounted
# Use the SAME Cube World low-poly palette as its characters and trees.
# Pixel Blocks/Blocks_PixelArt.png is a separate pixel-art style and is not used in gameplay.
const ROOT := "res://assets/library/Quaternius_Cube_World/Blocks/"
const TEXTURE_PATH := "res://assets/library/Quaternius_Cube_World/Atlas.png"
# Until unique low-poly sand/ore blocks are approved, tint existing palette materials.
# Block indices align with World.Block (AIR, GRASS, DIRT, STONE, SAND, SNOW, DARK_STONE, COPPER, SILVER, GOLD).
const MODELS := ["","Block_Grass","Block_Dirt","Block_Stone","Block_Dirt","Block_Snow","Block_Stone","Block_Stone","Block_Stone","Block_Stone"]
const DIRS = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]

static func build_lookup() -> Dictionary:
	var lookup := {}
	for block in range(1,MODELS.size()):
		var scene := load(ROOT+MODELS[block]+".gltf") as PackedScene
		if scene == null: continue
		var root := scene.instantiate()
		var meshes := root.find_children("*","MeshInstance3D",true,false)
		if root is MeshInstance3D: meshes.push_front(root)
		for instance in meshes:
			var mesh: Mesh = instance.mesh
			if mesh == null: continue
			for surface in mesh.get_surface_count():
				var a := mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
				if uv.size()!=verts.size() or normals.size()!=verts.size(): continue
				var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				# The low-poly Atlas is a tiny color palette, not a tiling image.
				# Sample one actual source triangle per face; taking four extreme UVs
				# across separate palette swatches would smear colors into gradients.
				for direction in DIRS:
					var sample := dominant_face_uv(verts,normals,uv,indices,direction)
					if sample.x >= 0.0:
						lookup[Vector2i(block,DIRS.find(direction))] = PackedVector2Array([sample,sample,sample,sample])
		root.free()
	return lookup

static func dominant_face_uv(verts: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array, direction: Vector3) -> Vector2:
	var best_area := 0.0
	var sample := Vector2(-1,-1)
	var count := indices.size() if not indices.is_empty() else verts.size()
	for i in range(0,count-2,3):
		var a := indices[i] if not indices.is_empty() else i
		var b := indices[i+1] if not indices.is_empty() else i+1
		var c := indices[i+2] if not indices.is_empty() else i+2
		if minf(normals[a].dot(direction),minf(normals[b].dot(direction),normals[c].dot(direction))) < 0.9: continue
		var area := (verts[b]-verts[a]).cross(verts[c]-verts[a]).length()
		if area > best_area:
			best_area = area
			sample = (uv[a]+uv[b]+uv[c])/3.0
	return sample
