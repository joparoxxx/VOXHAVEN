extends RefCounted
## Shared HQ coordinates, furniture clearances and navigation destinations.
const WIDTH := 30.0
const DEPTH := 22.0
const DESK_CLEARANCE := Vector2(1.85,0.95)
const DESKS := [Vector3(-7,0,-7.5),Vector3(-6,0,7),Vector3(0,0,7),Vector3(6,0,7)]
const SPAWNS := [Vector3(-7,0,-5.5),Vector3(-6,0,4.5),Vector3(0,0,4.5),Vector3(6,0,4.5)]
const MEETING_CENTER := Vector3(5,0,-6)
const SEATS := [Vector3(5,0,-8),Vector3(2.5,0,-6),Vector3(7.5,0,-6),Vector3(5,0,-4)]
const DOCKS := [Vector3(-11,0,-6),Vector3(12,0,-3),Vector3(12,0,0),Vector3(12,0,3)]
const LOUNGE := Vector3(-11,0,4)
const PLANTER := Vector3(0,0,-1.5)
const LAB := Vector3(-11,0,-0.5)
const PARTITIONS := [
	{"center":Vector3(-11.25,0,-3.5),"half":Vector2(2.75,0.08)},
	{"center":Vector3(-4.25,0,-3.5),"half":Vector2(0.75,0.08)},
	{"center":Vector3(-3.5,0,-7.25),"half":Vector2(0.08,3.25)}
]
static func block_fixed(nav: Object) -> void:
	for part in PARTITIONS:
		nav.block_box(part["center"], part["half"] + Vector2(0.4,0.4))
	nav.block_box(MEETING_CENTER, Vector2(2.25,1.4))
	nav.block_box(LOUNGE, Vector2(2,1.6))
	nav.block_box(PLANTER, Vector2(0.9,0.9))
	nav.block_box(LAB, Vector2(1.1,0.9))

static func work_target(station: int, desk_position: Vector3) -> Vector3:
	return desk_position + Vector3(0,0,1.5 if station == 0 else -1.5)
