class_name GemSave
extends RefCounted

const PATH = "user://run_v1.json"

static func write_snapshot(data: Dictionary, path: String = PATH) -> Error:
	if path == PATH and GemCatalog.campaign(): path = "user://run_campaign_v%d.json" % int(GemCatalog.DATA.version)
	if path == PATH and GemCatalog.expanded_gems():
		path = "user://run_expanded_gems_dev.json"
	var file = FileAccess.open(path+".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	# Rename only after a complete write; never discard a good checkpoint first.
	return DirAccess.rename_absolute(path+".tmp", path)

static func read_snapshot(path: String = PATH) -> Dictionary:
	if path == PATH and GemCatalog.campaign(): path = "user://run_campaign_v%d.json" % int(GemCatalog.DATA.version)
	if path == PATH and GemCatalog.expanded_gems():
		path = "user://run_expanded_gems_dev.json"
	if not FileAccess.file_exists(path):
		return {}
	var decoded = JSON.parse_string(FileAccess.get_file_as_string(path))
	return decoded if decoded is Dictionary else {}
