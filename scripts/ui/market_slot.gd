class_name MarketSlotUI extends Control

@onready var content_slot_ui: ContentSlotUI = $VBoxContainer/item;
@onready var line_edit: LineEdit = $VBoxContainer/PriceRow/price;
@onready var list_item_button: Button = $VBoxContainer/ActionButton;

var trade_mode: MarketUI.TradeMode = MarketUI.TradeMode.BUY;
var destination_inventory: ContentGroup;
var item_price: int = 0;
var sale_chance: float = 0;

var text_cache: String;
var _is_listed: bool = false;

var sell_item: bool:
	set(value):
		_is_listed = value;
		list_item_button.button_pressed = value;
	get:
		return _is_listed;

func get_slot() -> ContentSlotUI:
	return content_slot_ui;
	
func _ready() -> void:
	content_slot_ui.show_amount = true;
	line_edit.text_submitted.connect(_on_set_price);
	line_edit.text_changed.connect(_validate_line_edit);
	text_cache = str(item_price);
	
	line_edit.focus_exited.connect(_on_set_price);
	
	if Manager.instance and Manager.instance.market:
		Manager.instance.market.tick.connect(_try_sell);
	
	list_item_button.button_pressed = false;
	list_item_button.pressed.connect(_on_list_btn_pressed);
	_update_mode_ui();

func configure(mode: MarketUI.TradeMode, target_inventory: ContentGroup = null) -> void:
	trade_mode = mode;
	destination_inventory = target_inventory;
	if content_slot_ui.contentSlot and not content_slot_ui.contentSlot.changed.is_connected(_on_content_changed):
		content_slot_ui.contentSlot.changed.connect(_on_content_changed);
	_update_mode_ui();
	
func _on_list_btn_pressed() -> void:
	if trade_mode == MarketUI.TradeMode.BUY:
		_buy_one();
	else:
		_on_set_price();
		sell_item = list_item_button.button_pressed and item_price > 0;

func _on_set_price(s: String = line_edit.text) -> void:
	if trade_mode != MarketUI.TradeMode.SELL:
		return;
	if not content_slot_ui.contentSlot or not content_slot_ui.contentSlot.get_content():
		return;
	
	if s.is_empty():
		item_price = 0;
		sale_chance = 0;
		sell_item = false;
		return;

	item_price = int(s);
	var base_price: int = _get_unit_price();
	sale_chance = Manager.instance.market.calculate_sell_chance(base_price, maxi(1, item_price));
	
func _try_sell() -> void:
	if trade_mode == MarketUI.TradeMode.SELL && sell_item && item_price > 0 && not content_slot_ui.contentSlot.has_content(null):
		if randf() <= sale_chance:
			_resolve_sale();
			
func _resolve_sale() -> void:
	Manager.instance.player_instance.currency += item_price * content_slot_ui.contentSlot.count;
	content_slot_ui.contentSlot.remove(content_slot_ui.contentSlot.count);
	line_edit.text = "";
	sell_item = false;
	item_price = 0;
	
func _validate_line_edit(s: String) -> void:
	if trade_mode == MarketUI.TradeMode.BUY:
		return;
	if s.is_empty() or s.is_valid_int():
		text_cache = s;
		_on_set_price(s);
	else:
		var caret := line_edit.caret_column;
		line_edit.text = text_cache;
		line_edit.caret_column = caret;

func _buy_one() -> void:
	if not destination_inventory or not content_slot_ui.contentSlot:
		return;
	var content := content_slot_ui.contentSlot.get_content();
	if content == null or content_slot_ui.contentSlot.count <= 0:
		return;
	var price := _get_unit_price();
	if Manager.instance.player_instance.currency < price:
		return;
	var remaining := destination_inventory.add(content, 1);
	if remaining > 0:
		return;
	Manager.instance.player_instance.currency -= price;
	content_slot_ui.contentSlot.remove(1);
	_update_mode_ui();

func _on_content_changed() -> void:
	if trade_mode == MarketUI.TradeMode.BUY:
		_update_buy_price();
		return;
	if not content_slot_ui.contentSlot or content_slot_ui.contentSlot.has_content(null):
		sell_item = false;
		list_item_button.disabled = true;
		return;
	list_item_button.disabled = false;
	if item_price > 0:
		_on_set_price();

func _update_mode_ui() -> void:
	if not is_node_ready():
		return;
	content_slot_ui.show_amount = true;
	sell_item = false;
	item_price = 0;
	line_edit.editable = trade_mode == MarketUI.TradeMode.SELL;
	line_edit.selecting_enabled = trade_mode == MarketUI.TradeMode.SELL;
	list_item_button.toggle_mode = trade_mode == MarketUI.TradeMode.SELL;
	if trade_mode == MarketUI.TradeMode.BUY:
		list_item_button.text = "Buy"
		line_edit.placeholder_text = ""
		list_item_button.tooltip_text = "Buy one item"
		_update_buy_price();
	else:
		list_item_button.text = "List"
		line_edit.placeholder_text = "0"
		list_item_button.tooltip_text = "List this shop slot for sale"
		line_edit.text = "";
		text_cache = "";
		list_item_button.disabled = content_slot_ui.contentSlot == null or content_slot_ui.contentSlot.has_content(null);

func _update_buy_price() -> void:
	if not is_node_ready():
		return;
	item_price = _get_unit_price();
	line_edit.text = str(item_price) if item_price > 0 else "";
	text_cache = line_edit.text;
	list_item_button.disabled = item_price <= 0 or content_slot_ui.contentSlot == null or content_slot_ui.contentSlot.has_content(null);

func _get_unit_price() -> int:
	if not content_slot_ui.contentSlot:
		return 0;
	var content := content_slot_ui.contentSlot.get_content();
	if content == null:
		return 0;
	if not ("base_value" in content):
		return 1;
	return maxi(1, content.base_value);
