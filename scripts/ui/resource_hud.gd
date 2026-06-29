class_name ResourceHud extends Control

const RESOURCE_SINGLE_HUD := preload("res://scenes/hud/resource_single_hud.tscn")

@onready var _list: HBoxContainer = $HBoxContainer

var _entries: Array[ResourceSingleHud] = []
var _screen_margin := Vector2(12, 12)
var _content_margin := Vector2(8, 8)

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_content)
	_build_entries()
	_connect_signals()
	_refresh_counts()
	_fit_to_content.call_deferred()

func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_fit_to_content):
		get_viewport().size_changed.disconnect(_fit_to_content)
	var player := _get_player()
	if player != null and player.currency_amount_changed.is_connected(_refresh_counts):
		player.currency_amount_changed.disconnect(_refresh_counts)
	if player != null and player.inventory != null and player.inventory.changed.is_connected(_refresh_counts):
		player.inventory.changed.disconnect(_refresh_counts)

func _process(_delta: float) -> void:
	_connect_signals()

func _build_entries() -> void:
	if DataManager.instance == null or _list == null:
		return

	for child in _list.get_children():
		child.queue_free()
	_entries = []

	for item: ItemInfo in DataManager.instance.items:
		if item == null or not item.show_in_hud:
			continue
		var entry := RESOURCE_SINGLE_HUD.instantiate() as ResourceSingleHud
		entry.setup(item)
		_list.add_child(entry)
		_entries.append(entry)
	_fit_to_content.call_deferred()

func _connect_signals() -> void:
	var player := _get_player()
	if player == null:
		return

	if not player.currency_amount_changed.is_connected(_refresh_counts):
		player.currency_amount_changed.connect(_refresh_counts)
	if player.inventory != null and not player.inventory.changed.is_connected(_refresh_counts):
		player.inventory.changed.connect(_refresh_counts)
	if player.currency_amount_changed.is_connected(_refresh_counts):
		set_process(false)

func _refresh_counts() -> void:
	var player := _get_player()
	for entry in _entries:
		if entry == null or entry.item_info == null:
			continue
		entry.set_count(_get_item_count(player, entry.item_info))
	_fit_to_content.call_deferred()

func _fit_to_content() -> void:
	if _list == null:
		return
	var content_size := _list.get_combined_minimum_size()
	var panel_size := content_size + _content_margin * 2.0
	var viewport_size := get_viewport_rect().size
	var max_width := maxf(0.0, viewport_size.x - _screen_margin.x * 2.0)
	panel_size.x = minf(panel_size.x, max_width)

	size = panel_size
	position = Vector2(viewport_size.x - panel_size.x - _screen_margin.x, _screen_margin.y)
	_list.position = _content_margin
	_list.size = Vector2(maxf(0.0, panel_size.x - _content_margin.x * 2.0), content_size.y)

func _get_item_count(player: PlayerController, item: ItemInfo) -> int:
	if player == null or item == null:
		return 0
	if item.unique_id == "currency":
		return player.currency
	if player.inventory == null:
		return 0
	return player.inventory.get_count(item)

func _get_player() -> PlayerController:
	if Manager.instance == null:
		return null
	return Manager.instance.player_instance
