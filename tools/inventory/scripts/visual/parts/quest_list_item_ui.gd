class_name QuestListItemUI extends Control

@onready var quest_type: Label = $QuestType
@onready var quest_number: Label = $QuestNumber
@onready var quest_location: Label = $QuestLocation
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $ProgressBar/Label
@onready var party: HBoxContainer = $Party
@onready var approve_quest: Button = $ApproveQuest
@onready var complete_quest: Button = $CompleteQuest

@export var supply_slot: PackedScene;

var questData: Quest;

func set_data(quest: Quest) -> void:
	questData = quest;
	
	quest_number.text = "%s." % [str(self.get_parent().get_child_count())];
	quest_type.text = quest.Type.find_key(quest.quest_type);
	quest_location.text = quest.location.structure.structure_info.id;
	if approve_quest.pressed.is_connected(questData.start):
		approve_quest.pressed.disconnect(questData.start);
	if complete_quest.pressed.is_connected(questData.parse_reward):
		complete_quest.pressed.disconnect(questData.parse_reward);
	complete_quest.pressed.connect(questData.parse_reward);
	_update_progress()
	
	for n in quest.party:
		var img := TextureRect.new();
		img.texture = n.npc_info.img;
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH;
		party.add_child(img);
	
	quest.update_status.connect(_update_progress)
	
func _update_progress() -> void:
	progress_bar.value = questData.progress;
	label.text = questData.get_state_as_string();
	approve_quest.visible = questData.status != Quest.QuestState.COMPLETE;
	complete_quest.visible = questData.status == Quest.QuestState.COMPLETE;
