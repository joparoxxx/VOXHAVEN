extends SceneTree
const Atlas = preload("res://world/terrain_atlas.gd")
func _initialize() -> void:
	var lookup := Atlas.build_lookup()
	var ok := lookup.size()==54 and FileAccess.file_exists(Atlas.TEXTURE_PATH)
	# Match the owner-approved textured Cube World terrain, not the flat-color blocks.
	ok = ok and Atlas.TEXTURE_PATH.ends_with("/Blocks_PixelArt.png")
	ok = ok and Atlas.ROOT.ends_with("/Pixel Blocks/")
	for model in Atlas.MODELS:
		if model != "":
			ok = ok and FileAccess.file_exists(Atlas.ROOT + model + ".gltf")
	for key in lookup:
		var corners: PackedVector2Array = lookup[key]
		ok = ok and corners.size()==4
		for uv in corners:
			ok = ok and uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1
			# Different UV corners preserve the original textured Cube World pixel tile.
	print("Atlas faces: ",lookup.size())
	quit(0 if ok else 1)
