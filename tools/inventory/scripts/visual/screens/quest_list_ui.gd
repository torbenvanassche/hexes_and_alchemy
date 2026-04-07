class_name QuestListUI extends VBoxContainer

@export var quest_item_ui: PackedScene

func add_quest(quest: Quest) -> void:
	var instance: QuestListItemUI = quest_item_ui.instantiate();
	instance.set_data(quest);
	self.add_child(instance);

func on_enter() -> void:
	add_quest(Quest.new(Quest.Type.FETCH));
