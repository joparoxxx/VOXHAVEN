extends Node3D
## Visual footprint for the real hauling destination; no new mesh assets.
## Uses the existing Cube World crate GLTF and a simple bordered ground pad.
const CRATE = preload("res://assets/library/Quaternius_Cube_World/Blocks/Block_Crate.gltf")
var counter: Label3D

func _ready() -> void:
	var pad := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(2.5,0.035,2.5)
	pad.mesh = slab
	pad.position = Vector3(0.5,0.02,0.5)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.58,0.39,0.20,0.52)
	floor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = floor_material
	add_child(pad)
	var crate := CRATE.instantiate() as Node3D
	if crate != null:
		crate.scale = Vector3.ONE * 0.32
		crate.position = Vector3(0.5,0.35,0.5)
		add_child(crate)
	counter = Label3D.new()
	counter.position = Vector3(0.5,1.55,0.5)
	counter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	counter.font_size = 30
	counter.outline_size = 8
	counter.pixel_size = 0.0045
	add_child(counter)

func update_stock(p: Vector3i, stored: int, wood: int) -> void:
	position = Vector3(p)
	if counter != null:
		counter.text = "STOCKPILE  %d\nWOOD  %d" % [stored,wood]
