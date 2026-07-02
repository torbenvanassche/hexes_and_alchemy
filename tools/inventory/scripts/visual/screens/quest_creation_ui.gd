class_name QuestCreationUI extends Control

@onready var quest_type: OptionButton = $FormPanel/MarginContainer/VBoxContainer/TypeRow/QuestType
@onready var quest_location: OptionButton = $FormPanel/MarginContainer/VBoxContainer/LocationRow/QuestLocation
@onready var quest_supplies: Control = $FormPanel/MarginContainer/VBoxContainer/QuestSupplies
@onready var supplies_grid: GridContainer = $FormPanel/MarginContainer/VBoxContainer/QuestSupplies/SuppliesGrid
@onready var status_label: Label = $FormPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var finish_quest_creation: Button = $FormPanel/MarginContainer/VBoxContainer/Actions/FinishQuestCreation

@export var packed_slot: PackedScene
@export var slot_size: int = 56
@export var target_dropdown_max_height: int = 220
@export var no_supplies_window_min_size := Vector2(390, 205)
@export var supplies_window_min_size := Vector2(390, 280)

signal quest_created(quest: Quest)

var forced_interaction: Interaction;

func _reset_ui() -> void:
	quest_type.clear();
	quest_location.clear();
	quest_type.disabled = true;
	finish_quest_creation.disabled = true;
	_set_status("")
	_refresh_required_supplies()
	if finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.disconnect(_create_quest)

func _ready() -> void:
	_configure_location_dropdown()
	quest_location.item_selected.connect(_on_location_selected)
	quest_type.item_selected.connect(_on_quest_type_selected)

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
		_refresh_required_supplies()
		return;

	var location: HexBase = quest_location.get_item_metadata(idx) as HexBase;
	if location == null or location.structure == null:
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
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
				not objective.has_required_supplies(state, _get_player_inventory())
			)

	var has_types: bool = quest_type.item_count > 0
	quest_type.disabled = not has_types;
	_select_first_creatable_quest_type(objective)
	_refresh_required_supplies()
	_update_finish_button()

func _on_quest_type_selected(_idx: int) -> void:
	_refresh_required_supplies()
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
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		return

	var active_scene := SceneManager.get_active_scene()
	var grid: HexGrid = null
	if active_scene != null:
		grid = active_scene.node as HexGrid
	if grid != null and not Manager.instance.quests.is_quest_location_reachable(forced_interaction.hex, grid):
		_set_status(tr("QUEST_CREATION_UNREACHABLE"))
		return

	if not _add_location_option(forced_interaction.hex):
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

func _create_quest() -> void:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_metadata: Variant = quest_type.get_item_metadata(quest_type_idx)
	if not (quest_type_metadata is String):
		return

	var quest_type_key: String = str(quest_type_metadata)
	if location == null or quest_type_key == "":
		return

	var quest := Quest.new(location, quest_type_key)
	var objective := location.structure.instance as QuestObjective
	if objective != null and not objective.assign_required_supplies(quest, _get_player_inventory()):
		_update_finish_button()
		return

	quest_created.emit(quest);
	(owner as DraggableControl).close_requested.emit();

func _get_quest_type_name(quest_type_key: String) -> String:
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
	for i in quest_type.item_count:
		var quest_type_metadata: Variant = quest_type.get_item_metadata(i)
		if not (quest_type_metadata is String):
			continue
		if objective.has_required_supplies(str(quest_type_metadata), _get_player_inventory()):
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
	var quest_type_metadata: Variant = quest_type.get_item_metadata(quest_type_idx)
	if location == null or location.structure == null or not (quest_type_metadata is String):
		finish_quest_creation.disabled = true
		return

	var objective := location.structure.instance as QuestObjective
	finish_quest_creation.disabled = objective == null or not objective.has_required_supplies(
		str(quest_type_metadata),
		_get_player_inventory()
	)

func _refresh_required_supplies() -> void:
	for child in supplies_grid.get_children():
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
	_update_window_supply_space(has_visible_supplies)

func _update_window_supply_space(has_visible_supplies: bool) -> void:
	var window := owner as DraggableControl
	if window == null:
		return

	var needs_status_space := status_label != null and status_label.visible
	window.custom_minimum_size = supplies_window_min_size if has_visible_supplies or needs_status_space else no_supplies_window_min_size
	if window.visible:
		window.call_deferred("_fit_to_content")

func _set_status(message: String) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.visible = message != ""
	_update_window_supply_space(quest_supplies != null and quest_supplies.visible)

func _get_selected_required_supplies() -> Dictionary[ItemInfo, int]:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return {}

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_metadata: Variant = quest_type.get_item_metadata(quest_type_idx)
	if location == null or location.structure == null or not (quest_type_metadata is String):
		return {}

	var objective := location.structure.instance as QuestObjective
	if objective == null:
		return {}

	return objective.get_required_supplies(str(quest_type_metadata))

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
