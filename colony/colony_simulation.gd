extends RefCounted
const Colonist = preload("res://colony/colonist_state.gd")
const World = preload("res://world/voxel_world.gd")
const Nav = preload("res://colony/navigation.gd")
const Decision = preload("res://colony/decision.gd")
const MiningJobs = preload("res://colony/mining_jobs.gd")
const ResourceLogistics = preload("res://colony/resource_logistics.gd")
const WoodcutJobs = preload("res://colony/woodcut_jobs.gd")
const DigPlanner = preload("res://colony/dig_planner.gd")
var terrain: World
# Four navigable cells per second. Rendering catches up over each 0.25 s tick.
const STEP := 0.25
const MAX_STEPS := 16
const MINING_DURATION := 0.75
const WOODCUT_DURATION := 1.5
const YIELD_TIMEOUT := 0.75
var colonists: Array[Colonist] = []
var mining := MiningJobs.new()
var logistics := ResourceLogistics.new()
var woodcut := WoodcutJobs.new()
var dig := DigPlanner.new()
var elapsed := 0.0
var accumulator := 0.0
# Excavation planner needs changes, not four full area scans each second.
var planner_refresh_elapsed := 0.0

func initialize(spawn: Vector3i) -> void:
	mining.reset()
	if not mining.mined.is_connected(_on_mining_completed):
		mining.mined.connect(_on_mining_completed)
	logistics.reset(spawn)
	logistics.mining = mining
	woodcut.reset()
	woodcut.logistics = logistics
	mining.harvested_trees = woodcut.harvested
	dig.reset()
	dig.mining = mining
	colonists.clear()
	elapsed = 0.0
	accumulator = 0.0
	planner_refresh_elapsed = 0.0
	for i in 3:
		colonists.append(Colonist.new(i+1,"Colonist %d" % (i+1),spawn))

func advance(delta: float) -> void:
	mining.terrain = terrain
	logistics.terrain = terrain
	woodcut.terrain = terrain
	mining.harvested_trees = woodcut.harvested
	dig.terrain = terrain
	accumulator += maxf(0.0,delta)
	var steps := 0
	while accumulator >= STEP and steps < MAX_STEPS:
		# Existing jobs continue every 0.25 s; only poll for stale external
		# excavation edits once a second. New mined blocks schedule immediately.
		if not dig.columns.is_empty():
			planner_refresh_elapsed += STEP
			if planner_refresh_elapsed >= 1.0:
				planner_refresh_elapsed = 0.0
				dig.schedule()
		else:
			planner_refresh_elapsed = 0.0
		for colonist in colonists:
			colonist.tick(STEP)
			if terrain != null and colonist.health>0.0:
				if not _settle_unsupported(colonist):
					execute(colonist)
			elif colonist.health <= 0.0:
				mining.release(colonist.id)
				woodcut.release(colonist.id)
				logistics.release(colonist.id, colonist.position)
				colonist.work_progress = 0.0
		# A worker can remove another worker's floor during this very tick.
		# Resolve support a second time so no one remains hovering.
		for colonist in colonists:
			if terrain != null and colonist.health > 0.0:
				_settle_unsupported(colonist)
		accumulator -= STEP
		elapsed += STEP
		steps += 1

func execute(c: Colonist) -> void:
	if not Nav.standable(terrain,c.position):
		mining.release(c.id)
		woodcut.release(c.id)
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
			woodcut.release(c.id)
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
					woodcut.release(c.id)
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
		elif woodcut.has_assignment(c.id):
			c.activity="Walking to chop"
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
	if woodcut.has_assignment(c.id):
		c.activity = "Chopping"
		c.work_progress += STEP
		if c.work_progress < WOODCUT_DURATION:
			return
		c.work_progress = 0.0
		if woodcut.complete(c):
			return
	if c.stamina >= 15.0 and active_job_count(c.id) == 0:
		match c.job_role:
			"Miner":
				if mining.reserve(c):
					c.activity = "Going to mine"
					return
			"Woodcutter":
				if woodcut.reserve(c):
					c.activity = "Going to chop"
					return
			"Hauler":
				if logistics.reserve(c):
					return
			_:
				# Preserve existing standalone simulation tests and old generalist AI.
				if logistics.reserve(c) or _reserve_work(c):
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

# Divide mining/woodcut priority between colonists so neither job type starves.
func _reserve_work(c: Colonist) -> bool:
	var assigned := false
	if c.id % 2 == 0:
		assigned = woodcut.reserve(c) or mining.reserve(c)
	else:
		assigned = mining.reserve(c) or woodcut.reserve(c)
	if assigned:
		c.activity = "Going to chop" if woodcut.has_assignment(c.id) else "Going to mine"
	return assigned

## Centralized job ownership. Work reservations may never overlap.
func active_job_count(worker_id: int) -> int:
	return int(mining.has_assignment(worker_id)) + int(woodcut.has_assignment(worker_id)) + int(logistics.has_job(worker_id))

func set_role(worker_id: int, new_role: String) -> bool:
	if not new_role in ["Miner","Woodcutter","Hauler","Generalist"]:
		return false
	for c in colonists:
		if c.id != worker_id:
			continue
		if c.job_role == new_role:
			return true
		# Release the current reservation before taking a different occupation.
		# Logistics.release puts any carried item back on the ground.
		mining.release(c.id)
		woodcut.release(c.id)
		logistics.release(c.id,c.position)
		c.route.clear()
		c.actions.clear()
		c.work_progress = 0.0
		c.path_wait = 0.0
		c.job_role = new_role
		c.activity = "Idle"
		return true
	return false

func worker_roles() -> Array[String]:
	var result: Array[String] = []
	for c in colonists:
		result.append(c.job_role)
	return result

## Grid gravity for removed ground. Does not route through solid voxels.
## Worker drops to the first standable cell directly below; current job and
## path are reset so routefinding starts from the new position next tick.
func _settle_unsupported(c: Colonist) -> bool:
	if terrain == null or Nav.standable(terrain,c.position):
		return false
	if terrain.block_at(c.position) != World.Block.AIR or terrain.block_at(c.position+Vector3i.UP) != World.Block.AIR:
		return false
	var landing := c.position
	for y in range(c.position.y-1,0,-1):
		var below := Vector3i(c.position.x,y,c.position.z)
		if terrain.block_at(below) != World.Block.AIR:
			break
		landing = below
		if Nav.standable(terrain,below):
			break
	if landing == c.position or not Nav.standable(terrain,landing):
		return false
	mining.release(c.id)
	woodcut.release(c.id)
	# Drop any carried resources at the landing position, not in mid-air.
	logistics.release(c.id,landing)
	c.route.clear()
	c.actions.clear()
	c.work_progress = 0.0
	c.path_wait = 0.0
	c.position = landing
	c.activity = "Falling"
	c.remember(landing)
	return true

## Immediately unlock the next excavation layer on a completed mine. Unlike
## constant per-tick scans, this work only runs when actual terrain changes.
func _on_mining_completed(_position: Vector3i, _block: int) -> void:
	if not dig.columns.is_empty():
		planner_refresh_elapsed = 0.0
		dig.schedule()
