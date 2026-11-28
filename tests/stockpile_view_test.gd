extends SceneTree
const View = preload("res://world/stockpile_view.gd")

func _initialize() -> void:
	# SceneTree._initialize runs before the root is fully initialized.
	# Construct 3D visuals after the first deferred tree iteration.
	call_deferred("_run")

func _run() -> void:
	var scene := View.new()
	get_root().add_child(scene)
	scene.update_stock(Vector3i(2,35,-1),7,3)
	var positioned := scene.position == Vector3(2,35,-1)
	var has_label := scene.counter != null
	var label_correct := has_label and scene.counter.text.contains("WOOD  3")
	var has_geometry := scene.get_child_count() >= 3
	var ok := positioned and label_correct and has_geometry
	if not ok:
		print("Stockpile diagnostics: position=",scene.position," positioned=",positioned," counter=",has_label," label=",(scene.counter.text if has_label else "(missing)")," children=",scene.get_child_count())
	print("Stockpile display: ","PASS" if ok else "FAIL")
	scene.free()
	quit(0 if ok else 1)
