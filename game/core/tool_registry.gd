extends RefCounted
## Built-in capabilities only. Metadata is not executable code.
const IDS := ["text", "png", "md", "json", "csv", "pdf", "docx", "xlsx", "svg", "code", "obj"]
const DEFINITIONS := {
	"text": {"label": "TXT", "extension": "txt", "runtime": "native", "requires_network": false},
	"png": {"label": "PNG sample", "extension": "png", "runtime": "native", "requires_network": false},
	"md": {"label": "Markdown", "extension": "md", "runtime": "native", "requires_network": false},
	"json": {"label": "JSON", "extension": "json", "runtime": "native", "requires_network": false},
	"csv": {"label": "CSV", "extension": "csv", "runtime": "native", "requires_network": false},
	"pdf": {"label": "PDF", "extension": "pdf", "runtime": "native", "requires_network": false},
	"docx": {"label": "DOCX", "extension": "docx", "runtime": "native", "requires_network": false},
	"xlsx": {"label": "XLSX", "extension": "xlsx", "runtime": "native", "requires_network": false},
	"svg": {"label": "SVG shape", "extension": "svg", "runtime": "native", "requires_network": false},
	"code": {"label": "Source text", "extension": "code.txt", "runtime": "native", "requires_network": false},
	"obj": {"label": "OBJ primitive", "extension": "obj", "runtime": "native", "requires_network": false}
}

static func describe(id: String) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(id, {})
	return definition.duplicate(true)
