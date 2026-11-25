extends RefCounted
## Local game progression, not real money or provider credits.
const Snapshot = preload("res://core/snapshot_store.gd")
const UPGRADES := {"plant": {"name":"Office plant","cost":25}, "lounge":{"name":"Lounge chair","cost":50}, "lamp":{"name":"Desk lamp","cost":75}}
var store
var state := {"version":1,"company":"CUBYTE Studio","credits":100,"completed":0,"upgrades":[],"rewarded":{}}
var ready := false

func _init(root: String = "user://cubyte/company") -> void:
	store = Snapshot.new(root, "company.json")
	ready = store.ready
	if not ready:
		return
	var saved: Dictionary = store.read("company", "", 1048576)
	if not saved.get("ok", false):
		ready = false
	elif saved.get("found", false):
		var raw: Variant = JSON.parse_string(str(saved.get("value","")))
		if not _valid(raw):
			ready = false
		else:
			state = raw

func _valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("company") is String or str(raw["company"]).length() > 40:
		return false
	for field in ["credits","completed"]:
		var v: Variant = raw.get(field)
		if not (v is int or v is float) or float(v) != int(v) or v < 0 or v > 10000000:
			return false
	if not raw.get("upgrades") is Array or not raw.get("rewarded") is Dictionary or raw["rewarded"].size() > 10000:
		return false
	var seen := []
	for id in raw["upgrades"]:
		if id not in UPGRADES or id in seen:
			return false
		seen.append(id)
	for id in raw["rewarded"]:
		if not id is String or not id.is_valid_int() or raw["rewarded"][id] != true:
			return false
	return true

func snapshot() -> Dictionary:
	return state.duplicate(true)

func _commit(next: Dictionary) -> bool:
	if not ready or not _valid(next) or not store.write("company", JSON.stringify(next)):
		return false
	state = next
	return true

func rename_company(value: String) -> bool:
	var name_ := value.strip_edges()
	if name_.is_empty() or name_.length() > 40:
		return false
	var next := snapshot()
	next["company"] = name_
	return _commit(next)

func reward(task: Dictionary) -> bool:
	# An existing task may emit more than once (e.g. artifact rename).
	var id := str(task.get("id", ""))
	if task.get("status") != "succeeded" or not id.is_valid_int() or int(id) <= 0 or state["rewarded"].has(id):
		return false
	var next := snapshot()
	next["rewarded"][id] = true
	next["credits"] += 10
	next["completed"] += 1
	return _commit(next)

func purchase(id: String) -> bool:
	if id not in UPGRADES or id in state["upgrades"]:
		return false
	var price: int = UPGRADES[id]["cost"]
	if int(state["credits"]) < price:
		return false
	var next := snapshot()
	next["credits"] -= price
	next["upgrades"].append(id)
	return _commit(next)
