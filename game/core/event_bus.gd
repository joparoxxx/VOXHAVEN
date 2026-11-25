extends Node
## Central main-thread notification bus. Events contain identifiers and statuses, not secrets or file payloads.
signal published(topic: String, details: Dictionary)
const TOPICS := ["task.changed", "robot.profile_changed", "skill.imported", "skill.assigned"]
static func publish(topic: String, details: Dictionary) -> void:
	if topic not in TOPICS:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var bus := tree.root.get_node_or_null("Events")
	if bus != null:
		bus.emit_signal("published", topic, details.duplicate(true))
