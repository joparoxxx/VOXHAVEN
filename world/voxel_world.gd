extends RefCounted
## Deterministic terrain data. Coordinates are global, including negative chunks.
const CHUNK_SIZE := 16
const HEIGHT := 64
enum Block { AIR, GRASS, DIRT, STONE, SAND, SNOW, DARK_STONE, COPPER, SILVER, GOLD }
enum Biome { GRASSLAND, FOREST, DESERT, FROZEN, MOUNTAIN, VOLCANIC }
var world_seed: int
var elevation := FastNoiseLite.new()
var climate := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
var caves := FastNoiseLite.new()
var ore := FastNoiseLite.new()
var edits: Dictionary = {}

func _init(seed_value: int = 1) -> void:
	world_seed = seed_value
	var fields := [elevation, climate, moisture, caves, ore]
	var frequencies := [0.018, 0.006, 0.008, 0.065, 0.12]
	for i in fields.size():
		fields[i].seed = world_seed + i * 7919
		fields[i].frequency = frequencies[i]

func biome_at(x: int, z: int) -> int:
	var t := climate.get_noise_2d(x, z)
	var m := moisture.get_noise_2d(x, z)
	if t < -0.3: return Biome.FROZEN
	if t > 0.35: return Biome.DESERT if m < 0.1 else Biome.VOLCANIC
	if elevation.get_noise_2d(x, z) > 0.4: return Biome.MOUNTAIN
	return Biome.FOREST if m > 0.12 else Biome.GRASSLAND

func surface_at(x: int, z: int) -> int:
	return clampi(24 + roundi(elevation.get_noise_2d(x, z) * 18), 4, HEIGHT - 2)

func block_at(p: Vector3i) -> int:
	if p.y < 0 or p.y >= HEIGHT: return Block.AIR
	if edits.has(p): return edits[p]
	var h := surface_at(p.x, p.z)
	if p.y > h: return Block.AIR
	var biome := biome_at(p.x, p.z)
	if p.y == h:
		match biome:
			Biome.DESERT: return Block.SAND
			Biome.FROZEN: return Block.SNOW
			Biome.MOUNTAIN: return Block.STONE
			Biome.VOLCANIC: return Block.DARK_STONE
			_: return Block.GRASS
	if p.y >= h - 3: return Block.SAND if biome == Biome.DESERT else Block.DIRT
	if p.y > 2 and caves.get_noise_3d(p.x, p.y, p.z) > 0.42: return Block.AIR
	var v := ore.get_noise_3d(p.x, p.y, p.z)
	if p.y < 10 and v > 0.55: return Block.GOLD
	if p.y < 18 and v > 0.45: return Block.SILVER
	if v > 0.35: return Block.COPPER
	return Block.DARK_STONE if p.y < 8 else Block.STONE

func set_block(p: Vector3i, block: int) -> bool:
	if p.y < 0 or p.y >= HEIGHT or block < 0 or block > Block.GOLD: return false
	edits[p] = block
	return true

func chunk_of(p: Vector3i) -> Vector2i:
	return Vector2i(floori(float(p.x) / CHUNK_SIZE), floori(float(p.z) / CHUNK_SIZE))

func generate_chunk(chunk: Vector2i) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(CHUNK_SIZE * CHUNK_SIZE * HEIGHT)
	for y in HEIGHT:
		for z in CHUNK_SIZE:
			for x in CHUNK_SIZE:
				data[(y * CHUNK_SIZE + z) * CHUNK_SIZE + x] = block_at(Vector3i(chunk.x * CHUNK_SIZE + x, y, chunk.y * CHUNK_SIZE + z))
	return data

## Prefer flat grassland or forest with solid ground and headroom.
func find_spawn() -> Vector3i:
	for radius in range(0,65,4):
		for z in range(-radius,radius+1,4):
			for x in range(-radius,radius+1,4):
				if maxi(absi(x),absi(z)) != radius: continue
				var biome := biome_at(x,z)
				if biome != Biome.GRASSLAND and biome != Biome.FOREST: continue
				var y := surface_at(x,z)
				var p := Vector3i(x,y,z)
				if block_at(p) != Block.GRASS or block_at(p+Vector3i.UP) != Block.AIR or block_at(p+Vector3i.UP*2) != Block.AIR: continue
				var flat := true
				for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if absi(surface_at(x+d.x,z+d.y)-y)>1: flat = false
				if flat: return p
	return Vector3i(8,surface_at(8,8),8)
