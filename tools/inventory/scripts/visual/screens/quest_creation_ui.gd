class_name QuestCreationUI extends VBoxContainer

@onready var quest_type: OptionButton = $HBoxContainer/QuestType
@onready var quest_location: OptionButton = $HBoxContainer2/QuestLocation
@onready var finish_quest_creation: Button = $FinishQuestCreation

signal quest_created(quest: Quest)

func _ready() -> void:
	for state in Quest.Type.keys():
		quest_type.add_item(state, Quest.Type[state])
	finish_quest_creation.pressed.connect(_create_quest)
	
func _create_quest() -> void:
	quest_created.emit(Quest.new(quest_type.selected));
	(owner as DraggableControl).close_requested.emit();
