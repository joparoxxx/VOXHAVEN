extends RefCounted
## Built-in capabilities only. Metadata is not executable code.
const IDS := ["text", "png"]
const DEFINITIONS := {
	"text": {"label": "TXT", "extension": "txt", "runtime": "native", "requires_network": false},
	"png": {"label": "PNG sample", "extension": "png", "runtime": "native", "requires_network": false}
}

static func describe(id: String) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(id, {})
	return definition.duplicate(true)
