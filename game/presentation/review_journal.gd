class_name GemReviewJournal
extends RefCounted

const MAX_ACTIONS = 2000
var starting_checkpoint: Dictionary = {}
var actions: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var active: Dictionary = {}
var truncated = false
var resumed = false

func reset(state: GemRun, from_checkpoint: bool) -> void:
	starting_checkpoint = state.snapshot().duplicate(true)
	actions.clear()
	waves.clear()
	active.clear()
	truncated = false
	resumed = from_checkpoint

func record(entry: Dictionary, combat: GemCombat) -> void:
	if actions.size() >= MAX_ACTIONS:
		truncated = true
		return
	var item = entry.duplicate(true)
	item.tick = roundi(combat.elapsed*30) if entry.phase == "combat" else 0
	item.order = actions.size()+1
	actions.append(item)

func begin_wave(state: GemRun) -> void:
	active = {"wave":state.wave,"kills_before":state.kills,"leaks_before":state.leaks,
		"lives_before":state.lives,"gold_before":state.gold,"quality_level":state.quality}

func wave_result(state: GemRun, combat: GemCombat, status: String) -> Dictionary:
	var result = {"wave":active.wave,"status":status,"seconds":snappedf(combat.elapsed,.001),
		"kills":state.kills-int(active.kills_before),"leaks":state.leaks-int(active.leaks_before),
		"lives_lost":int(active.lives_before)-state.lives,"lives_after":state.lives,
		"gold_delta":state.gold-int(active.gold_before),"gold_after":state.gold,"quality_level":state.quality}

	if combat is GemCampaignCombat: result.diagnostics = combat.audit.snapshot()
	return result

func complete_wave(state: GemRun, combat: GemCombat) -> bool:
	if active.is_empty() or state.phase == "combat":
		return false
	waves.append(wave_result(state,combat,"defeat" if state.phase == "lost" else "cleared"))
	active.clear()
	return true

func export_report(state: GemRun, combat: GemCombat) -> Dictionary:
	var history = waves.duplicate(true)
	if not active.is_empty():
		history.append(wave_result(state,combat,"in_progress"))
	var result = {"report_schema":1,"game_version":GemRelease.version(),"balance_profile":GemCatalog.DATA.get("profile",GemRelease.DATA.balance_profile),
		"catalog_version":GemCatalog.DATA.version,"catalog_sha256":GemCatalog.content_sha256(),"balance_note":GemCatalog.DATA.get("balance_note",""),
		"engine":Engine.get_version_info().string,"platform":OS.get_name(),"debug_build":OS.is_debug_build(),"reference_date":GemRelease.DATA.reference_date,
		"seed":str(state.initial_seed),"resumed_from_checkpoint":resumed,"starting_checkpoint":starting_checkpoint.duplicate(true),
		"outcome":state.phase,"wave":state.wave,"wave_count":GemCatalog.wave_count(),"lives":state.lives,"gold":state.gold,"kills":state.kills,"leaks":state.leaks,
		"actions_truncated":truncated,"actions":actions.duplicate(true),"waves":history,"board":state.board.serialize(),"slabs":state.serialize_slabs(),"streak":state.streak,"enemy_count":state.enemy_count}
	if GemCatalog.campaign(): result.merge({"quality_discount":state.quality_discount,"discounted_bosses":state.discounted_bosses.duplicate()})
	return result
