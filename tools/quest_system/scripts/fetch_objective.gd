class_name BuildRequest extends Interaction

@export var quest: FetchQuest;
@export_range(1, 10, 1) var required_settlement_level: int = 1

signal completed();

func interact() -> void:
	DataManager.instance.get_scene_by_name("deposit_ui").queue(_open_window)
	
func can_interact() -> bool:
	return _meets_level_requirement() and (not window_instance || not SceneManager.is_visible(window_instance))

func _meets_level_requirement() -> bool:
	if settlement != null:
		return settlement.level >= required_settlement_level
	var owner_settlement: Settlement = null
	if Manager.instance != null:
		owner_settlement = Manager.instance.get_settlement(self)
	return owner_settlement == null or owner_settlement.level >= required_settlement_level
	
func _open_window(window_info: SceneInfo) -> void:
	quest.initialize();
	
	window_instance = SceneManager.add(window_info, false);
	var deposit_panel := (window_instance.node as DraggableControl).content
	if deposit_panel == null:
		return
	var dep_ui: DepositUI = deposit_panel.get_node_or_null("InventoryHud") as DepositUI
	if dep_ui == null:
		return
	dep_ui.inventory = quest.progress_tracker;
	dep_ui.source_inventory = Manager.instance.player_instance.inventory;
	if not dep_ui.supplies_deposited.is_connected(completed.emit):
		dep_ui.supplies_deposited.connect(completed.emit);
	window_instance.on_enter.emit();
