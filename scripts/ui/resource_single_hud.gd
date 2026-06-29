class_name ResourceSingleHud extends HBoxContainer

@onready var _icon: TextureRect = $TextureRect
@onready var _count_label: Label = $Label

var item_info: ItemInfo

func _ready() -> void:
	if item_info != null:
		_icon.texture = item_info.texture
		tooltip_text = item_info.get_display_name()
	_count_label.text = "0"

func setup(item: ItemInfo) -> void:
	item_info = item
	if is_node_ready():
		_icon.texture = item_info.texture
		tooltip_text = item_info.get_display_name()
		_count_label.text = "0"

func set_count(value: int) -> void:
	_count_label.text = str(value)
