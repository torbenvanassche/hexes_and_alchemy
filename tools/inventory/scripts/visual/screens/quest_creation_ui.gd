class_name QuestCreationUI extends VBoxContainer

@onready var quest_type: OptionButton = $HBoxContainer/QuestType
@onready var quest_location: OptionButton = $HBoxContainer2/QuestLocation
@onready var finish_quest_creation: Button = $FinishQuestCreation

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
		finish_quest_creation.disabled = true
		return;

	var location: HexBase = quest_location.get_item_metadata(idx) as HexBase;
	if location == null or location.structure == null:
		finish_quest_creation.disabled = true
		return;

	quest_type.clear();
	var objective: QuestObjective = location.structure.instance as QuestObjective;
	if objective:
		for state: String in objective.get_filtered_quest_types(objective.state_machine.get_current_state_index()):
			quest_type.add_item(state);
			quest_type.set_item_metadata(quest_type.item_count - 1, state)

	var has_types: bool = quest_type.item_count > 0
	quest_type.disabled = not has_types;
	finish_quest_creation.disabled = not has_types;

func _add_location_option(hex: HexBase) -> void:
	if hex == null or hex.structure == null:
		return

	var player_hex: HexBase = Manager.instance.player_instance.get_hex()
	if player_hex == null:
		return

	var distance: int = GridUtils.cube_distance(hex.cube_id, player_hex.cube_id);
	quest_location.add_item("%s (%s tiles)" % [hex.structure.structure_info.id, distance])
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
		var is_valid_quest: bool = quest_objective.get_filtered_quest_types().size() != 0;

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

	quest_created.emit(Quest.new(location, quest_type_key));
	(owner as DraggableControl).close_requested.emit();
