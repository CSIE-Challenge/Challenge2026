class_name Util

##### This part is for layer #####

##### End of layer #####


static func load_json(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error(
			"[Util] Failed to open file: %s, reason: %d" % [file_path, FileAccess.get_open_error()]
		)
		return null

	var content = file.get_as_text()
	file.close()

	var json_parsed = JSON.parse_string(content)
	if json_parsed == null:
		push_error("[Util] Failed to parse JSON from file: ", file_path)
		return null

	return json_parsed


static func save_json(file_path: String, data: Variant) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error(
			"[Util] Failed to open file: %s, reason: %d" % [file_path, FileAccess.get_open_error()]
		)
		return

	var dumped = JSON.stringify(data, "  ")
	if not file.store_string(dumped):
		push_error("[Util] Failed to write data to file: ", file_path)
	file.close()
