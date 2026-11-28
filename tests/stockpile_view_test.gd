extends SceneTree
const View = preload("res://world/stockpile_view.gd")

func _initialize() -> void:
	var s := View.new()
	get_root().add_child(s)
	s.update_stock(Vector3i(2,35,-1),7,3)
	var ok := s.position == Vector3(2,35,-1)
	ok = ok and s.counter != null and s.counter.text.contains("WOOD  3")
	ok = ok and s.get_child_count() >= 3
	print("Stockpile display: ","PASS" if ok else "FAIL")
	s.free()
	quit(0 if ok else 1)
