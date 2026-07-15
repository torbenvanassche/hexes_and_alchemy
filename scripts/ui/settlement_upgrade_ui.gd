class_name SettlementUpgradeUI
extends PanelContainer

@onready var current_level_value: Label = $MarginContainer/VBoxContainer/CurrentRow/CurrentLevelValue
@onready var next_section: VBoxContainer = $MarginContainer/VBoxContainer/NextSection
@onready var next_level_label: Label = $MarginContainer/VBoxContainer/NextSection/NextLevelLabel
@onready var unlock_label: Label = $MarginContainer/VBoxContainer/NextSection/UnlockLabel
@onready var requirements_divider: ColorRect = $MarginContainer/VBoxContainer/RequirementsDivider
@onready var requirements_header: Label = $MarginContainer/VBoxContainer/RequirementsHeader
@onready var requirements_list: VBoxContainer = $MarginContainer/VBoxContainer/RequirementsList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var upgrade_button: Button = $MarginContainer/VBoxContainer/UpgradeButton

var settlement: Settlement
var player_inventory: ContentGroup

func _ready() -> void:
	if not upgrade_button.pressed.is_connected(_on_upgrade_pressed):
		upgrade_button.pressed.connect(_on_upgrade_pressed)

func setup_interaction(interaction: Interaction) -> void:
	var service := interaction as SettlementService
	settlement = service.get_settlement() if service != null else null
	var player := Manager.instance.player_instance if Manager.instance != null else null
	player_inventory = player.inventory if player != null else null
	if settlement != null and not settlement.level_changed.is_connected(_on_settlement_changed):
		settlement.level_changed.connect(_on_settlement_changed)
	if player_inventory != null and not player_inventory.changed.is_connected(_refresh):
		player_inventory.changed.connect(_refresh)
	_refresh()

func on_enter() -> void:
	_refresh()

func _on_settlement_changed(_new_level: int) -> void:
	_refresh()

func _on_upgrade_pressed() -> void:
	if settlement == null or player_inventory == null:
		return
	if settlement.try_upgrade(player_inventory):
		_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	_clear_requirements()
	if settlement == null:
		current_level_value.text = "-"
		next_section.visible = false
		requirements_divider.visible = false
		requirements_header.visible = false
		requirements_list.visible = false
		unlock_label.text = ""
		status_label.text = tr("SETTLEMENT_UPGRADE_NO_SETTLEMENT")
		status_label.visible = true
		upgrade_button.disabled = true
		_request_window_fit()
		return

	current_level_value.text = str(settlement.level)
	var upgrade := settlement.get_next_upgrade()
	if upgrade == null:
		next_section.visible = true
		requirements_divider.visible = false
		requirements_header.visible = false
		requirements_list.visible = false
		unlock_label.text = tr("SETTLEMENT_UPGRADE_MAX_LEVEL")
		unlock_label.visible = true
		next_level_label.text = tr("SETTLEMENT_UPGRADE_MAX_LEVEL_HEADER")
		status_label.text = ""
		status_label.visible = false
		upgrade_button.text = tr("SETTLEMENT_UPGRADE_COMPLETE")
		upgrade_button.disabled = true
		_request_window_fit()
		return

	next_section.visible = true
	requirements_divider.visible = true
	requirements_header.visible = true
	requirements_list.visible = true
	next_level_label.text = tr("SETTLEMENT_UPGRADE_NEXT") % [upgrade.target_level]
	var unlock_text := upgrade.get_unlock_text()
	unlock_label.text = unlock_text
	unlock_label.visible = unlock_text != ""

	var missing_services := settlement.get_missing_service_requirements(upgrade)
	for service_name in upgrade.required_services:
		_add_requirement_row(
			_get_service_display_name(service_name),
			not missing_services.has(service_name)
		)

	for item_info: ItemInfo in upgrade.item_cost.keys():
		if item_info == null:
			continue
		var required := int(upgrade.item_cost[item_info])
		var available := player_inventory.get_count(item_info) if player_inventory != null else 0
		_add_requirement_row(
			"%s %s/%s" % [item_info.get_display_name(), available, required],
			available >= required
		)

	var can_level := settlement.can_upgrade(player_inventory)
	status_label.text = "" if can_level else tr("SETTLEMENT_UPGRADE_REQUIREMENTS_MISSING")
	status_label.visible = status_label.text != ""
	upgrade_button.text = tr("SETTLEMENT_UPGRADE_BUTTON") % [upgrade.target_level]
	upgrade_button.disabled = not can_level
	_request_window_fit()

func _add_requirement_row(text: String, complete: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "RequirementRow"
	row.theme = theme
	row.add_theme_constant_override("separation", 8)

	var state_label := Label.new()
	state_label.name = "StateLabel"
	state_label.custom_minimum_size = Vector2(80, 0)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.theme = theme
	state_label.theme_type_variation = "Label"
	state_label.text = tr("SETTLEMENT_UPGRADE_READY") if complete else tr("SETTLEMENT_UPGRADE_MISSING")
	state_label.modulate = Color(0.26, 0.54, 0.22) if complete else Color(0.72, 0.22, 0.13)
	row.add_child(state_label)

	var requirement_label := Label.new()
	requirement_label.name = "RequirementLabel"
	requirement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	requirement_label.theme = theme
	requirement_label.theme_type_variation = "Label"
	requirement_label.text = text
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(requirement_label)

	requirements_list.add_child(row)

func _clear_requirements() -> void:
	for child in requirements_list.get_children():
		requirements_list.remove_child(child)
		child.queue_free()

func _get_service_display_name(service_name: StringName) -> String:
	var translation_key := "SETTLEMENT_SERVICE_%s" % String(service_name).to_upper()
	var translated := tr(translation_key)
	return String(service_name).capitalize() if translated == translation_key else translated

func _request_window_fit() -> void:
	var current := get_parent()
	while current != null:
		if current is DraggableControl:
			(current as DraggableControl).request_fit_to_content(2)
			return
		current = current.get_parent()
