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
var curiosity := 1.0
var memory: Array[Vector3i] = []
var route: Array[Vector3i] = []
var actions: Array[String] = []
var activity := "Idle"
var next_decision := 0.0

func remember(p: Vector3i) -> void:
	memory.erase(p)
	memory.append(p)
	if memory.size()>16: memory.pop_front()


func _init(identifier: int, label: String, spawn: Vector3i) -> void:
	id = identifier
	display_name = label
	position = spawn
	curiosity = 0.8+float(identifier%3)*0.2
	next_decision = float(identifier%3)

func tick(seconds: float) -> void:
	if health <= 0.0 or seconds <= 0.0: return
	hunger = minf(100.0,hunger+seconds*0.12)
	thirst = minf(100.0,thirst+seconds*0.18)
	if hunger >= 100.0 or thirst >= 100.0:
		health = maxf(0.0,health-seconds*0.25)
	happiness = clampf(happiness-seconds*0.02 if hunger > 75.0 or thirst > 75.0 else happiness,0.0,100.0)
