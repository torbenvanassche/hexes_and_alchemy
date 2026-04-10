class_name QuestListItemUI extends Control

@onready var quest_type: OptionButton = $QuestType
@onready var quest_number: Label = $QuestNumber
@onready var quest_location: OptionButton = $QuestLocation
@onready var quest_supplies: HBoxContainer = $QuestSupplies

@export var supply_slot: PackedScene;

var questData: Quest;

func set_data(quest: Quest) -> void:
	questData = quest;
	
	quest_number.text = "%s." % [str(self.get_parent().get_child_count())];
	for state in Quest.Type.keys():
		quest_type.add_item(state, Quest.Type[state])

	for supply_item in questData.supplies.data:
		var slot: ContentSlotUI = supply_slot.instantiate();
		slot.custom_minimum_size = Vector2i(30, 30);
		slot.show_amount = false;
		slot.can_drag = false;
		
		slot.set_content(supply_item);
		quest_supplies.add_child(slot);
