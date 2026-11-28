extends Node3D
const State = preload("res://colony/colonist_state.gd")
const CUBE_CHARACTERS := "res://assets/library/Quaternius_Cube_World/Characters"
const FALLBACK_MODELS := [
 "res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
 "res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Ranger.glb",
 "res://assets/library/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb"
]

static var discovered_models: Array[String] = []
static var scanned := false
var name_label: Label3D
var animation_player: AnimationPlayer
var idle_clip: StringName
var walk_clip: StringName

static func _collect_models(folder: String) -> void:
 var dir := DirAccess.open(folder)
 if dir == null:
  return
 dir.list_dir_begin()
 var entry := dir.get_next()
 while entry != "":
  if entry != "." and entry != "..":
   var path := folder.path_join(entry)
   if dir.current_is_dir():
    _collect_models(path)
   elif entry.to_lower().ends_with(".gltf") or entry.to_lower().ends_with(".glb"):
    if ResourceLoader.exists(path) and ("character" in entry.to_lower() or "colonist" in entry.to_lower() or "human" in entry.to_lower()):
     discovered_models.append(path)
  entry = dir.get_next()
 dir.list_dir_end()

static func _scan_models() -> void:
 if scanned:
  return
 scanned = true
 _collect_models(CUBE_CHARACTERS)
 discovered_models.sort()
 if discovered_models.is_empty():
  for path in FALLBACK_MODELS:
   if ResourceLoader.exists(path):
    discovered_models.append(path)
 if discovered_models.is_empty():
  push_error("VOXHAVEN: No importable colonist models found.")

func setup(state: State) -> void:
 position = Vector3(state.position) + Vector3(0.5, 0, 0.5)
 _scan_models()
 if not discovered_models.is_empty():
  var path := discovered_models[posmod(state.id - 1, discovered_models.size())]
  var model := _load_model(path)
  if model == null:
   for fallback in FALLBACK_MODELS:
    model = _load_model(fallback)
    if model != null:
     path = fallback
     break
  if model != null:
   if path.begins_with(CUBE_CHARACTERS):
    model.scale = Vector3.ONE * 0.65
   add_child(model)
   _configure_animations(model)
 var label := Label3D.new()
 label.text = state.display_name
 label.position.y = 2.1
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size = 32
 label.outline_size = 6
 add_child(label)
 name_label = label

func _load_model(path: String) -> Node3D:
 if not ResourceLoader.exists(path):
  return null
 var resource := load(path) as PackedScene
 if resource == null:
  return null
 var instance := resource.instantiate()
 if not instance is Node3D:
  instance.free()
  return null
 return instance as Node3D

func _configure_animations(model: Node3D) -> void:
 for node in model.find_children("*", "AnimationPlayer", true, false):
  var player := node as AnimationPlayer
  var found_idle: StringName = &""
  var found_walk: StringName = &""
  for clip in player.get_animation_list():
   var lower := String(clip).get_file().to_lower()
   if found_idle == &"" and "idle" in lower:
    found_idle = clip
   if found_walk == &"" and ("walk" in lower or "run" in lower):
    found_walk = clip
  if found_idle != &"" or found_walk != &"":
   animation_player = player
   idle_clip = found_idle if found_idle != &"" else found_walk
   walk_clip = found_walk
   animation_player.play(idle_clip)
   return

func sync_state(state: State, delta: float) -> void:
 var target := Vector3(state.position) + Vector3(0.5, 0, 0.5)
 var offset := target - position
 var moving := Vector2(offset.x, offset.z).length() > 0.05
 if moving:
  rotation.y = atan2(offset.x, offset.z)
 if animation_player != null:
  var desired := walk_clip if moving and walk_clip != &"" else idle_clip
  if desired != &"" and animation_player.current_animation != desired:
   animation_player.play(desired, 0.15)
 position = position.move_toward(target, delta * 3.0)
 if name_label != null:
  name_label.text = state.display_name + " | " + state.activity
