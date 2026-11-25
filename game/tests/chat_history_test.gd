extends SceneTree
const History = preload("res://core/chat_history.gd")

func _initialize() -> void:
	var root := "user://cubyte-history-test-" + str(Time.get_ticks_usec())
	var store = History.new(root)
	var turns := []
	for n in range(15):
		turns.append({"user": "message " + str(n), "assistant": "reply " + str(n)})
	var ok: bool = store.save("atlas", turns)
	ok = store.save("pixel", [{"user": "design", "assistant": "idea"}]) and ok
	var reopened = History.new(root)
	var saved: Dictionary = reopened.load_all()
	var atlas: Array = saved.get("atlas", [])
	ok = ok and atlas.size() == 12
	if atlas.size() == 12:
		ok = ok and atlas[0]["user"] == "message 3"
	ok = ok and saved.get("pixel", []).size() == 1
	ok = ok and not store.save("../invalid", turns)
	ok = reopened.clear("atlas") and ok
	var after: Dictionary = reopened.load_all()
	ok = ok and not after.has("atlas") and after.has("pixel")
	reopened.clear("pixel")
	DirAccess.remove_absolute(root)
	print("Chat history smoke test: " + ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
