class_name Blacksmith extends SettlementService

func interact() -> void:
	var crafting_window: SceneInfo = DataManager.instance.get_scene_by_name("crafting_ui")
	if crafting_window == null:
		return
	crafting_window.queue(_open_window)

func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)

func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false)
	_setup_ui_window(window_instance)
	var draggable_window: DraggableControl = window_instance.node as DraggableControl
	if draggable_window == null:
		return
	var crafting_ui: CraftingUI = draggable_window.content as CraftingUI
	if crafting_ui == null:
		return
	crafting_ui.preview_only = false
	crafting_ui.inventory = Manager.instance.hub.stockpile if Manager.instance != null and Manager.instance.hub != null else null
	window_instance.on_enter.emit()
	open_additional_ui_windows()
