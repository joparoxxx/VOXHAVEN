extends RefCounted
## Local role progression. Rewards are committed once per real successful task.
const Snapshot = preload("res://core/snapshot_store.gd")
const Writer = preload("res://core/artifact_writer.gd")
const IDS := ["atlas", "pixel", "mesh", "nova"]
const MISSIONS := {
	"atlas": [
		{"title":"First Brief","tool":"text","target":1,"bonus":40,"equipment":"Coordinator Badge","sample":"Project brief: outline the goal, deliverables and next steps."},
		{"title":"Project Planner","tool":"md","target":2,"bonus":60,"equipment":"Planner Module","sample":"# Project plan\n- Define scope\n- Assign responsibilities\n- Review deliverables"},
		{"title":"Executive Reports","tool":"pdf","target":3,"bonus":90,"equipment":"Executive Core","sample":"Project status report\nObjective: Deliver a complete project.\nNext step: Review results."}
	],
	"pixel": [
		{"title":"Visual Starter","tool":"png","target":1,"bonus":40,"equipment":"Color Sensor","sample":""},
		{"title":"Color Lab","tool":"svg","target":2,"bonus":60,"equipment":"Vector Lens","sample":"{\"color\":\"#a48bdf\"}"},
		{"title":"Design Portfolio","tool":"svg","target":3,"bonus":90,"equipment":"Creative Core","sample":"{\"color\":\"#70d7b1\"}"}
	],
	"mesh": [
		{"title":"Model Blueprint","tool":"text","target":1,"bonus":40,"equipment":"Measuring Sensor","sample":"Model blueprint: create a simple geometric object with defined dimensions."},
		{"title":"Geometry Workshop","tool":"obj","target":2,"bonus":60,"equipment":"Precision Arm","sample":"cube"},
		{"title":"Prototype Collection","tool":"obj","target":3,"bonus":90,"equipment":"Fabrication Core","sample":"pyramid"}
	],
	"nova": [
		{"title":"Research Notes","tool":"text","target":1,"bonus":40,"equipment":"Data Sensor","sample":"Research notes: record a question, sources to verify and next steps."},
		{"title":"Data Organizer","tool":"csv","target":2,"bonus":60,"equipment":"Analysis Module","sample":"[[\"Item\",\"Status\"],[\"Task A\",\"Ready\"]]"},
		{"title":"Reporting Specialist","tool":"xlsx","target":3,"bonus":90,"equipment":"Analyst Core","sample":"[[\"Metric\",\"Value\"],[\"Completed\",\"3\"]]"}
	]
}
var store
var ready := false
var state := {"version":1,"robots":{},"rewarded":{}}

func _init(root: String = "user://cubyte/progression") -> void:
	for id in IDS:
		state["robots"][id] = {"xp":0,"mission":0,"progress":0,"equipped":-1,"jobs":0}
	store = Snapshot.new(root, "progress.json")
	ready = store.ready
	if not ready:
		return
	var saved: Dictionary = store.read("progress", "", 1048576)
	if not saved.get("ok", false):
		ready = false
	elif saved.get("found", false):
		var raw: Variant = JSON.parse_string(str(saved.get("value", "")))
		if not _valid(raw):
			ready = false
		else:
			state = raw

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and float(value) == int(value) and value >= low and value <= high

func _valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("robots") is Dictionary or not raw.get("rewarded") is Dictionary or raw["rewarded"].size() > 10000:
		return false
	for id in IDS:
		var entry: Variant = raw["robots"].get(id)
		if not entry is Dictionary:
			return false
		if not _integer(entry.get("xp"), 0, 10000000) or not _integer(entry.get("jobs"), 0, 10000):
			return false
		if not _integer(entry.get("mission"), 0, MISSIONS[id].size()):
			return false
		var index := int(entry["mission"])
		var limit: int = 0 if index == MISSIONS[id].size() else int(MISSIONS[id][index]["target"]) - 1
		if not _integer(entry.get("progress"), 0, limit) or not _integer(entry.get("equipped"), -1, index - 1):
			return false
	for key in raw["rewarded"]:
		if not key is String or not key.is_valid_int() or int(key) <= 0 or raw["rewarded"][key] != true:
			return false
	return true

func _commit(next: Dictionary) -> bool:
	if not ready or not _valid(next) or not store.write("progress", JSON.stringify(next)):
		return false
	state = next
	return true

func snapshot(id: String) -> Dictionary:
	var entry: Dictionary = state["robots"].get(id, {})
	return entry.duplicate(true)

func level(id: String) -> int:
	return mini(100, 1 + int(int(snapshot(id).get("xp", 0)) / 50.0))

func current_mission(id: String) -> Dictionary:
	if id not in IDS:
		return {}
	var index := int(snapshot(id)["mission"])
	return {} if index >= MISSIONS[id].size() else MISSIONS[id][index].duplicate(true)

func equipment(id: String) -> Array:
	if id not in IDS:
		return []
	var result := []
	var entry := snapshot(id)
	for index in range(int(entry["mission"])):
		result.append({"index":index,"name":MISSIONS[id][index]["equipment"],"speed_percent":10 * (index + 1),"equipped":int(entry["equipped"]) == index})
	return result

func speed_multiplier(id: String) -> float:
	return 1.0 + 0.1 * (int(snapshot(id).get("equipped", -1)) + 1)

func equip(id: String, index: int) -> bool:
	if id not in IDS or index < -1 or index >= int(snapshot(id)["mission"]):
		return false
	var next := state.duplicate(true)
	next["robots"][id]["equipped"] = index
	return _commit(next)

func reward(task: Dictionary) -> Dictionary:
	var id := str(task.get("robot_id", ""))
	var key := str(task.get("id", ""))
	if not ready or id not in IDS or task.get("status") != "succeeded" or not key.is_valid_int() or int(key) <= 0 or state["rewarded"].has(key):
		return {}
	var tool := str(task.get("tool", ""))
	if tool not in preload("res://core/tool_registry.gd").IDS:
		return {}
	# Task engine verifies file generation before publishing success.
	if str(task.get("artifact", "")).is_empty() or not FileAccess.file_exists(str(task["artifact"])):
		return {}
	var next := state.duplicate(true)
	var entry: Dictionary = next["robots"][id]
	var index := int(entry["mission"])
	var gained := 10
	var unlocked := ""
	var completed := ""
	if index < MISSIONS[id].size():
		var mission: Dictionary = MISSIONS[id][index]
		if tool == mission["tool"]:
			entry["progress"] += 1
			if int(entry["progress"]) >= int(mission["target"]):
				entry["mission"] += 1
				entry["progress"] = 0
				gained += int(mission["bonus"])
				unlocked = str(mission["equipment"])
				completed = str(mission["title"])
	entry["xp"] += gained
	entry["jobs"] += 1
	next["rewarded"][key] = true
	if not _commit(next):
		return {}
	return {"xp":gained,"mission":completed,"equipment":unlocked,"level":level(id)}
