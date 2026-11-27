extends RefCounted
## Deterministic simulation state, independent of rendering.
var id: int
var display_name: String
var hunger := 0.0
var thirst := 0.0
var stamina := 100.0
var health := 100.0
var happiness := 70.0
var position := Vector3i.ZERO

func _init(identifier: int, label: String, spawn: Vector3i) -> void:
	id = identifier
	display_name = label
	position = spawn

func tick(seconds: float) -> void:
	if health <= 0.0 or seconds <= 0.0: return
	hunger = minf(100.0,hunger+seconds*0.12)
	thirst = minf(100.0,thirst+seconds*0.18)
	if hunger >= 100.0 or thirst >= 100.0:
		health = maxf(0.0,health-seconds*0.25)
	happiness = clampf(happiness-seconds*0.02 if hunger > 75.0 or thirst > 75.0 else happiness,0.0,100.0)
