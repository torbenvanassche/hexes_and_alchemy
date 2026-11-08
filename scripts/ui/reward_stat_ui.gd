class_name RewardStatUI
extends HBoxContainer

## Compact icon, amount and caption shared by rewards and the guild treasury.
@export var icon: Texture2D
@export var label_key := ""
@export var icon_size := 28
@export var value_color := GameUI.TEXT

var _amount := 0
var _show_sign := false
var _text_value := ""

func _ready() -> void:
	$Icon.texture = icon
	$Icon.custom_minimum_size = Vector2(icon_size, icon_size)
	$Text/Caption.text = tr(label_key)
	$Text/Value.add_theme_color_override("font_color", value_color)
	_update_amount()

func set_amount(amount: int, show_sign := false) -> void:
	_text_value = ""
	_amount = amount
	_show_sign = show_sign
	if is_node_ready(): _update_amount()

func set_text_value(value: String) -> void:
	_text_value = value
	if is_node_ready(): _update_amount()

func _update_amount() -> void:
	$Text/Value.text = _text_value if not _text_value.is_empty() else ("%+d" % _amount if _show_sign else str(_amount))
