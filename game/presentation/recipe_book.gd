class_name GemRecipeBook
extends AcceptDialog

# Full-screen overview: every recipe is visible at once as a compact card.
# Ready recipes come first; click an ingredient to locate it, the pin to track the recipe.
signal locate_requested(cell: Vector2i)
signal track_requested(recipe: String)

const CARD_MIN_WIDTH = 186.0
const COMPACT_HEIGHT = 44.0
const ROW_MIN_WIDTH = 280.0
const READY = Color("6fc48a")
# Ingredients that are only available among this round's new gems (combining them is the final choice).
const FRESH = Color("f0cf4a")
const PARTIAL = Color("b8863b")
const GROUP_HEADER = 22.0
const MISSING = Color("4a5560")
const TRAP_WIDTH = 280.0
# Tower grades as the Dota 2 version labels them (help texts): grey, blue, pink, orange.
const GRADES = {"basic":["Basic","a3acb4"],"intermediate":["Intermediate","8f9cff"],"advanced":["Advanced","ff8fe8"],"top":["Top","ffa040"]}
const GRADE_OF = {"baiyin":"basic","kongqueshi":"basic","xingcaihongbaoshi":"basic","yu":"basic","furongshi":"basic",
	"heianfeicui":"intermediate","huangcailanbaoshi":"intermediate","palayibabixi":"intermediate","heisemaoyanshi":"intermediate",
	"jin":"intermediate","fenhongzuanshi":"intermediate","jixueshi":"intermediate","you238":"intermediate","baiyinqishi":"intermediate",
	"xianyandekongqueshi":"intermediate","xuehonghuoshan":"intermediate","shenhaizhenzhu":"intermediate","haiyangqingyu":"intermediate",
	"jixiangdezhongguoyu":"advanced","juxingfenhongzuanshi":"advanced","you235":"advanced","jingxindiaozhuodepalayibabixi":"advanced",
	"gudaidejixueshi":"advanced","mirendeqingjinshi":"advanced","aijijin":"advanced","hongshanhu":"advanced","feicuimoxiang":"advanced",
	"huaguoshanxiandan":"advanced","tianranzumulv":"advanced","haibao":"advanced",
	"keyinuoerguangmingzhishan":"top","shuaibiankaipayou":"top","heiwangzihuangguanhongbaoshi":"top","xingguanglanbaoshi":"top",
	"yijiazhishi":"top","huguoshenyishi":"top","jingangshikulinan":"top","sililankazhixing":"top"}
const TRAP_TINT = Color("d9a24a")
# One-line summaries from the Dota 2 version's help texts (presentation only; full rules are in the detail panel).
const SUMMARY = {
	"gudaidejixueshi":"Burns enemies in range, attacks have a chance to spark forked lightning.",
	"zhangqishiban":"Slows enemies passing by.",
	"huaguoshanxiandan":"Increases attack range and grants attacks regardless of evasion for allies around.",
	"jixiangdezhongguoyu":"Impairs flying enemies, poisons enemies, and has a chance to heal the gem tower on hit.",
	"baiyinqishi":"Slows and cleaves enemies on hit.",
	"hongshanhu":"Has several auras.",
	"feicuimoxiang":"Has a chance to stone-gaze enemies.",
	"keyinuoerguangmingzhishan":"Extreme attack damage and armor reduction, cleave, chances of crit.",
	"shenhaizhenzhu":"Helps towers nearby resist magic influence.",
	"yu":"Poisons enemies, fast attack speed.",
	"juxingfenhongzuanshi":"Cleaves enemies on hit, attacks have a chance to crit.",
	"furongshi":"Impairs flying enemies.",
	"haibao":"Slows enemies around; casts chain frost when nearby traps trigger.",
	"huguoshenyishi":"Random magical attack damage, impairs flying enemies.",
	"xianyandekongqueshi":"Attacks multiple enemies.",
	"heisemaoyanshi":"Boosts attack damage of nearby gem towers.",
	"jingxindiaozhuodepalayibabixi":"Greatly reduces enemies' armor in range, even through magic immunity.",
	"mabishiban":"Paralyzing powder ricochets among enemies passing by and stuns them.",
	"mirendeqingjinshi":"Impairs flying enemies.",
	"xuehonghuoshan":"Burns enemies in range.",
	"kongqueshi":"Attacks multiple enemies.",
	"haojiaoshiban":"Increases nearby towers' attack damage when enemies pass by.",
	"shuaibiankaipayou":"Extreme attack speed on several enemies at once.",
	"baiyin":"Slows enemies on hit.",
	"palayibabixi":"Decreases nearby enemies' armor.",
	"youbushiban":"Ensnares enemies passing by.",
	"huangcailanbaoshi":"Greatly slows nearby enemies.",
	"jixueshi":"Attacks have a chance to spark a lightning chain.",
	"xingguanglanbaoshi":"Slows enemies in a middle range; attack speed aura and slow aura.",
	"heianfeicui":"Has a chance to stun enemies.",
	"aijijin":"Greatly reduces one enemy's armor; chance to get gold on hit.",
	"heiwangzihuangguanhongbaoshi":"Extreme burn damage, chances of lightning and poison.",
	"fenhongzuanshi":"Attacks have a chance to crit.",
	"kongheshiban":"Terrorizes enemies passing by: more vulnerable and hurried.",
	"jingangshikulinan":"Huge attack damage; more range and evasion-proof attacks for allies around.",
	"xingcaihongbaoshi":"Burns nearby enemies.",
	"xuwushiban":"Decrepifies enemies passing by: more magic damage taken, slower.",
	"suanwushiban":"Creates an acid mist that decreases enemies' armor.",
	"jin":"Greatly reduces armor of a single enemy.",
	"you238":"Attacks multiple enemies, fast attack speed.",
	"sililankazhixing":"Gives enemies several weird debuffs.",
	"you235":"Attacks multiple enemies, fast attack speed.",
	"haiyangqingyu":"Increases attack range of allies around.",
	"hongliushiban":"Hurls enemies passing by into the sky and slows them.",
	"yijiazhishi":"Several auras that drive towers around crazy.",
	"tianranzumulv":"Steals 3 abilities from towers around."}

var content: GridContainer
# Compact mode: one column per HBox child, each holding whole upgrade-line groups.
var chains: HBoxContainer
var tower_header: HBoxContainer
var trap_panel: PanelContainer
var trap_list: VBoxContainer
var detail_panel: PanelContainer
var detail_title: Label
var detail_kind: Label
var detail_text: Label
var detail_status: Label
var detail_ingredient: Label
var scroll: ScrollContainer
var track_buttons: Dictionary = {}
var find_buttons: Dictionary = {}
var locate_cursor: Dictionary = {}
var search: LineEdit
var summary: Label
var bound_state: GemRun
var bound_tracking = ""
var built_width = 0

func _ready() -> void:
	title = "Recipe book"
	# The window is sized to the screen; content adapts to it, never the other way round.
	wrap_controls = false
	min_size = Vector2i(680,540)
	get_ok_button().text = "Close"
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_bottom = -48
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margin.add_child(layout)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation",16)
	layout.add_child(top)
	search = LineEdit.new()
	search.placeholder_text = "Search tower, ingredient or recipe family..."
	search.custom_minimum_size.x = 320
	search.text_changed.connect(func(_text): rebuild_cards())
	top.add_child(search)
	# Grade legend sits in the top row so the recipe columns get the full height.
	tower_header = HBoxContainer.new()
	tower_header.add_theme_constant_override("separation",10)
	tower_header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tower_header)
	section_title(tower_header,"TOWER RECIPES",Color("e8c46a"))
	for key in ["basic","intermediate","advanced","top"]:
		legend_dot(tower_header,GRADES[key][0],Color(GRADES[key][1]))
	summary = Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary.add_theme_font_size_override("font_size",13)
	summary.add_theme_color_override("font_color",Color("8e9aa3"))
	top.add_child(summary)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var columns = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",14)
	scroll.add_child(columns)
	var towers = VBoxContainer.new()
	towers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	towers.add_theme_constant_override("separation",6)
	columns.add_child(towers)
	content = GridContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("h_separation",8)
	content.add_theme_constant_override("v_separation",6)
	towers.add_child(content)
	chains = HBoxContainer.new()
	chains.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chains.add_theme_constant_override("separation",8)
	towers.add_child(chains)
	# Traps (path pedals) are a different kind of build: their own column, like Dota's pedal list.
	trap_panel = PanelContainer.new()
	var trap_style = StyleBoxFlat.new()
	trap_style.bg_color = Color("1a1712")
	trap_style.border_color = Color("6e5430")
	trap_style.set_border_width_all(1)
	trap_style.border_width_top = 3
	trap_style.set_corner_radius_all(8)
	trap_style.content_margin_left = 10
	trap_style.content_margin_right = 10
	trap_style.content_margin_top = 8
	trap_style.content_margin_bottom = 10
	trap_panel.add_theme_stylebox_override("panel",trap_style)
	trap_panel.custom_minimum_size.x = TRAP_WIDTH
	trap_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var side = VBoxContainer.new()
	side.add_theme_constant_override("separation",10)
	side.custom_minimum_size.x = TRAP_WIDTH
	columns.add_child(side)
	side.add_child(trap_panel)
	detail_panel = PanelContainer.new()
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color("18222b")
	detail_style.border_color = Color("33414d")
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(8)
	detail_style.content_margin_left = 12
	detail_style.content_margin_right = 12
	detail_style.content_margin_top = 10
	detail_style.content_margin_bottom = 12
	detail_panel.add_theme_stylebox_override("panel",detail_style)
	side.add_child(detail_panel)
	var detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation",6)
	detail_panel.add_child(detail_box)
	detail_title = section_title(detail_box,"",Color("e8c46a"))
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title.custom_minimum_size.x = TRAP_WIDTH-26
	detail_kind = text_label(detail_box,"",12)
	# Named while the pointer is on an ingredient chip, so a gem icon is never the only clue.
	detail_ingredient = text_label(detail_box,"",14)
	detail_ingredient.add_theme_color_override("font_color",GemArt.color("ui_accent"))
	detail_ingredient.visible = false
	detail_text = text_label(detail_box,"",13)
	detail_text.add_theme_color_override("font_color",Color("d9d6c8"))
	detail_text.max_lines_visible = 7
	detail_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_status = text_label(detail_box,"",12)
	detail_status.add_theme_color_override("font_color",Color("8e9aa3"))
	detail_status.max_lines_visible = 2
	show_detail("")
	var trap_box = VBoxContainer.new()
	trap_box.add_theme_constant_override("separation",6)
	trap_panel.add_child(trap_box)
	section_title(trap_box,"TRAPS · PATH PEDALS",TRAP_TINT)
	var note = text_label(trap_box,"Never block enemies · three in a row upgrade",11)
	note.add_theme_color_override("font_color",Color("a89878"))
	note.custom_minimum_size.x = TRAP_WIDTH-24
	trap_list = VBoxContainer.new()
	trap_list.add_theme_constant_override("separation",6)
	trap_box.add_child(trap_list)
	size_changed.connect(func():
		if visible and bound_state != null and absi(size.x-built_width) > 8: rebuild_cards()
	)

func clear_cards() -> void:
	track_buttons.clear()
	find_buttons.clear()
	for list in [content,chains,trap_list]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()

func reset() -> void:
	hide()
	bound_state = null
	search.text = ""
	locate_cursor.clear()
	clear_cards()

func open_for(state: GemRun, tracked: String) -> void:
	bound_state = state
	bound_tracking = tracked
	# Use the whole screen (minus the window frame) so every recipe fits without scrolling.
	var screen = (get_parent() as Control).size if get_parent() is Control else Vector2(1360,900)
	var wanted = Vector2i(int(screen.x)-24,int(screen.y)-34-24)
	var fitted = Vector2i(maxi(wanted.x,min_size.x),maxi(wanted.y,min_size.y))
	popup_centered(fitted)
	# popup_centered clamps to the physical screen size; with UI scaling the logical screen is larger.
	size = fitted
	position = Vector2i((Vector2(screen)-Vector2(fitted))/2.0)+Vector2i(0,17)
	rebuild_cards()

func rebuild_cards() -> void:
	if bound_state == null: return
	built_width = size.x
	clear_cards()
	var matches: Dictionary = {}
	for recipe in GemCatalog.recipes():
		var haystack = GemCatalog.recipe_title(recipe)+" "+str(GemCatalog.recipe(recipe).get("family",""))
		for ingredient in GemCatalog.recipe(recipe).ingredients: haystack += " "+GemCatalog.title({"kind":ingredient[0],"tier":int(ingredient[1])})
		if search.text.is_empty() or haystack.to_lower().contains(search.text.to_lower()):
			matches[recipe] = GemRecipeGuide.progress(bound_state,recipe)
	# Dota order: towers grouped by upgrade line (base -> top), secret recipes after, traps in their own column.
	var groups: Array = []
	var shown: Array = []
	for group in chain_groups():
		var entries: Array = group.recipes.filter(func(r): return matches.has(r)).map(func(r): return {"recipe":r,"progress":matches[r]})
		if not entries.is_empty():
			groups.append({"title":group.title,"color":group.color,"entries":entries})
			shown.append_array(entries)
	var traps: Array = []
	for recipe in matches:
		if is_trap(recipe): traps.append({"recipe":recipe,"progress":matches[recipe]})
	trap_panel.visible = not traps.is_empty()
	show_detail("")
	tower_header.visible = not traps.is_empty() or shown.size() > 12
	var detailed = shown.size() <= 12 and traps.is_empty()
	detail_panel.visible = not detailed
	detail_panel.get_parent().visible = not detailed or trap_panel.visible
	var width = maxf(400.0,float(size.x)-40.0-(TRAP_WIDTH+14.0 if trap_panel.visible else 0.0))
	content.visible = detailed
	chains.visible = not detailed
	var ready = 0
	if detailed:
		content.columns = clampi(int(width/(CARD_MIN_WIDTH+8.0)),1,3)
		for entry in shown:
			if entry.progress.complete: ready += 1
			add_recipe(entry.recipe,entry.progress,true,content)
	else:
		# Enough columns that every row fits the window height; never narrower than readable.
		var rows_fit = maxi(1,int((float(size.y)-150.0+8.0)/(COMPACT_HEIGHT+8.0)))
		var units = float(shown.size())+float(groups.size())*GROUP_HEADER/(COMPACT_HEIGHT+8.0)
		var needed = ceili(units/float(rows_fit))
		var columns = clampi(maxi(needed,int(width/380.0)),1,maxi(1,int(width/(ROW_MIN_WIDTH+8.0))))
		# Lines are never split. Largest first into the emptiest column, then each column keeps
		# the original line order, so the columns end up level and fit the window.
		var fill: Array = []
		var picks: Array = []
		for i in range(columns):
			fill.append(0.0)
			picks.append([])
		var by_size = range(groups.size())
		by_size.sort_custom(func(a,b): return groups[a].entries.size() > groups[b].entries.size() if groups[a].entries.size() != groups[b].entries.size() else a < b)
		for index in by_size:
			var target = fill.find(fill.min())
			fill[target] += float(groups[index].entries.size())+GROUP_HEADER/(COMPACT_HEIGHT+8.0)
			picks[target].append(index)
		for pick in picks: pick.sort()
		picks.sort_custom(func(a,b): return a.size() > 0 and (b.is_empty() or a[0] < b[0]))
		for pick in picks:
			if pick.is_empty():
				continue
			var column = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_theme_constant_override("separation",3)
			chains.add_child(column)
			for index in pick:
				var group: Dictionary = groups[index]
				var title = section_title(column,group.title,group.color)
				title.add_theme_font_size_override("font_size",11)
				for entry in group.entries:
					if entry.progress.complete: ready += 1
					add_recipe(entry.recipe,entry.progress,false,column)
	for entry in traps:
		if entry.progress.complete: ready += 1
		add_recipe(entry.recipe,entry.progress,false,trap_list)
	shown.append_array(traps)
	summary.text = "%d recipes · %d ready now · click an ingredient to find it on the board, the pin to track a recipe" % [shown.size(),ready] if not shown.is_empty() else "No matching recipes."

func card_style(ready: bool, tracked: bool, needs_new: bool = false) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color("1d2832") if not ready else (Color("2a2817") if needs_new else Color("1c2e27"))
	box.border_color = Color("e8c46a") if tracked else ((FRESH if needs_new else READY) if ready else Color("2c3a46"))
	box.set_border_width_all(2 if ready or tracked else 1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

func summary_for(recipe: String) -> String:
	var result = GemCatalog.recipe_result(recipe)
	var source = str(GemCatalog.DATA.get("specials",{}).get(result,{}).get("source_id","")).trim_prefix("gemtd_")
	if SUMMARY.has(source): return SUMMARY[source]
	var effect = GemCampaignRules.describe({"kind":result,"tier":1}) if GemCatalog.campaign() else str(GemCatalog.stats({"kind":result,"tier":1}).effect)
	var first = effect.strip_edges().split("\n")[0].split(". ")[0].strip_edges()
	if first.length() > 90: first = first.left(88).strip_edges()+"…"
	return first+("" if first.ends_with(".") or first.ends_with("…") else ".")

func show_detail(recipe: String) -> void:
	if detail_panel == null:
		return
	detail_ingredient.visible = false
	if recipe.is_empty() or bound_state == null:
		detail_title.text = "What does it do?"
		detail_kind.text = ""
		detail_text.text = "Point at any recipe to read its full effect here. Ingredient chips: green = placed in an earlier round, yellow = only among this round's new gems, bronze = some of them, grey = missing. Click a chip to find the gem on the board."
		detail_status.text = ""
		return
	var result = GemCatalog.recipe_result(recipe)
	var data: Dictionary = GemCatalog.stats({"kind":result,"tier":1})
	var grade = grade_of(recipe)
	var kind_text = "Trap · path pedal" if is_trap(recipe) else (GRADES[grade][0]+" combined tower" if not grade.is_empty() else "Combined tower")
	if str(GemCatalog.recipe(recipe).get("family","")) == "secret": kind_text += " · secret recipe"
	detail_title.text = str(data.name)
	detail_kind.text = kind_text
	detail_kind.add_theme_color_override("font_color",TRAP_TINT if is_trap(recipe) else (Color(GRADES[grade][1]) if not grade.is_empty() else Color("8e9aa3")))
	var effect = GemCampaignRules.describe({"kind":result,"tier":1}) if GemCatalog.campaign() else str(data.effect)
	var stats = ""
	if not is_trap(recipe) and float(data.get("damage",0)) > 0:
		stats = "\n\n%.0f damage · %.2fs / attack · range %.1f · %s" % [float(data.damage),float(data.interval),float(data.range),"ground + air" if str(data.get("targets","")) == "both" else "ground only"]
	var trap_rules = "\n\nTraps consume their gems and open the material cell. They never block enemies, trigger within one cell (10s cooldown), and three equal traps in a straight line upgrade at the centre." if is_trap(recipe) else ""
	detail_text.text = summary_for(recipe)+"\n\n"+effect+stats+trap_rules
	var parts: PackedStringArray = []
	for ingredient in GemCatalog.recipe(recipe).ingredients:
		parts.append(GemCatalog.title({"kind":ingredient[0],"tier":int(ingredient[1])}))
	detail_status.text = "Needs: "+", ".join(parts)+"\n"+str(GemRecipeGuide.progress(bound_state,recipe).message)

func show_ingredient(recipe: String, group: Dictionary) -> void:
	show_detail(recipe)
	if detail_panel == null or bound_state == null:
		return
	var have = group.owned.size()
	var source = " (missing)"
	if have > 0:
		source = " (earlier rounds)" if int(group.older) >= int(group.needed) else (" (new this round)" if int(group.older) == 0 else " (%d earlier, %d new)" % [int(group.older),int(group["new"])])
	detail_ingredient.text = "Ingredient: %s — have %d / %d%s" % [GemCatalog.title({"kind":group.kind,"tier":int(group.tier)}),have,int(group.needed),source]
	detail_ingredient.visible = true

# Upgrade lines from the recipe tree (Dota's _G.gemtd_merge): each top tower with every combined
# tower that feeds it, base first. Side towers join the line of a tower they are built from.
static func chain_groups() -> Array:
	var standard: Array = []
	var home: Array = []
	var mixed: Array = []
	for recipe in GemCatalog.recipes():
		if is_trap(recipe):
			continue
		if str(GemCatalog.recipe(recipe).get("family","")) != "secret":
			standard.append(recipe)
			continue
		var kinds = {}
		for ingredient in GemCatalog.recipe(recipe).ingredients: kinds[str(ingredient[0])] = true
		(home if kinds.size() == 1 else mixed).append(recipe)
	var by_result = {}
	for recipe in standard: by_result[GemCatalog.recipe_result(recipe)] = recipe
	var parts = {}
	var used = {}
	for recipe in standard:
		parts[recipe] = []
		for ingredient in GemCatalog.recipe(recipe).ingredients:
			if by_result.has(str(ingredient[0])):
				parts[recipe].append(by_result[str(ingredient[0])])
				used[by_result[str(ingredient[0])]] = true
	var depth = {}
	for recipe in standard: depth[recipe] = 0
	for _pass in range(standard.size()):
		for recipe in standard:
			for part in parts[recipe]: depth[recipe] = maxi(int(depth[recipe]),int(depth[part])+1)
	var roots = standard.filter(func(r): return not used.has(r))
	# Lines start at the Top-grade towers (Dota help texts); without any, every final tower starts one.
	var has_top = roots.any(func(r): return grade_of(r) == "top")
	var lines: Array = []
	var line_of = {}
	var pending: Array = []
	for root in roots:
		if grade_of(root) == "top" or not has_top: claim(root,lines.size(),parts,line_of,true,lines)
		else: pending.append(root)
	while not pending.is_empty():
		var attached = false
		for root in pending.duplicate():
			var line = -1
			for recipe in feeders(root,parts):
				if line_of.has(recipe):
					line = int(line_of[recipe])
					break
			if line >= 0:
				claim(root,line,parts,line_of,false,lines)
				pending.erase(root)
				attached = true
		if not attached:
			claim(pending.pop_front(),lines.size(),parts,line_of,true,lines)
	var groups: Array = []
	for line in lines:
		var members: Array = line.recipes
		members.sort_custom(func(a,b): return int(depth[a]) < int(depth[b]) if depth[a] != depth[b] else standard.find(a) < standard.find(b))
		var grade = grade_of(line.root)
		groups.append({"title":str(GemCatalog.stats({"kind":GemCatalog.recipe_result(line.root),"tier":1}).name).to_upper()+(" LINE" if members.size() > 1 else ""),
			"color":Color(GRADES[grade][1]) if not grade.is_empty() else Color("e8c46a"),"recipes":members})
	if not home.is_empty(): groups.append({"title":"SECRET · ONE GEM, FIVE QUALITIES","color":Color(GRADES.top[1]),"recipes":home})
	if not mixed.is_empty(): groups.append({"title":"SECRET · OTHERS","color":Color(GRADES.top[1]),"recipes":mixed})
	return groups

# The recipe and every combined tower it is built from, nearest first.
static func feeders(recipe: String, parts: Dictionary) -> Array:
	var result: Array = [recipe]
	var index = 0
	while index < result.size():
		for part in parts[result[index]]:
			if not result.has(part): result.append(part)
		index += 1
	return result

static func claim(root: String, line: int, parts: Dictionary, line_of: Dictionary, new_line: bool, lines: Array) -> void:
	if new_line: lines.append({"root":root,"recipes":[]})
	for recipe in feeders(root,parts):
		if not line_of.has(recipe):
			line_of[recipe] = line
			lines[line].recipes.append(recipe)

static func is_trap(recipe: String) -> bool:
	var result = GemCatalog.recipe_result(recipe)
	return str(GemCatalog.recipe(recipe).get("family","")) == "slab" or bool(GemCatalog.DATA.get("specials",{}).get(result,{}).get("slab",false))

static func grade_of(recipe: String) -> String:
	var result = GemCatalog.recipe_result(recipe)
	var source = str(GemCatalog.DATA.get("specials",{}).get(result,{}).get("source_id","")).trim_prefix("gemtd_")
	if GRADE_OF.has(source): return GRADE_OF[source]
	return "top" if str(GemCatalog.recipe(recipe).get("family","")) == "secret" else ""

func section_title(parent: Node, text: String, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "SectionLabel"
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func legend_dot(parent: Node, text: String, color: Color) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	var dot = ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(4,12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var label = text_label(row,text,11)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color",color)

func add_recipe(recipe: String, progress: Dictionary, detailed: bool, parent: Node) -> void:
	var result = GemCatalog.recipe_result(recipe)
	var data: Dictionary = GemCatalog.stats({"kind":result,"tier":1})
	var effect = GemCampaignRules.describe({"kind":result,"tier":1}) if GemCatalog.campaign() else str(data.effect)
	var family = str(GemCatalog.recipe(recipe).get("family",""))
	var grade = grade_of(recipe)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",card_style(bool(progress.complete),bound_tracking == recipe,bool(progress.complete) and not bool(progress.old_only)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = CARD_MIN_WIDTH if detailed else 0.0
	var kind_text = "Trap (path pedal)" if is_trap(recipe) else (GRADES[grade][0]+" combined tower" if not grade.is_empty() else "")
	if family == "secret": kind_text += " · secret recipe"
	panel.tooltip_text = "%s%s\n\n%s\n\n%s" % [data.name," · "+kind_text if not kind_text.is_empty() else "",effect,progress.message]
	parent.add_child(panel)
	panel.mouse_entered.connect(func(): show_detail(recipe))
	var outer = HBoxContainer.new()
	outer.add_theme_constant_override("separation",7)
	panel.add_child(outer)
	if parent == trap_list or not grade.is_empty():
		var stripe = ColorRect.new()
		stripe.color = TRAP_TINT if parent == trap_list else Color(GRADES[grade][1])
		stripe.custom_minimum_size.x = 3
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(stripe)
	var count_text = "Ready" if progress.complete else "%d/%d" % [progress.collected,progress.total]
	var count_color = (READY if progress.old_only else FRESH) if progress.complete else Color("8e9aa3")
	var track = Button.new()
	track.theme_type_variation = "ToolButton"
	track.icon = pin_icon(bound_tracking == recipe)
	track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	track.tooltip_text = "Highlight this recipe's ingredients on the board."
	track.pressed.connect(func(): track_requested.emit(recipe))
	track_buttons[recipe] = track
	find_buttons[recipe] = []
	if not detailed:
		# One line: [grade] [icon] [name ........] [ingredients] [count] [pin]
		portrait(outer,GemArt.sprite_id("gems",result),Vector2(26,30))
		var texts = VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation",-3)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(texts)
		var top = HBoxContainer.new()
		top.add_theme_constant_override("separation",6)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(top)
		var name_label = text_label(top,data.name,13)
		name_label.add_theme_color_override("font_color",GemArt.color("ui_accent"))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 44
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var line = text_label(texts,summary_for(recipe),11)
		line.add_theme_color_override("font_color",Color("9aa5ad"))
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.clip_text = true
		line.custom_minimum_size.x = 40
		var chips = HBoxContainer.new()
		chips.add_theme_constant_override("separation",3)
		chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(chips)
		for group in progress.groups:
			chips.add_child(ingredient_button(recipe,group,false))
		var count = text_label(top,count_text,11)
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.custom_minimum_size.x = 26
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_color",count_color)
		track.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		track.custom_minimum_size = Vector2(20,18)
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(track)
		texts.move_child(line,1)
		return
	portrait(outer,GemArt.sprite_id("gems",result),Vector2(56,60))
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",6)
	outer.add_child(box)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation",6)
	box.add_child(header)
	var names = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation",-2)
	header.add_child(names)
	var title_label = text_label(names,data.name,22)
	title_label.add_theme_color_override("font_color",GemArt.color("ui_accent"))
	var sub = text_label(names,("Ready" if progress.complete else "%d / %d found" % [progress.collected,progress.total])+(" · "+kind_text if not kind_text.is_empty() else ""),13)
	sub.add_theme_color_override("font_color",count_color)
	track.text = "Tracking" if bound_tracking == recipe else "Track on board"
	track.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(track)
	var description = text_label(box,effect,14)
	description.add_theme_color_override("font_color",Color("c6cabd"))
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation",4)
	row.add_theme_constant_override("v_separation",4)
	box.add_child(row)
	for group in progress.groups:
		row.add_child(ingredient_button(recipe,group,true))
	var message = text_label(box,progress.message,13)
	message.add_theme_color_override("font_color",Color("8e9aa3"))

func ingredient_button(recipe: String, group: Dictionary, detailed: bool) -> Button:
	var have = group.owned.size()
	var find = Button.new()
	find.focus_mode = Control.FOCUS_NONE
	find.icon = GemArt.texture(GemArt.sprite_id("gems",group.kind,int(group.tier)))
	find.add_theme_constant_override("icon_max_width",17 if not detailed else 32)
	find.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	find.text = (GemCatalog.title({"kind":group.kind,"tier":int(group.tier)})+"  %d/%d" % [have,int(group.needed)]) if detailed else ""
	if not detailed:
		# Compact chip: gem icon with its quality numeral in the corner.
		find.custom_minimum_size = Vector2(24,22)
		find.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		find.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var numeral = Label.new()
		numeral.text = GemCatalog.quality_name(int(group.tier))+("×%d" % int(group.needed) if int(group.needed) > 1 else "")
		numeral.add_theme_font_size_override("font_size",9)
		numeral.add_theme_color_override("font_color",Color("f2ead2") if have >= int(group.needed) else Color("b9c0c6"))
		numeral.add_theme_color_override("font_outline_color",Color("0b1015"))
		numeral.add_theme_constant_override("outline_size",3)
		numeral.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		numeral.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		numeral.grow_vertical = Control.GROW_DIRECTION_BEGIN
		numeral.offset_right = -1
		numeral.offset_bottom = 2
		numeral.mouse_filter = Control.MOUSE_FILTER_IGNORE
		find.add_child(numeral)
	find.add_theme_font_size_override("font_size",10 if not detailed else 13)
	var ok = have >= int(group.needed)
	# Green: enough from earlier rounds. Yellow: only reachable with this round's new gems.
	var older = int(group.older) >= int(group.needed)
	var style = StyleBoxFlat.new()
	style.bg_color = (Color("13201b") if older else Color("272412")) if ok else Color("141b22")
	style.border_color = (READY if older else FRESH) if ok else (PARTIAL if have > 0 else MISSING)
	style.set_border_width_all(2 if ok else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 1
	style.content_margin_right = 3
	for state in ["normal","hover","pressed","disabled","focus"]:
		find.add_theme_stylebox_override(state,style)
	find.add_theme_constant_override("h_separation",2)
	find.add_theme_color_override("font_color",Color("d9d6c8") if ok else Color("8e9aa3"))
	find.add_theme_color_override("font_disabled_color",Color("5d6a73"))
	find.disabled = group.owned.is_empty()
	find.modulate = Color(1,1,1,1) if have > 0 else Color(1,1,1,.55)
	find.tooltip_text = "%s · have %d / %d (%d kept, %d new)\n%s" % [GemCatalog.title({"kind":group.kind,"tier":int(group.tier)}),have,int(group.needed),group.older,group["new"],"Click to cycle through matching gems on the board, kept gems first." if have > 0 else "Missing ingredient — must match the exact quality."]
	find.mouse_entered.connect(func(): show_ingredient(recipe,group))
	find.mouse_exited.connect(func(): show_detail(recipe))
	find.pressed.connect(func():
		if group.owned.is_empty():
			return
		var key = recipe+"/"+str(group.key)
		var index = int(locate_cursor.get(key,0))%group.owned.size()
		locate_cursor[key] = index+1
		locate_requested.emit(group.owned[index])
	)
	find_buttons[recipe].append(find)
	return find

func pin_icon(active: bool) -> ImageTexture:
	var rows = [".xxx.","xxxxx",".xxx.","..x..","..x.."]
	var color = Color("e8c46a") if active else Color("8e9aa3")
	var img = Image.create(10,10,false,Image.FORMAT_RGBA8)
	for y in range(5):
		for x in range(5):
			if rows[y][x] == "x":
				img.fill_rect(Rect2i(x*2,y*2,2,2),color)
	return ImageTexture.create_from_image(img)

func portrait(parent: Node, id: String, minimum: Vector2) -> void:
	var image = TextureRect.new()
	image.texture = GemArt.texture(id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.custom_minimum_size = minimum
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func text_label(parent: Node, text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
