extends Node3D
const MODELS = [preload("res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb"), preload("res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Ranger.glb"), preload("res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb")]
const State = preload("res://colony/colonist_state.gd")

var name_label: Label3D
var animation_player: AnimationPlayer
var idle_clip: StringName
var walk_clip: StringName

func setup(state: State) -> void:
	position = Vector3(state.position)+Vector3(0.5,0,0.5)
	var model := MODELS[posmod(state.id-1, MODELS.size())].instantiate() as Node3D
	add_child(model)
	var players := model.find_children("*","AnimationPlayer",true,false)
	for player in players:
		for clip in player.get_animation_list():
			var lower := String(clip).to_lower()
			if idle_clip == &"" and "idle" in lower:
				idle_clip = clip
			if walk_clip == &"" and "walk" in lower:
				walk_clip = clip
		if idle_clip != &"":
			animation_player = player
			if walk_clip != &"" and not animation_player.has_animation(walk_clip): walk_clip = &""
			animation_player.play(idle_clip)
			break
		walk_clip = &""
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
	if animation_player != null:
		var desired := walk_clip if offset.length() > 0.05 and walk_clip != &"" else idle_clip
		if animation_player.current_animation != desired:
			animation_player.play(desired,0.15)
	position=position.move_toward(target,delta*3.0)
	name_label.text=state.display_name+" | "+state.activity
