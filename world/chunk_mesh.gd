extends RefCounted
const World = preload("res://world/voxel_world.gd")
const DIRS = [Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,1,0),Vector3i(0,-1,0),Vector3i(0,0,1),Vector3i(0,0,-1)]
const COLORS = [Color.TRANSPARENT,Color("638b42"),Color("79563b"),Color("85858a"),Color("d6bf83"),Color("e4eef4"),Color("45434b"),Color("b77950"),Color("a9b8c2"),Color("d8ad42")]

static func build(world: World, chunk: Vector2i) -> ArrayMesh:
	return upload(generate(world,chunk))

static func generate(world: World, chunk: Vector2i, atlas: Dictionary = {}) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var data := world.generate_chunk(chunk)
	var origin := Vector3i(chunk.x * 16,0,chunk.y * 16)
	var faces := 0
	for y in World.HEIGHT:
		for z in 16:
			for x in 16:
				var block := int(data[(y*16+z)*16+x])
				if block == World.Block.AIR: continue
				var p := Vector3i(x,y,z)
				for d in DIRS:
					var q: Vector3i = p+d
					var neighbor: int
					if q.x >= 0 and q.x < 16 and q.z >= 0 and q.z < 16 and q.y >= 0 and q.y < World.HEIGHT:
						neighbor = data[(q.y*16+q.z)*16+q.x]
					else:
						neighbor = world.block_at(origin+q)
					if neighbor != World.Block.AIR: continue
					var n := Vector3(d)
					var u := Vector3.UP if d.y == 0 else Vector3.RIGHT
					var v := n.cross(u)
					var center := Vector3(p)+Vector3.ONE*0.5+n*0.5
					var a := center-u*0.5-v*0.5
					var bb := center+u*0.5-v*0.5
					var c := center+u*0.5+v*0.5
					var e := center-u*0.5+v*0.5
					var base := vertices.size()
					var corners: PackedVector2Array = atlas.get(Vector2i(block,DIRS.find(d)),PackedVector2Array())
					var points := [a,bb,c,e]
					for i in 4:
						vertices.append(points[i])
						normals.append(n)
						colors.append(Color.WHITE if corners.size()==4 else COLORS[block])
						uvs.append(corners[i] if corners.size()==4 else Vector2.ZERO)
					for index in [0,2,1,0,3,2]:
						indices.append(base+index)
					faces += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func upload(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not arrays[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
