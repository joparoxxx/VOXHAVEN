extends SceneTree

const Skills = preload("res://core/skill_registry.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var path := "user://skills_test_" + str(Time.get_ticks_usec()) + "_" + str(randi())
	var registry = Skills.new(path)
	var doc := "---\nname: write-note\ndescription: Creates a note.\n---\n# Write a note\nDo not execute arbitrary code.\n"
	check(registry.import_markdown(doc) == "write-note", "import valid metadata")
	check(registry.import_markdown(doc).is_empty(), "reject duplicate skill")
	check(registry.import_markdown(doc.replace("write-note", "../bad")).is_empty(), "reject unsafe name")
	check(registry.import_markdown(doc.replace("description: Creates a note.", "name: twice\ndescription: Duplicate")).is_empty(), "reject duplicate metadata")
	check(registry.import_markdown(doc + "x".repeat(70000)).is_empty(), "reject oversized document")
	check(registry.import_markdown("---\nname: no-desc\n---\n").is_empty(), "reject missing description")
	check(not registry.equip("atlas", "write-note", "shell"), "reject unknown tool")
	check(not registry.equip("atlas", "missing", "text"), "reject unknown skill")
	check(registry.equip("atlas", "write-note", "text"), "explicit allowlisted binding")
	check(registry.get_binding("atlas").get("tool") == "text", "binding exists")
	check(registry.get_binding("pixel").is_empty(), "separate agent bindings")
	check(registry.import_markdown(doc.replace("write-note", "second-note")) == "second-note", "second skill")
	check(registry.equip("atlas", "second-note", "png"), "equip another skill")
	check(registry.inventory("atlas").size() == 2, "inventory retains previous skill")
	check(registry.inventory("pixel").is_empty(), "inventory isolated")
	check(registry.equip("atlas", "write-note", "text"), "switch active skill")
	var restored = Skills.new(path)
	check(restored.inventory("atlas").size() == 2, "inventory persisted")
	check(restored.get_binding("atlas").get("skill") == "write-note", "persistent assignment")
	check(restored.get_skill("write-note").get("description") == "Creates a note.", "persistent metadata")
	check(restored.get_skill("write-note").get("markdown") == doc, "persistent source")
	print("CUBYTE skill tests: ", failures, " failures")
	quit(0 if failures == 0 else 1)
