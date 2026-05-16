class_name QuestCreationUI extends VBoxContainer

@onready var quest_type: OptionButton = $HBoxContainer/QuestType
@onready var quest_location: OptionButton = $HBoxContainer2/QuestLocation
@onready var finish_quest_creation: Button = $FinishQuestCreation

signal quest_created(quest: Quest)

func _reset_ui() -> void:
	quest_type.clear();
	quest_location.clear();
	if finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.disconnect(_create_quest)
		
func _ready() -> void:
	quest_location.item_selected.connect(_on_location_selected)
	
func _on_location_selected() -> void:
	var location: HexBase = quest_location.get_item_metadata(quest_location.get_selected_id());
	
	quest_type.clear()
	var types := (location.structure.instance as QuestObjective).get_filtered_quest_types();
	for state: Quest.Type in types.keys():
		quest_type.add_item(types[state]);
		quest_type.set_item_metadata(quest_type.item_count, state)
		
func force_data(interaction: Interaction) -> void:
	_reset_ui();
	
	var distance := GridUtils.cube_distance(interaction.hex.cube_id, Manager.instance.player_instance.get_hex().cube_id);
	quest_location.add_item("%s (%s tiles)" % [interaction.hex.structure.structure_info.id, distance])
	quest_location.disabled = true;

func on_enter() -> void:
	_reset_ui()
	quest_location.disabled = false;
	var structure_hexes: Array[HexBase] = (SceneManager.get_active_scene().node as HexGrid).get_structured_hexes();
	
	for hex in structure_hexes:
		var distance := GridUtils.cube_distance(hex.cube_id, Manager.instance.player_instance.get_hex().cube_id);
		var in_range := distance <= Config.gamestate.max_quest_distance;
		var is_valid_quest: bool = hex.structure.instance.get_filtered_quest_types().size() != 0;
		
		if  in_range && is_valid_quest && hex.structure.structure_info.is_quest_target && hex.is_explored:
			quest_location.add_item("%s (%s tiles)" % [hex.structure.structure_info.id, distance]);
			quest_location.set_item_metadata(quest_location.item_count, hex);
	finish_quest_creation.pressed.connect(_create_quest)
	quest_type.disabled = true;
	
func _create_quest() -> void:
	quest_created.emit(Quest.new(quest_location.get_item_metadata(quest_location.get_selected_id()), quest_type.get_selected_id()));
	(owner as DraggableControl).close_requested.emit();
