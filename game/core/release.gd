class_name GemRelease
extends RefCounted

const DATA: Dictionary = preload("res://data/release.json").data

static func version() -> String:
	if GemCatalog.campaign(): return "1.3.0-dev"
	return "1.1.0-dev" if GemCatalog.expanded_gems() else str(DATA.version)
