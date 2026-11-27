extends RefCounted
const State = preload("res://colony/colonist_state.gd")
# Utility selects a goal; bounded symbolic search chooses applicable actions.
const ACTIONS := [
	{"name":"rest","requires":[],"adds":["rested"]},
	{"name":"observe","requires":[],"adds":["observed"]},
	{"name":"wander","requires":["observed"],"adds":["explored"]}
]
static func goal(c: State) -> String:
	var rest := (100.0-c.stamina)*1.4
	var explore := 25.0*c.curiosity
	if c.hunger>75.0 or c.thirst>75.0: return "rested"
	return "rested" if rest>=explore else "explored"

static func plan(target: String) -> Array[String]:
	var queue: Array = [{"facts":[],"steps":[]}]
	var seen := {}
	for iteration in 16:
		if queue.is_empty(): break
		var node: Dictionary = queue.pop_front()
		var facts: Array = node.facts
		if facts.has(target):
			var result: Array[String] = []
			result.assign(node.steps)
			return result
		for action in ACTIONS:
			var allowed := true
			for fact in action.requires:
				if not facts.has(fact): allowed=false
			if not allowed: continue
			var next: Array = facts.duplicate()
			for fact in action.adds:
				if not next.has(fact): next.append(fact)
			next.sort()
			var key := str(next)
			if seen.has(key): continue
			seen[key]=true
			var steps: Array = node.steps.duplicate()
			steps.append(action.name)
			queue.append({"facts":next,"steps":steps})
	return []
