class_name GemSeedDialog
extends ConfirmationDialog

signal seed_requested(value: int)
var input: LineEdit
var hint: Label
var content: VBoxContainer

func _ready() -> void:
	title = "Start with a seed"
	wrap_controls = false
	dialog_hide_on_ok = false
	min_size = Vector2i(440,230)
	get_ok_button().text = "Start run"
	content = VBoxContainer.new()
	add_child(content)
	var label = Label.new()
	label.text = "Start a fresh run from a reproducible seed.\nYour choices still affect the result."
	content.add_child(label)
	input = LineEdit.new()
	input.placeholder_text = "Positive whole number"
	input.max_length = 18
	input.text_changed.connect(func(_value): validate())
	input.text_submitted.connect(func(_value): submit())
	content.add_child(input)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size",12)
	content.add_child(hint)
	confirmed.connect(submit)
	size_changed.connect(func(): fit_content.call_deferred())
	content.minimum_size_changed.connect(func(): fit_content.call_deferred())

func fit_content() -> void:
	content.position = Vector2(20,20)
	content.size = Vector2(size.x-40,maxi(0,size.y-84))

func validate() -> bool:
	var value = input.text.strip_edges()
	var valid = value.is_valid_int() and value.length() <= 18 and value.to_int() > 0
	get_ok_button().disabled = not valid
	hint.text = "Use a positive whole number, up to 18 digits." if not valid else "A new run starts at wave one."
	return valid

func submit() -> void:
	if validate():
		var value = input.text.strip_edges().to_int()
		hide()
		seed_requested.emit(value)

func open_for(value: int) -> void:
	input.text = str(value)
	validate()
	popup_centered(Vector2i(470,250))
	fit_content.call_deferred()
	input.grab_focus()
	input.select_all()
