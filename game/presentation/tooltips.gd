class_name GemTooltips
extends RefCounted

# Shared themed, wrapped tooltips keep numeric comparisons inside the viewport.
static func make(text: String) -> Control:
	var panel = PanelContainer.new()
	panel.theme = load(str(GemArt.config().get("theme","res://assets/graphics/ui_theme.tres"))) as Theme
	var label = Label.new()
	label.text = text
	label.custom_minimum_size.x = 410
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",14)
	panel.add_child(label)
	return panel

class InfoButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		return GemTooltips.make(for_text)

class InfoLabel extends Label:
	func _make_custom_tooltip(for_text: String) -> Object:
		return GemTooltips.make(for_text)
