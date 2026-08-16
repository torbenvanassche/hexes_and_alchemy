class_name ResourceHud extends Control

const RESOURCE_SINGLE_HUD := preload("res://scenes/hud/resource_single_hud.tscn")

@onready var _list: GridContainer = $Margin/Content/ResourceGrid
@onready var _day_label: Label = $Margin/Content/TimeRow/Day
@onready var _phase_label: Label = $Margin/Content/TimeRow/Phase
@onready var _clock_label: Label = $Margin/Content/TimeRow/Clock

var _entries: Array[ResourceSingleHud] = []

func _ready() -> void:
	_build_entries()
	_connect_signals()
	_connect_time_signals()
	_refresh_counts()
	_refresh_time()

func _exit_tree() -> void:
	var player := _get_player()
	if player != null and player.currency_amount_changed.is_connected(_refresh_counts):
		player.currency_amount_changed.disconnect(_refresh_counts)
	if player != null and player.inventory != null and player.inventory.changed.is_connected(_refresh_counts):
		player.inventory.changed.disconnect(_refresh_counts)
	var hub := _get_hub()
	if hub != null and hub.changed.is_connected(_refresh_counts):
		hub.changed.disconnect(_refresh_counts)
	var cycle := _get_time_of_day()
	if cycle != null:
		if cycle.time_changed.is_connected(_on_time_changed):
			cycle.time_changed.disconnect(_on_time_changed)
		if cycle.phase_changed.is_connected(_on_phase_changed):
			cycle.phase_changed.disconnect(_on_phase_changed)

func _process(_delta: float) -> void:
	_connect_signals()
	_connect_time_signals()
	if _get_player() != null and _get_time_of_day() != null:
		set_process(false)

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

func _connect_signals() -> void:
	var hub := _get_hub()
	if hub != null and not hub.changed.is_connected(_refresh_counts):
		hub.changed.connect(_refresh_counts)
	var player := _get_player()
	if player == null:
		return
	if not player.currency_amount_changed.is_connected(_refresh_counts):
		player.currency_amount_changed.connect(_refresh_counts)
	if player.inventory != null and not player.inventory.changed.is_connected(_refresh_counts):
		player.inventory.changed.connect(_refresh_counts)

func _connect_time_signals() -> void:
	var cycle := _get_time_of_day()
	if cycle == null:
		return
	if not cycle.time_changed.is_connected(_on_time_changed):
		cycle.time_changed.connect(_on_time_changed)
	if not cycle.phase_changed.is_connected(_on_phase_changed):
		cycle.phase_changed.connect(_on_phase_changed)

func _refresh_counts() -> void:
	var player := _get_player()
	for entry in _entries:
		if entry == null or entry.item_info == null:
			continue
		entry.set_count(_get_item_count(player, entry.item_info))

func _refresh_time() -> void:
	var cycle := _get_time_of_day()
	if cycle == null:
		_day_label.text = tr("HUD_TIME_DAY") % 1
		_phase_label.text = ""
		_clock_label.text = "--:--"
		return
	_on_time_changed(cycle.get_day_number(), cycle.get_clock_hour(), cycle.get_clock_minute())
	_on_phase_changed(cycle.current_phase)

func _on_time_changed(day: int, hour: int, minute: int) -> void:
	_day_label.text = tr("HUD_TIME_DAY") % day
	_clock_label.text = "%02d:%02d" % [hour, minute]

func _on_phase_changed(phase: TimeOfDayPhase) -> void:
	_phase_label.text = phase.get_display_name() if phase != null else ""

func _get_item_count(player: PlayerController, item: ItemInfo) -> int:
	if item == null:
		return 0
	var hub := _get_hub()
	if item.unique_id == "currency":
		return hub.currency if hub != null else (player.currency if player != null else 0)
	if hub != null and hub.stockpile != null:
		return hub.stockpile.get_count(item)
	if player == null or player.inventory == null:
		return 0
	return player.inventory.get_count(item)

func _get_player() -> PlayerController:
	return Manager.instance.player_instance if Manager.instance != null else null

func _get_hub() -> HubState:
	return Manager.instance.hub if Manager.instance != null else null

func _get_time_of_day() -> TimeOfDay:
	return Manager.instance.time_of_day if Manager.instance != null else null
