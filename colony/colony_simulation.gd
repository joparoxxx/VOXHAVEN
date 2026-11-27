extends RefCounted
const Colonist = preload("res://colony/colonist_state.gd")
const STEP := 1.0
const MAX_STEPS := 4
var colonists: Array[Colonist] = []
var elapsed := 0.0
var accumulator := 0.0

func initialize(spawn: Vector3i) -> void:
	colonists.clear()
	elapsed = 0.0
	accumulator = 0.0
	for i in 3:
		colonists.append(Colonist.new(i+1,"Colonist %d" % (i+1),spawn))

func advance(delta: float) -> void:
	accumulator += maxf(0.0,delta)
	var steps := 0
	while accumulator >= STEP and steps < MAX_STEPS:
		for colonist in colonists:
			colonist.tick(STEP)
		accumulator -= STEP
		elapsed += STEP
		steps += 1
