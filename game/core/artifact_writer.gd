extends RefCounted
## Data-only file writers. Generated source/markup is never executed.
const MAX_BYTES := 65536
static func valid(tool: String, payload: String) -> bool:
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		return false
	match tool:
		"png": return payload.is_empty()
		"json": return JSON.new().parse(payload) == OK
		"svg":
			# Only a constrained rectangle drawing, not arbitrary active XML.
			var parsed: Variant = JSON.parse_string(payload)
			return parsed is Dictionary and parsed.get("color") is String and Color.html_is_valid(parsed["color"])
		"obj":
			return payload in ["cube", "pyramid"]
		"csv", "xlsx":
			var rows: Variant = JSON.parse_string(payload)
			if not rows is Array or rows.is_empty() or rows.size() > 100:
				return false
			for row in rows:
				if not row is Array or row.is_empty() or row.size() > 20:
					return false
				for cell in row:
					if not (cell is String or cell is float or cell is int or cell is bool):
						return false
					if str(cell).length() > 1000:
						return false
			return true
		"text", "md", "code", "pdf", "docx": return true
	return false

static func _write(path: String, data: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return ok and FileAccess.get_file_as_bytes(path) == data

static func _xml(value: String) -> String:
	var result := ""
	for ch in value:
		var n: int = ch.unicode_at(0)
		if n >= 32 or n in [9, 10, 13]:
			result += ch
	return result.xml_escape(true)

static func _zip(path: String, parts: Dictionary) -> bool:
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return false
	var ok := true
	for name in parts:
		if zip.start_file(name) != OK:
			ok = false
			break
		if zip.write_file(str(parts[name]).to_utf8_buffer()) != OK:
			ok = false
		if zip.close_file() != OK:
			ok = false
		if not ok:
			break
	ok = zip.close() == OK and ok
	if not ok:
		return false
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return false
	for name in parts:
		if not reader.file_exists(name) or reader.read_file(name) != str(parts[name]).to_utf8_buffer():
			ok = false
	reader.close()
	return ok

static func _package(path: String, tool: String, payload: String) -> bool:
	var ns := "http://schemas.openxmlformats.org"
	var root := "word/document.xml" if tool == "docx" else "xl/workbook.xml"
	var mime := "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml" if tool == "docx" else "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
	var types := '<Types xmlns="' + ns + '/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/' + root + '" ContentType="' + mime + '"/>'
	var rels := '<Relationships xmlns="' + ns + '/package/2006/relationships"><Relationship Id="rId1" Type="' + ns + '/officeDocument/2006/relationships/officeDocument" Target="' + root + '"/></Relationships>'
	var parts := {"_rels/.rels": rels}
	if tool == "docx":
		var doc := '<w:document xmlns:w="' + ns + '/wordprocessingml/2006/main"><w:body>'
		for line in payload.split("\n"):
			doc += '<w:p><w:r><w:t xml:space="preserve">' + _xml(line) + '</w:t></w:r></w:p>'
		doc += '<w:sectPr/></w:body></w:document>'
		parts[root] = doc
	else:
		types += '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
		parts[root] = '<workbook xmlns="' + ns + '/spreadsheetml/2006/main" xmlns:r="' + ns + '/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'
		parts["xl/_rels/workbook.xml.rels"] = '<Relationships xmlns="' + ns + '/package/2006/relationships"><Relationship Id="rId1" Type="' + ns + '/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'
		var sheet := '<worksheet xmlns="' + ns + '/spreadsheetml/2006/main"><sheetData>'
		var rows: Array = JSON.parse_string(payload)
		for i in range(rows.size()):
			sheet += '<row r="' + str(i + 1) + '">'
			for j in range(rows[i].size()):
				var ref := String.chr(65 + j) + str(i + 1)
				sheet += '<c r="' + ref + '" t="inlineStr"><is><t xml:space="preserve">' + _xml(str(rows[i][j])) + '</t></is></c>'
			sheet += '</row>'
		parts["xl/worksheets/sheet1.xml"] = sheet + '</sheetData></worksheet>'
	parts["[Content_Types].xml"] = types + '</Types>'
	return _zip(path, parts)

static func _pdf(path: String, payload: String) -> bool:
	# Rasterize text using Godot's bundled font is not available headless; use standard PDF Helvetica.
	# Reject unsupported characters rather than corrupt Unicode or silently truncate content.
	for ch in payload:
		if ch.unicode_at(0) > 126 or (ch.unicode_at(0) < 32 and ch not in ["\n", "\r", "\t"]):
			return false
	var lines: Array[String] = []
	for raw in payload.replace("\r", "").replace("\t", "    ").split("\n"):
		var line: String = raw
		while line.length() > 80:
			lines.append(line.left(80))
			line = line.substr(80)
		lines.append(line)
	var objects: Array[String] = ["<< /Type /Catalog /Pages 2 0 R >>", "", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
	var kids := ""
	var count := 0
	for start in range(0, lines.size(), 48):
		var page_id := objects.size() + 1
		kids += str(page_id) + " 0 R "
		count += 1
		var stream := "BT /F1 11 Tf 50 780 Td 15 TL\n"
		for line in lines.slice(start, start + 48):
			stream += "(" + line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)") + ") Tj T*\n"
		stream += "ET\n"
		objects.append("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents " + str(page_id + 1) + " 0 R >>")
		objects.append("<< /Length " + str(stream.to_utf8_buffer().size()) + " >>\nstream\n" + stream + "endstream")
	objects[1] = "<< /Type /Pages /Count " + str(count) + " /Kids [" + kids + "] >>"
	var pdf := "%PDF-1.4\n"
	var offsets: Array[int] = [0]
	for i in range(objects.size()):
		offsets.append(pdf.to_utf8_buffer().size())
		pdf += str(i + 1) + " 0 obj\n" + objects[i] + "\nendobj\n"
	var xref := pdf.to_utf8_buffer().size()
	pdf += "xref\n0 " + str(offsets.size()) + "\n0000000000 65535 f \n"
	for i in range(1, offsets.size()):
		pdf += "%010d 00000 n \n" % offsets[i]
	pdf += "trailer\n<< /Size " + str(offsets.size()) + " /Root 1 0 R >>\nstartxref\n" + str(xref) + "\n%%EOF\n"
	return _write(path, pdf.to_utf8_buffer())

static func create(tool: String, payload: String, path: String) -> bool:
	if not valid(tool, payload):
		return false
	match tool:
		"docx", "xlsx": return _package(path, tool, payload)
		"pdf": return _pdf(path, payload)
		"csv":
			var rows: Array = JSON.parse_string(payload)
			var lines: PackedStringArray = []
			for row in rows:
				var cells: PackedStringArray = []
				for cell in row:
					var value := str(cell)
					# Prevent spreadsheet formula injection from generated text.
					if value.strip_edges().left(1) in ["=", "+", "-", "@"]:
						value = "'" + value
					cells.append('"' + value.replace('"', '""') + '"')
				lines.append(",".join(cells))
			return _write(path, ("\r\n".join(lines) + "\r\n").to_utf8_buffer())
		"svg":
			var parsed: Dictionary = JSON.parse_string(payload)
			var color := Color.html(str(parsed["color"])).to_html(false)
			return _write(path, ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" rx="24" fill="#' + color + '"/></svg>').to_utf8_buffer())
		"obj":
			var obj := "o cube\nv -1 -1 -1\nv 1 -1 -1\nv 1 1 -1\nv -1 1 -1\nv -1 -1 1\nv 1 -1 1\nv 1 1 1\nv -1 1 1\nf 1 4 3 2\nf 5 6 7 8\nf 1 2 6 5\nf 2 3 7 6\nf 3 4 8 7\nf 4 1 5 8\n"
			if payload == "pyramid":
				obj = "o pyramid\nv -1 0 -1\nv 1 0 -1\nv 1 0 1\nv -1 0 1\nv 0 2 0\nf 1 2 3 4\nf 1 5 2\nf 2 5 3\nf 3 5 4\nf 4 5 1\n"
			return _write(path, obj.to_utf8_buffer())
		"png": return false # existing sample writer in task engine
		_: return _write(path, payload.to_utf8_buffer())
