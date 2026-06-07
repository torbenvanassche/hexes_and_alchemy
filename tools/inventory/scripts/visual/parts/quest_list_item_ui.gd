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
	if questData:
		Debug.err("Quest already has data, create a new one instead!")
		return
	questData = quest;
	
	quest_number.text = "%s." % [str(self.get_parent().get_child_count())];
	quest_type.text = quest.quest_key;
	quest_location.text = quest.location.structure.structure_info.id;

	approve_quest.pressed.connect(_start_quest)
	complete_quest.pressed.connect(questData.parse_reward);
	_update_progress(questData.state_machine.get_current_state())
	
	quest.state_machine.state_entered.connect(_update_progress)
	quest.completed.connect(_on_quest_complete)
	
func _on_quest_complete() -> void:
	questData = null;
	queue_free();
	
func _start_quest() -> void:
	var taverns: Array[Tavern];
	taverns.assign(Manager.instance.active_settlement.interactions.filter(func(x: Interaction) -> bool: return x is Tavern));
	if taverns.size() != 0:
		var npcs: Array[SceneInstance] = taverns[0].get_available_npcs();
		if npcs.size() != 0:
			questData.add_to_party(npcs.pick_random().node)
			approve_quest.visible = false
			questData.start();
		else:
			Debug.err("No NPC available in tavern.")
	else:
		Debug.err("Cannot start quest, no tavern was found.")
	
func _update_progress(state: String) -> void:
	label.text = state;             
	complete_quest.visible = questData.is_state(Quest.QuestState.COMPLETE);
