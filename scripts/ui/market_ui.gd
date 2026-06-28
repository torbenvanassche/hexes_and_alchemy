class_name MarketUI
extends VBoxContainer

enum TradeMode { BUY, SELL }

@export var buy_tab_button_path: NodePath
@export var sell_tab_button_path: NodePath
@export var item_grid_path: NodePath
@export var currency_label_path: NodePath
@export var empty_label_path: NodePath
@export var market_tile_scene: PackedScene
@export var window_min_size: Vector2 = Vector2(760, 460)
@export var window_max_size: Vector2 = Vector2(980, 640)

var buy_inventory: ContentGroup
var sell_inventory: ContentGroup
var player_inventory: ContentGroup
var trade_mode: TradeMode = TradeMode.SELL

@onready var buy_tab_button: Button = get_node_or_null(buy_tab_button_path)
@onready var sell_tab_button: Button = get_node_or_null(sell_tab_button_path)
@onready var item_grid: GridContainer = get_node_or_null(item_grid_path)
@onready var currency_label: Label = get_node_or_null(currency_label_path)
@onready var empty_label: Label = get_node_or_null(empty_label_path)

func _ready() -> void:
	_connect_tabs()
	_connect_market_signals()
	_set_trade_mode(trade_mode)

func setup(_buy_inventory: ContentGroup, _sell_inventory: ContentGroup, _player_inventory: ContentGroup) -> void:
	buy_inventory = _buy_inventory
	sell_inventory = _sell_inventory
	player_inventory = _player_inventory
	_connect_inventory_signals()
	_set_trade_mode(TradeMode.SELL)

func on_enter() -> void:
	_apply_window_limits()
	call_deferred("_rebuild_market")

func _connect_tabs() -> void:
	if buy_tab_button:
		buy_tab_button.toggle_mode = true
		buy_tab_button.pressed.connect(_set_trade_mode.bind(TradeMode.BUY))
	if sell_tab_button:
		sell_tab_button.toggle_mode = true
		sell_tab_button.pressed.connect(_set_trade_mode.bind(TradeMode.SELL))

func _connect_market_signals() -> void:
	if Manager.instance and Manager.instance.player_instance and not Manager.instance.player_instance.currency_amount_changed.is_connected(_update_currency):
		Manager.instance.player_instance.currency_amount_changed.connect(_update_currency)

func _connect_inventory_signals() -> void:
	for inventory in [buy_inventory, sell_inventory, player_inventory]:
		if inventory and not inventory.changed.is_connected(_rebuild_market):
			inventory.changed.connect(_rebuild_market)

func _apply_window_limits() -> void:
	var node := get_parent()
	while node != null and not (node is DraggableControl):
		node = node.get_parent()
	if node is DraggableControl:
		var window := node as DraggableControl
		window.custom_maximum_size = window_max_size
		window.custom_minimum_size = window_min_size

func _set_trade_mode(mode: TradeMode) -> void:
	trade_mode = mode
	_update_tabs()
	_rebuild_market()

func _update_tabs() -> void:
	if buy_tab_button:
		buy_tab_button.button_pressed = trade_mode == TradeMode.BUY
	if sell_tab_button:
		sell_tab_button.button_pressed = trade_mode == TradeMode.SELL

func _update_currency() -> void:
	if currency_label and Manager.instance and Manager.instance.player_instance:
		currency_label.text = str(Manager.instance.player_instance.currency)

func _rebuild_market() -> void:
	if not is_node_ready() or item_grid == null:
		return
	_update_currency()
	_set_empty_message("")
	_clear_grid()
	if trade_mode == TradeMode.BUY:
		_build_buy_tiles()
	else:
		_build_sell_tiles()

func _build_buy_tiles() -> void:
	if buy_inventory == null:
		_set_empty_message("No market stock available.")
		return
	var visible_tiles := 0
	for slot in buy_inventory.data:
		if slot == null or not slot.is_unlocked or slot.get_content() == null or slot.count <= 0:
			continue
		var tile := _create_market_tile()
		item_grid.add_child(tile)
		tile.configure_buy(slot, player_inventory)
		visible_tiles += 1
	if visible_tiles == 0:
		_set_empty_message("The market is sold out.")

func _build_sell_tiles() -> void:
	if player_inventory == null:
		_set_empty_message("No player inventory available.")
		return
	var item_counts := _get_inventory_counts(player_inventory)
	for content in item_counts.keys():
		var tile := _create_market_tile()
		item_grid.add_child(tile)
		tile.configure_sell(content, int(item_counts[content]), player_inventory)
	if item_counts.is_empty():
		_set_empty_message("You have no items to sell.")

func _create_market_tile() -> MarketSlotUI:
	var tile := market_tile_scene.instantiate() as MarketSlotUI
	tile.action_completed.connect(_rebuild_market)
	return tile

func _clear_grid() -> void:
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()

func _set_empty_message(text: String) -> void:
	if empty_label == null:
		return
	empty_label.text = text
	empty_label.visible = not text.is_empty()

func _get_inventory_counts(inventory: ContentGroup) -> Dictionary:
	var counts := {}
	for slot in inventory.data:
		if slot == null or not slot.is_unlocked or slot.get_content() == null or slot.count <= 0:
			continue
		var content := slot.get_content()
		counts[content] = int(counts.get(content, 0)) + slot.count
	return counts
