class_name MarketSlotUI extends Control

@onready var content_slot_ui: ContentSlotUI = $"item";
@onready var spin_box: SpinBox = $SpinBox
@onready var btn_set_price: Button = $Button

var line_edit: LineEdit;

var item_price: int = 0;
var sale_chance: float = 0;

var text_cache: String;

func get_slot() -> ContentSlotUI:
	return content_slot_ui;
	
func _ready() -> void:
	content_slot_ui.show_amount = false;
	line_edit = spin_box.get_line_edit();
	line_edit.text_submitted.connect(_on_set_price)
	line_edit.text_changed.connect(_validate_spinbox)
	text_cache = str(item_price);
	
	content_slot_ui.initialized.connect(_slot_ready)
	btn_set_price.pressed.connect(_on_set_price)
	Manager.instance.market_tick.connect(_try_sell)
	
func _slot_ready() -> void:
	content_slot_ui.contentSlot.value_changed.connect(_set_button_state)
	_set_button_state();
	
func _set_button_state() -> void:
	btn_set_price.disabled = content_slot_ui.contentSlot.has_content(null)

func _on_set_price(s: String = line_edit.text) -> void:
	var base_price: int = content_slot_ui.contentSlot.get_content().base_value;
	item_price = maxi(1, int(s))
	
	sale_chance = Manager.instance.base_sale_chance * (base_price / float(item_price));
	sale_chance = clampf(sale_chance, Manager.instance.min_sale_chance, Manager.instance.max_sale_chance);
	
func _try_sell() -> void:
	if item_price != 0 && not content_slot_ui.contentSlot.has_content(null):
		var sold = randf() > sale_chance;
		if sold:
			var currency := DataManager.instance.get_item_by_name("currency");
			Manager.instance.player_instance.inventory.add(currency, item_price * content_slot_ui.contentSlot.count)
			Debug.message("%s was sold for %s %s." % [content_slot_ui.contentSlot.get_content().unique_id, item_price * content_slot_ui.contentSlot.count, currency.unique_id])
			_disable_slot();
			
func _disable_slot() -> void:
	item_price = 0;
	content_slot_ui.contentSlot.remove(content_slot_ui.contentSlot.count)
	
func _on_sale_completed() -> void:
	pass
	
func _validate_spinbox(s: String) -> void:
	if s.is_empty() or s.is_valid_int():
		text_cache = s
	else:
		var caret := line_edit.caret_column
		line_edit.text = text_cache
		line_edit.caret_column = caret
