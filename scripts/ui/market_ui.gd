class_name MarketUI extends InventoryUI

enum TradeMode { BUY, SELL }

@export var buy_tab_button_path: NodePath
@export var sell_tab_button_path: NodePath

var buy_inventory: ContentGroup
var sell_inventory: ContentGroup
var player_inventory: ContentGroup
var trade_mode: TradeMode = TradeMode.SELL

@onready var buy_tab_button: Button = get_node_or_null(buy_tab_button_path)
@onready var sell_tab_button: Button = get_node_or_null(sell_tab_button_path)

func _ready() -> void:
	_connect_tabs()
	_set_trade_mode(trade_mode)

func setup(_buy_inventory: ContentGroup, _sell_inventory: ContentGroup, _player_inventory: ContentGroup) -> void:
	buy_inventory = _buy_inventory
	sell_inventory = _sell_inventory
	player_inventory = _player_inventory
	_set_trade_mode(TradeMode.SELL)

func add(content: ContentSlotResource) -> ContentSlotUI:
	var market_slot: MarketSlotUI = packed_slot.instantiate();
	grid.add_child(market_slot)
	
	var container := market_slot.content_slot_ui;
	container.button_up.connect(_set_selected.bind(container))
	container.set_content(content)
	var target_inventory := player_inventory if trade_mode == TradeMode.BUY else null
	market_slot.configure(trade_mode, target_inventory)

	market_slot.size_flags_horizontal = Control.SIZE_FILL
	market_slot.size_flags_vertical = Control.SIZE_FILL
	market_slot.custom_minimum_size = Vector2(slot_size + 12, slot_size + 70)
	return container

func _connect_tabs() -> void:
	if buy_tab_button:
		buy_tab_button.toggle_mode = true
		buy_tab_button.pressed.connect(_set_trade_mode.bind(TradeMode.BUY))
	if sell_tab_button:
		sell_tab_button.toggle_mode = true
		sell_tab_button.pressed.connect(_set_trade_mode.bind(TradeMode.SELL))

func _set_trade_mode(mode: TradeMode) -> void:
	trade_mode = mode
	inventory = buy_inventory if trade_mode == TradeMode.BUY else sell_inventory
	_update_tabs()

func _update_tabs() -> void:
	if buy_tab_button:
		buy_tab_button.button_pressed = trade_mode == TradeMode.BUY
	if sell_tab_button:
		sell_tab_button.button_pressed = trade_mode == TradeMode.SELL
