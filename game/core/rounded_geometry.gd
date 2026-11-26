extends RefCounted
## Rounded cuboid with analytic normals, exact outer dimensions and bounded tessellation.
static func rounded_box(size_: Vector3, radius: float) -> ArrayMesh:
	var half := size_ * 0.5
	var r := clampf(radius, 0.0001, minf(half.x, minf(half.y, half.z)) * 0.98)
	var core := half - Vector3.ONE * r
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for axis in range(3):
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_ in [-1, 1]:
			var start := vertices.size()
			var us := _coordinates(half[u], r)
			var vs := _coordinates(half[v], r)
			for y in vs:
				for x in us:
					var p := Vector3.ZERO
					p[axis] = half[axis] * sign_
					p[u] = x
					p[v] = y
					var inner := p.clamp(-core, core)
					var n := (p - inner).normalized()
					vertices.append(inner + n * r)
					normals.append(n)
			var width := us.size()
			for row in range(vs.size() - 1):
				for col in range(width - 1):
					var a := start + row * width + col
					var b := a + 1
					var c := a + width
					var d := c + 1
					if sign_ == 1:
						indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
					else:
						indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _coordinates(half: float, radius: float) -> Array[float]:
	return [-half, -half + radius / 3.0, -half + radius * 2.0 / 3.0, -half + radius, half - radius, half - radius * 2.0 / 3.0, half - radius / 3.0, half]
