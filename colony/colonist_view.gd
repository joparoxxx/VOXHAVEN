extends Node3D
# These four GLTF scenes are present in the Cube World asset library.
const MODELS = [
	preload("res://assets/library/Quaternius_Cube_World/Characters/Character_Male_1.gltf"),
	preload("res://assets/library/Quaternius_Cube_World/Characters/Character_Female_1.gltf"),
	preload("res://assets/library/Quaternius_Cube_World/Characters/Character_Male_2.gltf"),
	preload("res://assets/library/Quaternius_Cube_World/Characters/Character_Female_2.gltf")
]
const State = preload("res://colony/colonist_state.gd")

var name_label: Label3D
var animation_players: Array[AnimationPlayer] = []

func setup(state: State) -> void:
	position = Vector3(state.position)+Vector3(0.5,0,0.5)
	var model := MODELS[posmod(state.id - 1, MODELS.size())].instantiate() as Node3D
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

const WALK_SPEED := 4.0

func sync_state(state: State,delta: float) -> void:
	var target := Vector3(state.position)+Vector3(0.5,0,0.5)
	var offset: Vector3 = target-position
	var moving: bool = offset.length_squared()>0.0025
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x,offset.z), clampf(delta*12.0,0.0,1.0))
	# The imported Cube World characters already contain Punch and Walk_Hold.
	# Play a job motion until the timed job finishes, not just a single still frame.
	if state.activity == "Mining" or state.activity == "Chopping":
		_play_motion("Punch")
	elif state.activity == "Carrying resources":
		_play_motion("Walk_Hold" if moving else "Idle_Hold")
	elif moving or (not state.route.is_empty() and state.activity != "Yielding path"):
		# Keep the walk cycle active between closely spaced grid waypoints.
		_play_motion("Walk")
	else:
		_play_motion("Idle")
	# Ordinary walking interpolation; gravity/falling is intentionally disabled.
	position = position.move_toward(target,maxf(0.0,delta)*WALK_SPEED)
	name_label.text=state.display_name+" | "+state.activity
