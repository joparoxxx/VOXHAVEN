extends RefCounted
## Shared offline item IDs. Terrain block IDs remain unchanged and wood is an item.
const WOOD := 100

static func is_valid(item_id: int) -> bool:
	return (item_id > 0 and item_id <= 9) or item_id == WOOD

static func display_name(item_id: int) -> String:
	if item_id == WOOD:
		return "Wood"
	return "Block %d" % item_id
