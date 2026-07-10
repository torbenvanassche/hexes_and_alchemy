class_name QuestCreationUI extends Control

@onready var quest_type: OptionButton = $MarginContainer/VBoxContainer/TypeRow/QuestType
@onready var quest_location: OptionButton = $MarginContainer/VBoxContainer/LocationRow/QuestLocation
@onready var details_panel: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/DescriptionLabel
@onready var rank_requirement_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/RankRequirementLabel
@onready var details_divider: ColorRect = $MarginContainer/VBoxContainer/DetailsPanel/DetailsDivider
@onready var meta_row: HBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow
@onready var duration_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/DurationBox
@onready var duration_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/DurationBox/DurationLabel
@onready var risk_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RiskBox
@onready var risk_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RiskBox/RiskLabel
@onready var reward_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RewardBox
@onready var reward_items: FlowContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RewardBox/RewardItems
@onready var reward_text_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RewardBox/RewardText
@onready var quest_supplies: Control = $MarginContainer/VBoxContainer/QuestSupplies
@onready var supplies_grid: GridContainer = $MarginContainer/VBoxContainer/QuestSupplies/SuppliesGrid
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var finish_quest_creation: Button = $MarginContainer/VBoxContainer/Actions/FinishQuestCreation
@onready var window: DraggableControl = $"../../../.."

@export var packed_slot: PackedScene
@export var slot_size: int = 56
@export var target_dropdown_max_height: int = 220

signal quest_created(quest: Quest)

var forced_interaction: Interaction;

func _reset_ui() -> void:
	quest_type.clear();
	quest_location.clear();
	quest_type.disabled = true;
	finish_quest_creation.disabled = true;
	_set_details("")
	_set_status("")
	_refresh_required_supplies()
	if finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.disconnect(_create_quest)

func _ready() -> void:
	_configure_location_dropdown()
	quest_location.item_selected.connect(_on_location_selected)
	quest_type.item_selected.connect(_on_quest_type_selected)
	_request_window_refit()

func _configure_location_dropdown() -> void:
	var popup := quest_location.get_popup()
	if popup == null:
		return
	popup.max_size = Vector2i(4096, target_dropdown_max_height)

func clear_forced_data() -> void:
	forced_interaction = null

func force_data(interaction: Interaction) -> void:
	forced_interaction = interaction
	if is_inside_tree():
		_reset_ui()
		_connect_finish_button()
		_apply_forced_interaction()

func _connect_finish_button() -> void:
	if not finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.connect(_create_quest)

func _on_location_selected(idx: int) -> void:
	if idx == -1:
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		_set_details("")
		_set_status("")
		_refresh_required_supplies()
		return;

	var location: HexBase = quest_location.get_item_metadata(idx) as HexBase;
	if location == null or location.structure == null:
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		_set_details("")
		_set_status("")
		_refresh_required_supplies()
		return;

	quest_type.clear();
	var objective: QuestObjective = location.structure.instance as QuestObjective;
	if objective:
		var available_types := Manager.instance.quests.get_available_quest_types(
			location,
			objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
		)
		for state: String in available_types:
			quest_type.add_item(_get_quest_type_label(state));
			quest_type.set_item_metadata(quest_type.item_count - 1, state)
			quest_type.set_item_disabled(
				quest_type.item_count - 1,
				not _can_create_quest(location, objective, state)
			)

	var has_types: bool = quest_type.item_count > 0
	quest_type.disabled = not has_types;
	_select_first_creatable_quest_type(objective)
	_refresh_required_supplies()
	_refresh_quest_details()
	_update_finish_button()

func _on_quest_type_selected(_idx: int) -> void:
	_refresh_required_supplies()
	_refresh_quest_details()
	_update_finish_button()

func _add_location_option(hex: HexBase, require_reachable: bool = true) -> bool:
	if not _is_available_location_base(hex):
		return false

	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return false

	var grid := active_scene.node as HexGrid
	if grid == null:
		return false
	if require_reachable and not Manager.instance.quests.is_quest_location_reachable(hex, grid):
		return false

	var player_hex: HexBase = Manager.instance.player_instance.get_hex()
	if player_hex == null:
		return false

	var objective: QuestObjective = hex.structure.instance as QuestObjective
	var available_types := Manager.instance.quests.get_available_quest_types(
		hex,
		objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
	)
	if available_types.is_empty():
		return false

	var distance: int = GridUtils.cube_distance(hex.cube_id, player_hex.cube_id);
	quest_location.add_item(tr("QUEST_LOCATION_DISTANCE") % [hex.structure.structure_info.get_display_name(), distance])
	quest_location.set_item_metadata(quest_location.item_count - 1, hex)
	return true

func _is_available_location_base(hex: HexBase) -> bool:
	if hex == null or hex.structure == null:
		return false
	if not hex.is_explored or not hex.is_visible_in_tree():
		return false
	if not hex.structure.structure_info.is_quest_target:
		return false

	var objective := hex.structure.instance as QuestObjective
	return objective != null and objective.is_visible_in_tree() and objective.can_interact()

func _sort_locations_by_distance(locations: Array[HexBase]) -> Array[HexBase]:
	var player_hex: HexBase = Manager.instance.player_instance.get_hex()
	if player_hex == null:
		return locations

	var sorted_locations := locations.duplicate()
	sorted_locations.sort_custom(func(a: HexBase, b: HexBase) -> bool:
		var distance_a := GridUtils.cube_distance(a.cube_id, player_hex.cube_id)
		var distance_b := GridUtils.cube_distance(b.cube_id, player_hex.cube_id)
		if distance_a == distance_b:
			return a.structure.structure_info.get_display_name().nocasecmp_to(
				b.structure.structure_info.get_display_name()
			) < 0
		return distance_a < distance_b
	)
	return sorted_locations

func _apply_forced_interaction() -> void:
	quest_location.disabled = true;
	if forced_interaction == null:
		return

	if forced_interaction.hex == null:
		_set_details("")
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		return

	var active_scene := SceneManager.get_active_scene()
	var grid: HexGrid = null
	if active_scene != null:
		grid = active_scene.node as HexGrid
	if grid != null and not Manager.instance.quests.is_quest_location_reachable(forced_interaction.hex, grid):
		_set_details("")
		_set_status(tr("QUEST_CREATION_UNREACHABLE"))
		return

	if not _add_location_option(forced_interaction.hex):
		_set_details("")
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		return

	_set_status("")
	quest_location.select(0)
	_on_location_selected(0)

func on_enter() -> void:
	_reset_ui()
	_connect_finish_button()
	if forced_interaction != null:
		_apply_forced_interaction()
		if window != null:
			window.request_fit_to_content();
		return

	quest_location.disabled = false;
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		_on_location_selected(-1)
		return

	var grid := active_scene.node as HexGrid
	if grid == null:
		_on_location_selected(-1)
		return

	var structure_hexes: Array[HexBase] = grid.get_structured_hexes();
	var available_locations: Array[HexBase] = []

	for hex in structure_hexes:
		if not _is_available_location_base(hex):
			continue

		var quest_objective: QuestObjective = hex.structure.instance as QuestObjective

		var player_hex: HexBase = Manager.instance.player_instance.get_hex()
		if player_hex == null:
			continue

		var distance: int = GridUtils.cube_distance(hex.cube_id, player_hex.cube_id);
		var in_range: bool = distance <= Manager.instance.quests.max_quest_distance;
		var is_reachable := Manager.instance.quests.is_quest_location_reachable(hex, grid)
		var is_valid_quest: bool = Manager.instance.quests.get_available_quest_types(
			hex,
			quest_objective.get_filtered_quest_types()
		).size() != 0;

		if in_range and is_reachable and is_valid_quest:
			available_locations.append(hex)

	for hex in _sort_locations_by_distance(available_locations):
		_add_location_option(hex)

	if quest_location.item_count > 0:
		quest_location.select(0)
		_on_location_selected(0);
	else:
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		_on_location_selected(-1);

	if window != null:
		window.request_fit_to_content();

func _create_quest() -> void:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return

	var quest := Quest.new(location, quest_type_key)
	var objective := location.structure.instance as QuestObjective
	if objective == null or not _can_create_quest(location, objective, quest_type_key):
		_update_finish_button()
		return
	if not objective.assign_required_supplies(quest, _get_player_inventory()):
		_update_finish_button()
		return

	quest_created.emit(quest);
	if window != null:
		window.close_requested.emit();

func _get_quest_type_name(quest_type_key: String) -> String:
	var objective := _get_selected_objective()
	if objective != null:
		var profile := objective.get_profile(quest_type_key)
		if profile != null:
			return profile.get_display_name()
	var translation_key := "QUEST_TYPE_%s" % [quest_type_key.to_upper()]
	var translated := tr(translation_key)
	if translated == translation_key:
		return quest_type_key.capitalize()
	return translated

func _get_quest_type_label(quest_type_key: String) -> String:
	return _get_quest_type_name(quest_type_key)

func _select_first_creatable_quest_type(objective: QuestObjective) -> void:
	if objective == null:
		return
	var location := quest_location.get_item_metadata(quest_location.selected) as HexBase
	for i in quest_type.item_count:
		var quest_type_key := _get_quest_type_key(i)
		if quest_type_key == "":
			continue
		if _can_create_quest(location, objective, quest_type_key):
			quest_type.select(i)
			return

	if quest_type.item_count > 0:
		quest_type.select(0)

func _update_finish_button() -> void:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		finish_quest_creation.disabled = true
		return

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or location.structure == null or quest_type_key == "":
		finish_quest_creation.disabled = true
		return

	var objective := location.structure.instance as QuestObjective
	finish_quest_creation.disabled = not _can_create_quest(location, objective, quest_type_key)

func _can_create_quest(location: HexBase, objective: QuestObjective, quest_type_key: String) -> bool:
	if Manager.instance == null or Manager.instance.quests == null:
		return false
	if location == null or objective == null or quest_type_key == "":
		return false
	if not objective.has_required_supplies(quest_type_key, _get_player_inventory()):
		return false
	return Manager.instance.quests.has_eligible_npc_for_quest(location, quest_type_key)

func _refresh_required_supplies() -> void:
	for child in supplies_grid.get_children():
		supplies_grid.remove_child(child)
		child.queue_free()

	var required_supplies := _get_selected_required_supplies()
	var has_visible_supplies := false
	for item: ItemInfo in required_supplies.keys():
		if item == null:
			continue
		var amount := int(required_supplies[item])
		if amount <= 0:
			continue
		supplies_grid.add_child(_create_supply_slot(item, amount))
		has_visible_supplies = true

	quest_supplies.visible = has_visible_supplies
	_request_window_refit()

func _request_window_refit() -> void:
	if window == null:
		return

	if window.visible:
		if window.has_method("request_fit_to_content"):
			window.request_fit_to_content(2)
		else:
			window.call_deferred("_fit_to_content")

func _set_detail_value(label: Label, container: Control, message: String) -> bool:
	if label == null or container == null:
		return false
	label.text = message
	var should_show := message != ""
	label.visible = should_show
	container.visible = should_show
	return should_show

func _clear_reward_preview() -> void:
	if reward_items == null:
		return
	for child in reward_items.get_children():
		reward_items.remove_child(child)
		child.queue_free()

func _set_reward_preview(preview: Array[Dictionary]) -> bool:
	_clear_reward_preview()
	if reward_box == null or reward_items == null:
		return false

	var has_rewards := false
	for entry in preview:
		var item := entry.get("item") as ItemInfo
		if item == null:
			continue

		var min_amount := int(entry.get("min", 0))
		var max_amount := int(entry.get("max", 0))
		if max_amount <= 0:
			continue
		var slot := _create_reward_slot()
		reward_items.add_child(slot)

		_set_reward_slot(slot, item, min_amount, max_amount)
		has_rewards = true

	if reward_text_label != null:
		reward_text_label.text = ""
		reward_text_label.visible = false

	reward_box.visible = has_rewards
	return has_rewards

func _create_reward_slot() -> ContentSlotUI:
	var slot: ContentSlotUI = packed_slot.instantiate()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.can_drag = false
	return slot

func _set_reward_slot(slot: ContentSlotUI, item: ItemInfo, min_amount: int, max_amount: int) -> void:
	var range_text := _format_reward_range(min_amount, max_amount)
	var count := maxi(1, max_amount)
	slot.visible = true
	slot.set_content(ContentSlotResource.new(count, item, count, true, false))
	slot.redraw()
	if slot.counter != null:
		slot.counter.visible = true
		slot.counter.text = range_text
	slot.tooltip_text = "%s: %s" % [item.get_display_name(), range_text]

func _format_reward_range(min_amount: int, max_amount: int) -> String:
	var clamped_min := maxi(0, min_amount)
	var clamped_max := maxi(clamped_min, max_amount)
	if clamped_min == clamped_max:
		return str(clamped_max)
	return "%s-%s" % [clamped_min, clamped_max]

func _set_details(
	description: String,
	rank_requirement: String = "",
	duration: String = "",
	risk: String = "",
	reward_preview: Array[Dictionary] = []
) -> void:
	var has_description := false
	if description_label != null:
		description_label.text = description
		has_description = description != ""
		description_label.visible = has_description

	var has_rank_requirement := false
	if rank_requirement_label != null:
		rank_requirement_label.text = rank_requirement
		has_rank_requirement = rank_requirement != ""
		rank_requirement_label.visible = has_rank_requirement

	var has_duration := _set_detail_value(duration_label, duration_box, duration)
	var has_risk := _set_detail_value(risk_label, risk_box, risk)
	var has_reward := _set_reward_preview(reward_preview)
	var has_detail_meta := has_duration or has_risk or has_reward

	if details_divider != null:
		details_divider.visible = (has_description or has_rank_requirement) and has_detail_meta
	if meta_row != null:
		meta_row.visible = has_detail_meta

	var has_details := has_description or has_rank_requirement or has_detail_meta
	if details_panel != null:
		details_panel.visible = has_details
	_request_window_refit()

func _set_status(message: String) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.visible = message != ""
	_request_window_refit()

func _get_selected_required_supplies() -> Dictionary[ItemInfo, int]:
	var selected := _get_selected_quest_type_and_objective()
	var objective := selected.get("objective") as QuestObjective
	var quest_type_key := str(selected.get("quest_type", ""))
	if objective == null or quest_type_key == "":
		return {}

	return objective.get_required_supplies(quest_type_key)

func _refresh_quest_details() -> void:
	var selected := _get_selected_quest_type_and_objective()
	var objective := selected.get("objective") as QuestObjective
	var quest_type_key := str(selected.get("quest_type", ""))
	if objective == null or quest_type_key == "":
		_set_details("")
		return

	var description := objective.get_quest_profile_description(quest_type_key)

	var duration_text := ""
	var duration := objective.get_quest_duration(quest_type_key, 0.0)
	if duration > 0.0:
		duration_text = "%ss" % [ceil(duration)]

	var risk_text := ""
	var risk := objective.get_quest_profile_risk(quest_type_key)
	if risk != "":
		risk_text = risk

	var reward_preview := objective.get_quest_profile_reward_preview(quest_type_key)
	var rank_text := _get_rank_requirement_text(objective, quest_type_key)
	_set_details(description, rank_text, duration_text, risk_text, reward_preview)

func _get_rank_requirement_text(objective: QuestObjective, quest_type_key: String) -> String:
	var minimum_rank := objective.get_quest_minimum_rank(quest_type_key)
	var rank_label := AdventurerRank.get_display_name(minimum_rank)
	return tr("QUEST_DETAIL_REQUIRED_RANK") % [rank_label]

func _get_selected_objective() -> QuestObjective:
	var selected := _get_selected_quest_type_and_objective()
	return selected.get("objective") as QuestObjective

func _get_selected_quest_type_and_objective() -> Dictionary:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return {}

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or location.structure == null or quest_type_key == "":
		return {}

	var objective := location.structure.instance as QuestObjective
	if objective == null:
		return {}

	return {
		"objective": objective,
		"quest_type": quest_type_key,
	}

func _get_quest_type_key(index: int) -> String:
	if index < 0 or index >= quest_type.item_count:
		return ""
	var metadata = quest_type.get_item_metadata(index)
	return str(metadata) if metadata is String else ""

func _create_supply_slot(item: ItemInfo, count: int) -> ContentSlotUI:
	var slot: ContentSlotUI = packed_slot.instantiate()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.can_drag = false
	slot.set_content(ContentSlotResource.new(count, item, max(1, count), true, false))
	return slot

func _get_player_inventory() -> Inventory:
	if Manager.instance == null or Manager.instance.player_instance == null:
		return null
	return Manager.instance.player_instance.inventory
