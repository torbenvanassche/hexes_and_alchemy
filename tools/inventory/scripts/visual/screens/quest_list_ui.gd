class_name QuestListUI extends VBoxContainer

@onready var create_quest_button: Button = $"../CreateQuestButton"

@export var quest_item_ui: PackedScene
var window_instance: SceneInstance;

func add_quest(quest: Quest) -> void:
	var instance: QuestListItemUI = quest_item_ui.instantiate();
	self.add_child(instance);
	instance.set_data(quest);
	
	instance.remove_quest.pressed.connect(remove_child.bind(instance))
	
func _ready() -> void:
	create_quest_button.pressed.connect(_open_create_quest_menu)
	
func _open_create_quest_menu() -> void:
	if can_open_creation_menu():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded)
	
func can_open_creation_menu() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	quest_creation.quest_created.connect(add_quest)
	window_instance.on_enter.emit();
