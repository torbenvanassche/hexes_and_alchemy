class_name BuildRequest extends Interaction

@export var quest: FetchQuest;
var window_instance: SceneInstance;

signal completed();

func interact() -> void:
	DataManager.instance.get_scene_by_name("deposit_ui").queue(_open_window)
	
func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _open_window(window_info: SceneInfo) -> void:
	quest.initialize();
	
	window_instance = SceneManager.add(window_info, false);
	var dep_ui: DepositUI = (window_instance.node as DraggableControl).content as DepositUI;
	dep_ui.inventory = quest.progress_tracker;
	if not dep_ui.complete_order.pressed.is_connected(completed.emit):
		dep_ui.complete_order.pressed.connect(completed.emit);
	window_instance.on_enter.emit();

func _on_area_exit(other: Area3D) -> void:
	if window_instance:
		window_instance.hide();
	super(other);
