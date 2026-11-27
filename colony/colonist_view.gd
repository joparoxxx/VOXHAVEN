extends Node3D
const Model = preload("res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb")
const State = preload("res://colony/colonist_state.gd")

var name_label: Label3D

func setup(state: State) -> void:
	position = Vector3(state.position)+Vector3(0.5,0,0.5)
	var model := Model.instantiate() as Node3D
	add_child(model)
	var players := model.find_children("*","AnimationPlayer",true,false)
	for player in players:
		for clip in player.get_animation_list():
			if "idle" in String(clip).to_lower():
				player.play(clip)
				break
	var label := Label3D.new()
	label.text = state.display_name
	label.position.y = 2.4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 6
	add_child(label)
	name_label=label

func sync_state(state: State,delta: float) -> void:
	var target := Vector3(state.position)+Vector3(0.5,0,0.5)
	var offset := target-position
	if Vector2(offset.x,offset.z).length()>0.05:
		rotation.y=atan2(offset.x,offset.z)
	position=position.move_toward(target,delta*3.0)
	name_label.text=state.display_name+" | "+state.activity
