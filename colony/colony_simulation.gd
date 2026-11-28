extends RefCounted
const Colonist = preload("res://colony/colonist_state.gd")
const World = preload("res://world/voxel_world.gd")
const Nav = preload("res://colony/navigation.gd")
const Decision = preload("res://colony/decision.gd")
const MiningJobs = preload("res://colony/mining_jobs.gd")
const ResourceLogistics = preload("res://colony/resource_logistics.gd")
var terrain: World
# Four navigable cells per second. Rendering catches up over each 0.25 s tick.
const STEP := 0.25
const MAX_STEPS := 16
const MINING_DURATION := 0.75
const YIELD_TIMEOUT := 0.75
var colonists: Array[Colonist] = []
var mining := MiningJobs.new()
var logistics := ResourceLogistics.new()
var elapsed := 0.0
var accumulator := 0.0

func initialize(spawn: Vector3i) -> void:
	mining.reset()
	logistics.reset(spawn)
	logistics.mining = mining
	colonists.clear()
	elapsed = 0.0
	accumulator = 0.0
	for i in 3:
		colonists.append(Colonist.new(i+1,"Colonist %d" % (i+1),spawn))

func advance(delta: float) -> void:
	mining.terrain = terrain
	logistics.terrain = terrain
	accumulator += maxf(0.0,delta)
	var steps := 0
	while accumulator >= STEP and steps < MAX_STEPS:
		for colonist in colonists:
			colonist.tick(STEP)
			if terrain != null and colonist.health>0.0:
				execute(colonist)
			elif colonist.health <= 0.0:
				mining.release(colonist.id)
				logistics.release(colonist.id, colonist.position)
				colonist.work_progress = 0.0
		accumulator -= STEP
		elapsed += STEP
		steps += 1

func execute(c: Colonist) -> void:
	if not Nav.standable(terrain,c.position):
		mining.release(c.id)
		logistics.release(c.id, c.position)
		c.activity="Blocked"
		c.work_progress = 0.0
		c.path_wait = 0.0
		c.route.clear()
		c.actions.clear()
		return
	if not c.route.is_empty():
		var p: Vector3i = c.route[0]
		if not Nav.standable(terrain,p):
			mining.release(c.id)
			logistics.release(c.id, c.position)
			c.work_progress = 0.0
			c.path_wait = 0.0
			c.route.clear()
			c.actions.clear()
			return
		for other in colonists:
			if other != c and other.health>0.0 and other.position==p:
				# A fellow worker can vacate this cell on the next 0.25 s tick.
				# Do not cancel the job and force replanning on every brief overlap.
				c.path_wait += STEP
				c.activity = "Yielding path"
				if c.path_wait >= YIELD_TIMEOUT:
					mining.release(c.id)
					logistics.release(c.id, c.position)
					c.route.clear()
					c.actions.clear()
					c.path_wait = 0.0
					c.work_progress = 0.0
				return
		c.path_wait = 0.0
		c.work_progress = 0.0
		c.position=c.route.pop_front()
		c.stamina=maxf(0.0,c.stamina-2.0*STEP)
		if logistics.carried.has(c.id):
			c.activity="Carrying resources"
		elif mining.has_assignment(c.id):
			c.activity="Walking to mine"
		else:
			c.activity="Walking"
		c.remember(c.position)
		return
	if logistics.has_job(c.id):
		logistics.progress(c)
		return
	if mining.has_assignment(c.id):
		# Hold a real work phase at the target: no instantaneous one-step mining.
		c.activity = "Mining"
		c.work_progress += STEP
		if c.work_progress < MINING_DURATION:
			return
		c.work_progress = 0.0
		if mining.complete(c):
			return
	elif c.stamina >= 15.0 and logistics.reserve(c):
		c.work_progress = 0.0
		return
	elif c.stamina >= 15.0 and mining.reserve(c):
		c.work_progress = 0.0
		c.activity = "Going to mine"
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
