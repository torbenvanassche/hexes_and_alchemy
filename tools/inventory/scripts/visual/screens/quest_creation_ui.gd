class_name QuestCreationUI extends Control

@onready var quest_type: OptionButton = $FormPanel/MarginContainer/VBoxContainer/TypeRow/QuestType
@onready var quest_location: OptionButton = $FormPanel/MarginContainer/VBoxContainer/LocationRow/QuestLocation
@onready var finish_quest_creation: Button = $FormPanel/MarginContainer/VBoxContainer/Actions/FinishQuestCreation

signal quest_created(quest: Quest)

var forced_interaction: Interaction;

func _reset_ui() -> void:
	quest_type.clear();
	quest_location.clear();
	quest_type.disabled = true;
	finish_quest_creation.disabled = true;
	if finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.disconnect(_create_quest)

func _ready() -> void:
	quest_location.item_selected.connect(_on_location_selected)
	quest_type.item_selected.connect(_on_quest_type_selected)

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
		return;

	var location: HexBase = quest_location.get_item_metadata(idx) as HexBase;
	if location == null or location.structure == null:
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		return;

	quest_type.clear();
	var objective: QuestObjective = location.structure.instance as QuestObjective;
	if objective:
		var available_types := Config.gamestate.get_available_quest_types(
			location,
			objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
		)
		for state: String in available_types:
			quest_type.add_item(_get_quest_type_label(objective, state));
			quest_type.set_item_metadata(quest_type.item_count - 1, state)
			quest_type.set_item_disabled(
				quest_type.item_count - 1,
				not objective.has_required_supplies(state, _get_player_inventory())
			)

	var has_types: bool = quest_type.item_count > 0
	quest_type.disabled = not has_types;
	_select_first_creatable_quest_type(objective)
	_update_finish_button()

func _on_quest_type_selected(_idx: int) -> void:
	_update_finish_button()

func _add_location_option(hex: HexBase) -> void:
	if hex == null or hex.structure == null:
		return

	var player_hex: HexBase = Manager.instance.player_instance.get_hex()
	if player_hex == null:
		return

	var objective: QuestObjective = hex.structure.instance as QuestObjective
	if objective == null:
		return

	var available_types := Config.gamestate.get_available_quest_types(
		hex,
		objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
	)
	if available_types.is_empty():
		return

	var distance: int = GridUtils.cube_distance(hex.cube_id, player_hex.cube_id);
	quest_location.add_item(tr("QUEST_LOCATION_DISTANCE") % [hex.structure.structure_info.get_display_name(), distance])
	quest_location.set_item_metadata(quest_location.item_count - 1, hex)

func _apply_forced_interaction() -> void:
	quest_location.disabled = true;
	if forced_interaction == null:
		return

	_add_location_option(forced_interaction.hex)
	if quest_location.item_count == 0:
		return

	quest_location.select(0)
	_on_location_selected(0)

func on_enter() -> void:
	_reset_ui()
	_connect_finish_button()
	if forced_interaction != null:
		_apply_forced_interaction()
		return

	quest_location.disabled = false;
	var structure_hexes: Array[HexBase] = (SceneManager.get_active_scene().node as HexGrid).get_structured_hexes();

	for hex in structure_hexes:
		var quest_objective: QuestObjective = hex.structure.instance as QuestObjective
		if quest_objective == null:
			continue

		var player_hex: HexBase = Manager.instance.player_instance.get_hex()
		if player_hex == null:
			continue

		var distance: int = GridUtils.cube_distance(hex.cube_id, player_hex.cube_id);
		var in_range: bool = distance <= Config.gamestate.max_quest_distance;
		var is_valid_quest: bool = Config.gamestate.get_available_quest_types(
			hex,
			quest_objective.get_filtered_quest_types()
		).size() != 0;

		if in_range and is_valid_quest and quest_objective.can_interact() and hex.structure.structure_info.is_quest_target and hex.is_explored:
			_add_location_option(hex);

	if quest_location.item_count > 0:
		quest_location.select(0)
		_on_location_selected(0);
	else:
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

func _get_quest_type_label(objective: QuestObjective, quest_type_key: String) -> String:
	var quest_name := _get_quest_type_name(quest_type_key)
	if objective == null:
		return quest_name

	var required_supplies := objective.get_required_supplies(quest_type_key)
	if required_supplies.is_empty():
		return quest_name
	return "%s (%s)" % [quest_name, _format_supplies(required_supplies)]

func _format_supplies(supplies: Dictionary[ItemInfo, int]) -> String:
	var parts: Array[String] = []
	for item: ItemInfo in supplies.keys():
		if item == null:
			continue
		var amount := int(supplies[item])
		if amount <= 0:
			continue
		parts.append("%sx %s" % [amount, item.get_display_name()])
	return ", ".join(parts)

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

func _get_player_inventory() -> Inventory:
	if Manager.instance == null or Manager.instance.player_instance == null:
		return null
	return Manager.instance.player_instance.inventory
