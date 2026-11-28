extends SceneTree
const Colony = preload("res://colony/colony_simulation.gd")

func _initialize() -> void:
	var colony := Colony.new()
	colony.initialize(Vector3i(8,25,8))
	if colony.colonists.size() != 3:
		quit(1)
		return
	colony.advance(0.125)
	if colony.elapsed != 0.0:
		quit(1)
		return
	colony.advance(0.125)
	if colony.elapsed != Colony.STEP or colony.colonists[0].hunger <= 0.0 or colony.colonists[0].thirst <= 0.0:
		quit(1)
		return
	colony.advance(20.0)
	if colony.elapsed != Colony.STEP * (Colony.MAX_STEPS + 1):
		quit(1)
		return
	colony.colonists[0].tick(10000.0)
	if colony.colonists[0].health != 0.0 or colony.colonists[0].hunger != 100.0:
		quit(1)
		return
	print("Colony simulation passed")
	quit(0)
