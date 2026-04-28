class_name QuestListItemUI extends Control

@onready var quest_type: Label = $QuestType
@onready var quest_number: Label = $QuestNumber
@onready var quest_location: Label = $QuestLocation
@onready var quest_supplies: HBoxContainer = $QuestSupplies
@onready var remove_quest: Button = $RemoveQuest

@export var supply_slot: PackedScene;

var questData: Quest;

func set_data(quest: Quest) -> void:
	questData = quest;
	
	quest_number.text = "%s." % [str(self.get_parent().get_child_count())];
	quest_type.text = quest.Type.find_key(quest.quest_type);
	quest_location.text = quest.location.structure.structure_info.id;

	for supply_item in questData.supplies.data:
		var slot: ContentSlotUI = supply_slot.instantiate();
		slot.custom_minimum_size = Vector2i(30, 30);
		slot.show_amount = false;
		slot.can_drag = false;
		
		slot.set_content(supply_item);
		quest_supplies.add_child(slot);
