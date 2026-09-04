class_name HubOverviewUI
extends PanelContainer

const FACTION_CARD_SCENE := preload("res://scenes/ui/components/faction_overview_card.tscn")
const OPERATION_CARD_SCENE := preload("res://scenes/ui/components/operation_card.tscn")

@onready var faction_tabs: HBoxContainer = $Margin/Scroll/VBox/FactionTabs
@onready var faction_details: VBoxContainer = $Margin/Scroll/VBox/FactionDetails
@onready var operations_container: VBoxContainer = $Margin/Scroll/VBox/Operations
@onready var standing_panel: Control = $Margin/Scroll/VBox/StandingPanel
@onready var reputation_progress: ProgressBar = $Margin/Scroll/VBox/StandingPanel/Margin/Content/Metrics/Reputation/Progress
@onready var reputation_value: Label = $Margin/Scroll/VBox/StandingPanel/Margin/Content/Metrics/Reputation/Value
@onready var notoriety_progress: ProgressBar = $Margin/Scroll/VBox/StandingPanel/Margin/Content/Metrics/Notoriety/Progress
@onready var notoriety_value: Label = $Margin/Scroll/VBox/StandingPanel/Margin/Content/Metrics/Notoriety/Value
@onready var prestige_value: Label = $Margin/Scroll/VBox/StandingPanel/Margin/Content/Metrics/Prestige/Margin/Content/Value

var active_faction_id: StringName = &"hunters"
var _refresh_pending := false

func _ready() -> void:
	if Manager.instance != null:
		if Manager.instance.hub != null and not Manager.instance.hub.changed.is_connected(_queue_refresh):
			Manager.instance.hub.changed.connect(_queue_refresh)
		if Manager.instance.hub != null and not Manager.instance.hub.faction_activity_changed.is_connected(_queue_refresh):
			Manager.instance.hub.faction_activity_changed.connect(_queue_refresh)
		if Manager.instance.operations != null and not Manager.instance.operations.operations_changed.is_connected(_queue_refresh):
			Manager.instance.operations.operations_changed.connect(_queue_refresh)
		if Manager.instance.reputation != null and not Manager.instance.reputation.changed.is_connected(_queue_refresh):
			Manager.instance.reputation.changed.connect(_queue_refresh)
	_refresh()

func _queue_refresh() -> void:
	if _refresh_pending or not is_inside_tree():
		return
	_refresh_pending = true
	_apply_queued_refresh.call_deferred()

func _apply_queued_refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree():
		return
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or Manager.instance == null or Manager.instance.hub == null:
		return
	var hub := Manager.instance.hub
	_refresh_standing(hub)
	_refresh_factions(hub)
	_refresh_operations()

func _refresh_standing(hub: HubState) -> void:
	var standing: GuildReputation = Manager.instance.reputation
	var reputation: int = standing.reputation if standing != null else 0
	var notoriety: int = standing.notoriety if standing != null else 0
	reputation_progress.value = clampi(reputation, 0, int(reputation_progress.max_value))
	notoriety_progress.value = clampi(notoriety, 0, int(notoriety_progress.max_value))
	reputation_value.text = "%d / %d" % [reputation, int(reputation_progress.max_value)]
	notoriety_value.text = "%d / %d" % [notoriety, int(notoriety_progress.max_value)]
	prestige_value.text = str(hub.prestige)
	standing_panel.tooltip_text = standing.get_detailed_summary() if standing != null else ""

func _refresh_factions(hub: HubState) -> void:
	_clear_container(faction_tabs)
	for faction: FactionState in hub.factions.values():
		var tab := Button.new()
		tab.text = faction.get_display_name().to_upper()
		tab.toggle_mode = true
		tab.button_pressed = faction.id == active_faction_id
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 34)
		tab.pressed.connect(_select_faction.bind(faction.id))
		faction_tabs.add_child(tab)
	if not hub.factions.has(active_faction_id) and not hub.factions.is_empty():
		active_faction_id = hub.factions.keys()[0]
	_refresh_faction_details(hub)

func _select_faction(faction_id: StringName) -> void:
	active_faction_id = faction_id
	if Manager.instance != null and Manager.instance.hub != null:
		_refresh_faction_details(Manager.instance.hub)
		_refresh_operations()

func _refresh_faction_details(hub: HubState) -> void:
	_clear_container(faction_details)
	var faction := hub.factions.get(active_faction_id) as FactionState
	if faction != null:
		var card := _create_faction_card(faction)
		faction_details.add_child(card)
		(card as FactionOverviewCardUI).setup(faction)

func _create_faction_card(_faction: FactionState) -> Control:
	return FACTION_CARD_SCENE.instantiate() as FactionOverviewCardUI

func _refresh_operations() -> void:
	_clear_container(operations_container)
	var selected_faction := Manager.instance.hub.factions.get(active_faction_id) as FactionState if Manager.instance != null and Manager.instance.hub != null else null
	var active_operations: Array[HubOperation] = Manager.instance.operations.get_active_operations() if Manager.instance.operations != null else []
	if active_operations.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("HUB_NO_ACTIVE_OPERATIONS")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.45, 0.34, 0.23, 0.85))
		operations_container.add_child(empty_label)
		return
	for operation: HubOperation in active_operations:
		if operation == null or operation.quest == null:
			continue
		if selected_faction != null and operation.faction_id != selected_faction.id:
			continue
		var card := _create_operation_card(operation)
		operations_container.add_child(card)
		(card as OperationCardUI).setup(operation)
	if operations_container.get_child_count() == 0:
		var faction_empty_label := Label.new()
		faction_empty_label.text = tr("HUB_NO_ACTIVE_OPERATIONS_FACTION")
		faction_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		faction_empty_label.add_theme_color_override("font_color", Color(0.45, 0.34, 0.23, 0.85))
		operations_container.add_child(faction_empty_label)

func _create_operation_card(_operation: HubOperation) -> Control:
	return OPERATION_CARD_SCENE.instantiate() as OperationCardUI

func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
