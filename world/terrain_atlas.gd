extends RefCounted
const ROOT := "res://assets/library/KayKit_BlockBits_1.0_FREE/Assets/gltf/"
const MODELS := ["","dirt_with_grass","dirt","stone","sand_A","snow","stone_dark","stone_with_copper","stone_with_silver","stone_with_gold"]
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
				for direction in DIRS:
					var u := Vector3.UP if direction.y==0 else Vector3.RIGHT
					var v: Vector3 = direction.cross(u)
					var corners := PackedVector2Array()
					for target in [ -u-v,u-v,u+v,-u+v ]:
						var best := -INF
						var chosen := Vector2.ZERO
						for i in verts.size():
							if normals[i].dot(direction)<0.9: continue
							var score: float = verts[i].dot(target)
							if score>best:
								best=score
								chosen=uv[i]
						if best != -INF: corners.append(chosen)
					if corners.size()==4: lookup[Vector2i(block,DIRS.find(direction))]=corners
		root.free()
	return lookup
