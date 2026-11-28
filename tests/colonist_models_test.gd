extends SceneTree
# Validate all approved Cube World humanoid variants after Godot imports.
const MODELS = [
 "res://assets/library/Quaternius_Cube_World/Characters/Character_Male_1.gltf",
 "res://assets/library/Quaternius_Cube_World/Characters/Character_Female_1.gltf",
 "res://assets/library/Quaternius_Cube_World/Characters/Character_Male_2.gltf",
 "res://assets/library/Quaternius_Cube_World/Characters/Character_Female_2.gltf"
]

func _initialize() -> void:
 var ok := true
 for path in MODELS:
  var scene := load(path) as PackedScene
  if scene == null:
   push_error("Cannot load Cube World model: " + path)
   ok = false
   continue
  var model := scene.instantiate()
  var has_idle := false
  var has_walk := false
  for node in model.find_children("*", "AnimationPlayer", true, false):
   var player := node as AnimationPlayer
   for clip in player.get_animation_list():
    var name := String(clip).get_file().to_lower()
    if name == "idle":
     has_idle = true
    if name == "walk":
     has_walk = true
  if not (has_idle and has_walk):
   push_error("Cube World model lacks Idle/Walk animation: " + path)
   ok = false
  model.free()
 print("Cube World colonist models: ", "PASS" if ok else "FAIL")
 quit(0 if ok else 1)
