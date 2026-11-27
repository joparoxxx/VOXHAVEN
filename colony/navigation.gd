extends RefCounted
const World = preload("res://world/voxel_world.gd")
const LIMIT := 256
static func standable(world: World,p: Vector3i) -> bool:
	return p.y > 0 and p.y < World.HEIGHT-1 and world.block_at(p-Vector3i.UP)!=World.Block.AIR and world.block_at(p)==World.Block.AIR and world.block_at(p+Vector3i.UP)==World.Block.AIR

static func route(world: World,start: Vector3i,goal: Vector3i) -> Array[Vector3i]:
	var empty: Array[Vector3i] = []
	if not standable(world,start) or not standable(world,goal): return empty
	var open: Array[Vector3i] = [start]
	var costs := {start:0}
	var parent := {}
	for iteration in LIMIT:
		if open.is_empty(): break
		open.sort_custom(func(a: Vector3i,b: Vector3i) -> bool: return int(costs[a])+heuristic(a,goal)<int(costs[b])+heuristic(b,goal))
		var p: Vector3i = open.pop_front()
		if p == goal:
			var result: Array[Vector3i] = []
			while p != start:
				result.push_front(p)
				p = parent[p]
			return result
		for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			for dy in [0,1,-1]:
				var q: Vector3i = p+d+Vector3i.UP*dy
				if not standable(world,q): continue
				if dy == 1 and world.block_at(p+Vector3i.UP*2)!=World.Block.AIR: continue
				var cost: int = int(costs[p])+1
				if cost < int(costs.get(q,1000000)):
					costs[q]=cost
					parent[q]=p
					if not open.has(q): open.append(q)
	return empty

static func heuristic(a: Vector3i,b: Vector3i) -> int:
	return absi(a.x-b.x)+absi(a.z-b.z)
