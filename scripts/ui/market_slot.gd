class_name MarketSlotUI extends Control

@onready var content_slot_ui: ContentSlotUI = $"item";
@onready var spin_box: SpinBox = $SpinBox
var line_edit: LineEdit;

var item_price: int = 0;
var text_cache: String;

func get_slot() -> ContentSlotUI:
	return content_slot_ui;
	
func _ready() -> void:
	content_slot_ui.show_amount = false;
	line_edit = spin_box.get_line_edit();
	line_edit.text_submitted.connect(_on_set_price)
	line_edit.text_changed.connect(_validate_spinbox)
	text_cache = str(item_price);

func _on_set_price(s: String) -> void:
	item_price = int(s)
	
func _validate_spinbox(s: String) -> void:
	if s.is_empty() or s.is_valid_int():
		line_edit.text = s
		text_cache = s;
	else:
		line_edit.text = text_cache
