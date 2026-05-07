class_name QuestCreationUI extends VBoxContainer

@onready var quest_type: OptionButton = $HBoxContainer/QuestType
@onready var quest_location: OptionButton = $HBoxContainer2/QuestLocation
@onready var finish_quest_creation: Button = $FinishQuestCreation

signal quest_created(quest: Quest)

var quest_location_hashes: Array[HexBase]

func _reset_ui() -> void:
	quest_type.clear();
	quest_location.clear();
	quest_location_hashes.clear();
	if finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.disconnect(_create_quest)
		
func force_data(interaction: Interaction) -> void:
	quest_location.select(quest_location_hashes.find(interaction.hex))
	quest_location.disabled = true;

func on_enter() -> void:
	_reset_ui()
	for state in Quest.Type.keys():
		quest_type.add_item(state, Quest.Type[state])
	var structure_hexes: Array[HexBase] = (SceneManager.get_active_scene().node as HexGrid).get_structured_hexes();
	for hex in structure_hexes:
		var distance := GridUtils.cube_distance(hex.cube_id, Manager.instance.player_instance.get_hex().cube_id);
		if  distance <= Config.gameplay.max_quest_distance && hex.structure.structure_info.is_quest_target && hex.is_explored:
			quest_location.add_item("%s (%s tiles)" % [hex.structure.structure_info.id, distance], quest_location_hashes.size())
			quest_location_hashes.append(hex)
	finish_quest_creation.pressed.connect(_create_quest)
	
func _create_quest() -> void:
	quest_created.emit(Quest.new(quest_location_hashes[quest_location.get_selected_id()], quest_type.get_selected_id()));
	(owner as DraggableControl).close_requested.emit();
