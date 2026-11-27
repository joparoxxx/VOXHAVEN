extends Node3D
const Model = preload("res://assets/library/Quaternius_Cube_World/Characters/Character_Male_1.gltf")
const State = preload("res://colony/colonist_state.gd")

var name_label: Label3D
var animation_players: Array[AnimationPlayer] = []

func setup(state: State) -> void:
	position = Vector3(state.position)+Vector3(0.5,0,0.5)
	var model := Model.instantiate() as Node3D
	model.scale = Vector3.ONE * 0.65
	add_child(model)
	for player in model.find_children("*","AnimationPlayer",true,false):
		animation_players.append(player as AnimationPlayer)
	_play_motion("Idle")
	var label := Label3D.new()
	label.text = state.display_name
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 6
	add_child(label)
	name_label=label

func _play_motion(clip: String) -> void:
	for player in animation_players:
		for key in player.get_animation_list():
			if String(key).get_file().to_lower() != clip.to_lower(): continue
			if player.current_animation == key and player.is_playing(): break
			var animation := player.get_animation(key)
			animation.loop_mode = Animation.LOOP_LINEAR
			player.play(key,0.15)
			break

func sync_state(state: State,delta: float) -> void:
	var target := Vector3(state.position)+Vector3(0.5,0,0.5)
	var offset := target-position
	var moving := Vector2(offset.x,offset.z).length()>0.05
	if moving:
		rotation.y=atan2(offset.x,offset.z)
	_play_motion("Walk" if moving else "Idle")
	position=position.move_toward(target,delta*3.0)
	name_label.text=state.display_name+" | "+state.activity
