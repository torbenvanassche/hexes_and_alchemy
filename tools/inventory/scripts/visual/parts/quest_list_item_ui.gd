class_name QuestListItemUI extends Control

@onready var quest_type: Label = $QuestType
@onready var quest_number: Label = $QuestNumber
@onready var quest_location: Label = $QuestLocation
@onready var remove_quest: Button = $RemoveQuest
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $ProgressBar/Label

@export var supply_slot: PackedScene;

var questData: Quest;

func set_data(quest: Quest) -> void:
	questData = quest;
	
	quest_number.text = "%s." % [str(self.get_parent().get_child_count())];
	quest_type.text = quest.Type.find_key(quest.quest_type);
	quest_location.text = quest.location.structure.structure_info.id;
	_update_progress()
	
	quest.update_status.connect(_update_progress)
	
func _update_progress() -> void:
	progress_bar.value = questData.progress;
	label.text = questData.status;
