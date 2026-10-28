class_name GemRunSummary
extends AcceptDialog

signal leaderboard_requested

var content: MarginContainer
var tabs: TabContainer
var summary: RichTextLabel
var report_text: TextEdit
var copy_button: Button
var status: Label

func _ready() -> void:
	title = "Run summary"
	wrap_controls = false
	min_size = Vector2i(720,540)
	get_ok_button().text = "Close"
	content = MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		content.add_theme_constant_override("margin_"+side,12)
	add_child(content)
	var box = VBoxContainer.new()
	content.add_child(box)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	summary = RichTextLabel.new()
	summary.name = "Summary"
	summary.bbcode_enabled = true
	summary.add_theme_font_size_override("normal_font_size",16)
	tabs.add_child(summary)
	report_text = TextEdit.new()
	report_text.name = "Report"
	report_text.editable = false
	report_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	report_text.add_theme_font_size_override("font_size",12)
	tabs.add_child(report_text)
	copy_button = Button.new()
	copy_button.text = "Copy test report"
	copy_button.pressed.connect(func():
		DisplayServer.clipboard_set(report_text.text)
		status.text = "Report prepared. If copying is unavailable, open Report and use Ctrl+A, Ctrl+C."
	)
	box.add_child(copy_button)
	var leaderboard_button = Button.new()
	leaderboard_button.text = "Leaderboard & submit result"
	leaderboard_button.pressed.connect(func(): leaderboard_requested.emit())
	box.add_child(leaderboard_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",12)
	box.add_child(status)
	size_changed.connect(func(): fit_content.call_deferred())
	content.resized.connect(func(): fit_content.call_deferred())
	content.minimum_size_changed.connect(func(): fit_content.call_deferred())

func fit_content() -> void:
	content.position = Vector2(8,8)
	content.size = Vector2(size.x-16,maxi(0,size.y-64))

func open_report(report: Dictionary) -> void:
	report_text.text = JSON.stringify(report,"  ")
	tabs.current_tab = 0
	status.text = "Include this report with feedback to share the seed, choices and wave outcomes."
	var outcome = {"won":"VICTORY","lost":"DEFEAT","build":"BUILD PHASE","intermission":"BETWEEN TRIALS · NO NEW GEMS","combat":"BATTLE IN PROGRESS"}.get(report.outcome,"RUN SUMMARY")
	summary.text = "[font_size=26][color=#e4d4a4]%s[/color][/font_size]\n\nVersion %s · %s\nSeed %s · Wave %d / %d\n%d lives · %d gold · %d defeated · %d leaked\n\n" % [outcome,report.game_version,report.balance_profile,report.seed,int(report.wave),int(report.get("wave_count",10)),int(report.lives),int(report.gold),int(report.kills),int(report.leaks)]
	if report.has("quality_discount"): summary.text += "Saved gem discount: %d gold\n\n" % int(report.quality_discount)
	if report.has("tower_moves_left"): summary.text += "Free tower moves left this run: %d / 5\nFurther moves: %d gold each.\n\n" % [int(report.tower_moves_left),int(GemCatalog.DATA.get("mechanics",{}).get("tower_move_cost_after_free",100))]
	if report.resumed_from_checkpoint:
		summary.text += "This session resumed at build phase %d. Earlier actions are outside this session report.\n\n" % int(report.starting_checkpoint.wave)
	summary.text += "[table=5][cell]Wave[/cell][cell]Result[/cell][cell]Defeated[/cell][cell]Leaked[/cell][cell]Time[/cell]"
	for wave in report.waves:
		summary.text += "[cell]%d[/cell][cell]%s[/cell][cell]%d[/cell][cell]%d[/cell][cell]%.1fs[/cell]" % [int(wave.wave),str(wave.status).replace("_"," "),int(wave.kills),int(wave.leaks),float(wave.seconds)]
	summary.text += "[/table]\n\n"
	if report.balance_profile == "full-solo-dev" and not report.waves.is_empty():
		var last: Dictionary = report.waves.back()
		var diagnostic: Dictionary = last.get("diagnostics",{})
		if not diagnostic.is_empty():
			summary.text += "[b]Wave %d · combat analysis[/b]\n" % int(last.wave)
			if diagnostic.has("boss"):
				var boss: Dictionary = diagnostic.boss
				summary.text += "%s: %.1f%% HP remaining (%s).\n" % [boss.name,boss.remaining_percent,"escaped" if boss.escaped else "defeated" if boss.defeated else "fighting"]
			var total: Dictionary = diagnostic.totals
			summary.text += "Effective damage: %.0f physical / %.0f magical / %.0f pure.\n%d missed · %d blocked damage events · %d discarded projectiles.\n" % [total.physical,total.magical,total.pure,total.missed,total.blocked,total.discarded]
			for source in diagnostic.top_sources.slice(0,5):
				summary.text += "%s (%d,%d): %.0f damage; %.1fs in boss range, %.1fs targetable, %.1fs disabled; %.1fs damaging aura.\n" % [source.name,int(source.at[0])+1,int(source.at[1])+1,source.damage,source.boss_range_seconds,source.boss_targetable_seconds,source.boss_disabled_seconds,source.boss_effect_seconds]
			summary.text += "Damage excludes overkill. Range windows are sampled at 30 Hz; full detail is in Report.\n\n"
	if report.waves.is_empty():
		summary.text += "No battle recorded in this session yet.\n\n"
	if report.actions_truncated:
		summary.text += "The action journal reached its storage limit and is truncated.\n\n"
	var balance_blurb = "Base values follow the reviewed Dota snapshot. Campaign adaptations are described below." if report.balance_profile == "full-solo-dev" else "Original tower and enemy base values are retained; the ten-wave economy and leak costs are adaptations."
	summary.text += "[b]Balance reference[/b]\nDota 2 GemTD snapshot: %s. %s\n\n" % [report.reference_date,balance_blurb]
	if not str(report.get("balance_note","")).is_empty():
		summary.text += str(report.balance_note)+"\n\n"
	summary.text += "The Report tab contains the starting checkpoint and accepted actions. Reload resumes a build checkpoint, not a battle in progress."
	summary.scroll_to_line(0)
	popup_centered(Vector2i(820,740))
	fit_content.call_deferred()
