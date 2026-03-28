class_name MarketSlotUI extends Control

@onready var content_slot_ui: ContentSlotUI = $"item";
@onready var line_edit: LineEdit = $item/NinePatchRect/price;
@onready var list_item_button: Button = $item/MarginContainer/ListItem

var item_price: int = 0;
var sale_chance: float = 0;

var text_cache: String;

var sell_item: bool:
	set(value):
		sell_item = value;
		list_item_button.self_modulate = Color.YELLOW if sell_item else Color.WHITE;
		list_item_button.button_pressed = value;

func get_slot() -> ContentSlotUI:
	return content_slot_ui;
	
func _ready() -> void:
	content_slot_ui.show_amount = false;
	line_edit.text_submitted.connect(_on_set_price)
	line_edit.text_changed.connect(_validate_line_edit)
	text_cache = str(item_price);
	
	line_edit.focus_exited.connect(_on_set_price);
	
	Manager.instance.market.tick.connect(_try_sell)
	
	list_item_button.button_pressed = false;
	list_item_button.pressed.connect(_on_list_btn_pressed)
	
func _on_list_btn_pressed() -> void:
	sell_item = list_item_button.button_pressed;

func _on_set_price(s: String = line_edit.text) -> void:
	if not content_slot_ui.contentSlot.get_content():
		return
	
	item_price = int(s);
	var base_price: int = content_slot_ui.contentSlot.get_content().base_value;
	sale_chance = Manager.instance.market.calculate_sell_chance(base_price, maxi(1, item_price))
	
func _try_sell() -> void:
	if list_item_button.button_pressed && not content_slot_ui.contentSlot.has_content(null):
		if randf() > sale_chance:
			_resolve_sale();
			
func _resolve_sale() -> void:
	Manager.instance.player_instance.currency += item_price * content_slot_ui.contentSlot.count;
	content_slot_ui.contentSlot.remove(content_slot_ui.contentSlot.count)
	line_edit.text = "";
	sell_item = false;
	item_price = 0;
	
func _validate_line_edit(s: String) -> void:
	if s.is_empty() or s.is_valid_int():
		text_cache = s
	else:
		var caret := line_edit.caret_column
		line_edit.text = text_cache
		line_edit.caret_column = caret
