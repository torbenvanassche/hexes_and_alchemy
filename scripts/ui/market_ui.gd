class_name MarketUI
extends VBoxContainer

enum TradeMode { BUY, SELL }

@onready var buy_tab_button: Button = $TopRow/TabSelector/BuyTab
@onready var sell_tab_button: Button = $TopRow/TabSelector/SellTab
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var item_grid: GridContainer = $ScrollContainer/ItemGrid
@onready var currency_label: Label = $TopRow/CurrencyPanel/CurrencyAmount
@onready var empty_label: Label = $EmptyLabel

@export_group("Layout")
@export var market_tile_scene: PackedScene
@export var window_min_size: Vector2 = Vector2(760, 460)
@export var window_max_size: Vector2 = Vector2(980, 640)

var buy_inventory: ContentGroup
var sell_inventory: ContentGroup
var player_inventory: ContentGroup
var trade_mode: TradeMode = TradeMode.SELL
var is_setup := false
var pending_setup := false

func _ready() -> void:
	_connect_tabs()
	_connect_market_signals()
	if scroll_container != null and not scroll_container.resized.is_connected(_on_market_layout_resized):
		scroll_container.resized.connect(_on_market_layout_resized)
	_update_tabs()
	_set_empty_message("")
	if pending_setup:
		_finish_setup()

func setup(_buy_inventory: ContentGroup, _sell_inventory: ContentGroup, _player_inventory: ContentGroup) -> void:
	buy_inventory = _buy_inventory
	sell_inventory = _sell_inventory
	player_inventory = _player_inventory
	pending_setup = true
	if not is_node_ready():
		return
	_finish_setup()

func _finish_setup() -> void:
	pending_setup = false
	is_setup = true
	_connect_inventory_signals()
	_set_trade_mode(TradeMode.SELL)
	call_deferred("_rebuild_market")

func on_enter() -> void:
	_apply_window_limits()
	call_deferred("_rebuild_market")

func _connect_tabs() -> void:
	if buy_tab_button:
		buy_tab_button.toggle_mode = true
		if not buy_tab_button.pressed.is_connected(_on_buy_tab_pressed):
			buy_tab_button.pressed.connect(_on_buy_tab_pressed)
	if sell_tab_button:
		sell_tab_button.toggle_mode = true
		if not sell_tab_button.pressed.is_connected(_on_sell_tab_pressed):
			sell_tab_button.pressed.connect(_on_sell_tab_pressed)

func _on_buy_tab_pressed() -> void:
	_set_trade_mode(TradeMode.BUY)

func _on_sell_tab_pressed() -> void:
	_set_trade_mode(TradeMode.SELL)

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

func _on_market_layout_resized() -> void:
	call_deferred("_apply_tile_widths")

func _rebuild_market() -> void:
	if not is_node_ready() or item_grid == null:
		return
	_update_currency()
	_set_empty_message("")
	_clear_grid()
	if not is_setup:
		return
	if trade_mode == TradeMode.BUY:
		_build_buy_tiles()
	else:
		_build_sell_tiles()
	_apply_tile_widths()

func _build_buy_tiles() -> void:
	if buy_inventory == null:
		_set_empty_message(tr("MARKET_EMPTY_NO_STOCK"))
		return
	if market_tile_scene == null:
		_set_empty_message(tr("MARKET_EMPTY_NO_STOCK"))
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
		_set_empty_message(tr("MARKET_EMPTY_SOLD_OUT"))

func _build_sell_tiles() -> void:
	if player_inventory == null:
		_set_empty_message(tr("MARKET_EMPTY_NO_PLAYER_INVENTORY"))
		return
	if market_tile_scene == null:
		_set_empty_message(tr("MARKET_EMPTY_NO_STOCK"))
		return
	var item_counts := _get_inventory_counts(player_inventory)
	for content in item_counts.keys():
		var tile := _create_market_tile()
		item_grid.add_child(tile)
		tile.configure_sell(content, int(item_counts[content]), player_inventory)
	if item_counts.is_empty():
		_set_empty_message(tr("MARKET_EMPTY_NOTHING_TO_SELL"))

func _create_market_tile() -> MarketSlotUI:
	var tile := market_tile_scene.instantiate() as MarketSlotUI
	_apply_tile_size(tile)
	tile.action_completed.connect(_rebuild_market)
	return tile

func _apply_tile_widths() -> void:
	if item_grid == null:
		return
	for child in item_grid.get_children():
		var tile := child as Control
		if tile != null:
			_apply_tile_size(tile)

func _apply_tile_size(tile: Control) -> void:
	if tile == null:
		return
	var target_size := tile.custom_minimum_size
	target_size.x = _get_tile_width()
	tile.custom_minimum_size = target_size

func _get_tile_width() -> float:
	if item_grid == null or scroll_container == null:
		return 0.0
	var column_count := maxi(1, item_grid.columns)
	var available_width := scroll_container.size.x
	if available_width <= 0.0:
		available_width = scroll_container.custom_minimum_size.x
	var total_gap := item_grid.get_theme_constant("h_separation") * (column_count - 1)
	return floor(maxf(0.0, available_width - total_gap) / column_count)

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
