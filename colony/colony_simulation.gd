extends RefCounted
const Colonist = preload("res://colony/colonist_state.gd")
const World = preload("res://world/voxel_world.gd")
const Nav = preload("res://colony/navigation.gd")
const Decision = preload("res://colony/decision.gd")
var terrain: World
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
			if terrain != null and colonist.health>0.0: execute(colonist)
		accumulator -= STEP
		elapsed += STEP
		steps += 1

func execute(c: Colonist) -> void:
	if not Nav.standable(terrain,c.position):
		c.activity="Blocked"
		c.route.clear()
		c.actions.clear()
		return
	if not c.route.is_empty():
		var p: Vector3i = c.route[0]
		if not Nav.standable(terrain,p):
			c.route.clear()
			c.actions.clear()
			return
		for other in colonists:
			if other != c and other.health>0.0 and other.position==p:
				c.route.clear()
				c.actions.clear()
				return
		c.position=c.route.pop_front()
		c.stamina=maxf(0.0,c.stamina-2.0)
		c.activity="Walking"
		c.remember(c.position)
		return
	if c.actions.is_empty():
		if elapsed<c.next_decision: return
		c.next_decision=elapsed+3.0
		c.actions=Decision.plan(Decision.goal(c))
	if c.actions.is_empty(): return
	match c.actions.pop_front():
		"rest":
			c.activity="Resting"
			c.stamina=minf(100.0,c.stamina+12.0)
		"observe":
			c.activity="Observing"
			c.remember(c.position)
		"wander":
			c.activity="Exploring"
			for attempt in 8:
				var angle := float(c.id*7+int(elapsed)*3+attempt)*2.399963
				var x := c.position.x+roundi(cos(angle)*4.0)
				var z := c.position.z+roundi(sin(angle)*4.0)
				for y in range(World.HEIGHT-2,0,-1):
					var target := Vector3i(x,y,z)
					if not Nav.standable(terrain,target): continue
					if not c.memory.has(target):
						c.route=Nav.route(terrain,c.position,target)
					break
				if not c.route.is_empty(): break
