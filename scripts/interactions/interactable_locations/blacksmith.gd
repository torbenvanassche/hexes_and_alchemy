class_name Blacksmith extends SettlementService

func interact() -> void:
	var crafting_window: SceneInfo = DataManager.instance.get_scene_by_name("crafting_ui")
	if crafting_window == null:
		return
	crafting_window.queue(_open_window)

func _on_visibility_changed() -> void:
	super._on_visibility_changed()
	if is_visible_in_tree() and journal_quest != null and Manager.instance != null and Manager.instance.journal != null:
		Manager.instance.journal.complete_task(journal_quest.id)

func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)

func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false)
	var draggable_window: DraggableControl = window_instance.node as DraggableControl
	if draggable_window == null:
		return
	var crafting_ui: CraftingUI = draggable_window.content as CraftingUI
	if crafting_ui == null:
		return
	var player: PlayerController = Manager.instance.player_instance
	crafting_ui.inventory = player.inventory if player != null else null
	if not crafting_ui.item_crafted.is_connected(_on_item_crafted):
		crafting_ui.item_crafted.connect(_on_item_crafted)
	window_instance.on_enter.emit()

func _on_item_crafted(_item: ItemInfo) -> void:
	Manager.instance.journal.complete_task("craft_" + _item.unique_id)

func _on_area_exit(other: Area3D) -> void:
	if window_instance:
		window_instance.hide()
	super(other)
