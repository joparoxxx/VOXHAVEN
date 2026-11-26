extends RefCounted
## Shared coordinates for navigation, geometry and meeting seats.
const DESKS := [Vector3(-4,0,-4.5),Vector3(-4,0,3.5),Vector3(0,0,3.5),Vector3(4,0,3.5)]
const SPAWNS := [Vector3(-4,0,-3),Vector3(-4,0,1.5),Vector3(0,0,1.5),Vector3(4,0,1.5)]
const MEETING_CENTER := Vector3(3.5,0,-3.5)
const SEATS := [Vector3(3.5,0,-5),Vector3(1.5,0,-3.5),Vector3(5.5,0,-3.5),Vector3(3.5,0,-2)]
const LOUNGE := Vector3(-5.5,0,0)
const LAB := Vector3(5.5,0,0)
const PARTITIONS := [
	{"center":Vector3(-5.75,0,-1.5),"half":Vector2(1.25,0.08)},
	{"center":Vector3(-1.75,0,-1.5),"half":Vector2(0.75,0.08)},
	{"center":Vector3(-1,0,-3.75),"half":Vector2(0.08,2.25)}
]
static func block_fixed(nav: Object) -> void:
	for part in PARTITIONS:
		nav.block_box(part["center"], part["half"] + Vector2(0.4,0.4))
	nav.block_box(MEETING_CENTER, Vector2(1.35,0.95))
	nav.block_box(LOUNGE, Vector2(0.8,0.8))
	nav.block_box(LAB, Vector2(0.8,0.8))

static func work_target(station: int, desk_position: Vector3) -> Vector3:
	return desk_position + Vector3(0,0,1.6 if station == 0 else -1.6)
