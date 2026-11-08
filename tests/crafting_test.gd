extends Node

const WOOD := preload("res://resources/item_info/wood_raw.tres")
var plank := preload("res://resources/item_info/wood_log.tres")
const IRON := preload("res://resources/item_info/iron_ore.tres")
var failures: Array[String] = []
var completions := 0
var refunds := 0
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 90000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("CRAFTING TEST timed out")
		get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _open() -> DraggableControl:
	Manager.instance.active_settlement.get_service(&"Blacksmith").interact()
	var info := DataManager.instance.get_scene_by_name("crafting_ui")
	while info.get_live_instances().is_empty(): await get_tree().process_frame
	for frame in 4: await get_tree().process_frame
	return info.get_live_instances()[0].node as DraggableControl

func _reload(label: String) -> void:
	check(SaveGames.save_slot(label), "Cannot save crafting: " + SaveGames.last_error)
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot load crafting: " + SaveGames.last_error)
	var result: Array = await SaveGames.load_finished
	check(result[0], "Crafting save failed to restore")

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	check(SaveGames.load_development_checkpoint("blacksmith"), "Cannot load blacksmith checkpoint")
	await SaveGames.load_finished
	check(Manager.instance.crafting.active_job == null, "Legacy checkpoint acquired an active craft")
	for item: ItemInfo in DataManager.instance.items:
		check(is_equal_approx(item.crafting_duration, 1.0), "Default item duration is not one second: " + item.unique_id)
	var window := await _open()
	var ui := window.content as CraftingUI
	ui._select_recipe(ui.recipes.find(plank))
	var before_wood := ui.inventory.get_count(WOOD)
	var before_planks := ui.inventory.get_count(plank)
	var original_duration := plank.crafting_duration
	# A longer test recipe lets the UI close/reopen and save at partial progress.
	plank.crafting_duration = 2.0
	ui.craft_button.pressed.emit()
	check(Manager.instance.crafting.active_job != null and ui.craft_button.disabled, "Craft did not start or disable its button")
	check(ui.inventory.get_count(WOOD) == before_wood - 2 and ui.inventory.get_count(plank) == before_planks, "Crafting consumed/output materials at the wrong time")
	ui.craft_button.pressed.emit()
	check(ui.inventory.get_count(WOOD) == before_wood - 2, "Repeated click reserved ingredients twice")
	var other := ui.recipes.find(load("res://resources/item_info/field_kit.tres"))
	ui._select_recipe(other)
	check(ui.selected_item == plank, "Recipe changed during a running craft")
	while Manager.instance.crafting.active_job.get_progress() < 0.35: await get_tree().process_frame
	check(ui.craft_progress.visible and ui.craft_progress.value > 0.0 and ui.craft_progress.value < 1.0, "Craft button does not show partial progress")
	check(ui.craft_button.get_global_rect().encloses(ui.craft_progress.get_global_rect()), "Progress bar exceeds craft button")
	await _capture("blacksmith-crafting-progress")
	get_tree().paused = true
	var paused_elapsed := Manager.instance.crafting.active_job.elapsed
	for frame in 6: await get_tree().process_frame
	check(is_equal_approx(Manager.instance.crafting.active_job.elapsed, paused_elapsed), "Crafting continues while paused")
	get_tree().paused = false
	window.close_window(true)
	var hidden_elapsed := Manager.instance.crafting.active_job.elapsed
	for frame in 5: await get_tree().process_frame
	check(not window.visible and Manager.instance.crafting.active_job.elapsed > hidden_elapsed, "Closing the blacksmith stopped crafting")
	var saved_elapsed := Manager.instance.crafting.active_job.elapsed
	plank.crafting_duration = 10.0
	await _reload("Crafting in progress")
	var manager := Manager.instance
	check(manager.crafting.active_job != null, "Craft was lost on load")
	check(absf(manager.crafting.active_job.elapsed - saved_elapsed) < 0.15 and is_equal_approx(manager.crafting.active_job.duration, 2.0), "Loading restarted the timer or used a changed item duration")
	check(manager.hub.stockpile.get_count(WOOD) == before_wood - 2 and manager.hub.stockpile.get_count(plank) == before_planks, "Loading duplicated ingredients or output")
	manager.crafting.completed.connect(func(_item: ItemInfo, _source: ContentGroup) -> void: completions += 1)
	window = await _open()
	ui = window.content as CraftingUI
	check(ui.selected_item == plank and ui.craft_progress.visible, "Reopening did not restore the active recipe and progress")
	while manager.crafting.active_job != null: await get_tree().process_frame
	for frame in 2: await get_tree().process_frame
	check(completions == 1 and manager.hub.stockpile.get_count(plank) == before_planks + 1, "Craft completed more than once or produced the wrong item")
	check(not ui.craft_progress.visible and ui.craft_button.text == tr("CRAFTING_CRAFT"), "Craft button did not reset")
	var message := tr("NOTICE_CRAFTED") % plank.get_display_name()
	check(not ui.status_label.visible, "Completion is repeated beneath the craft button")
	check(manager.toast.active_notifications.any(func(toast: ToastNotificationUI) -> bool: return toast.message.text == message and toast.icon.texture == plank.texture), "Craft completion notification/icon missing")
	await _capture("blacksmith-crafting-complete")
	await _reload("Crafting completed")
	manager = Manager.instance
	check(manager.crafting.active_job == null and manager.hub.stockpile.get_count(plank) == before_planks + 1, "Loading completed work replayed it")
	plank.crafting_duration = 0.1
	# A delivery can fill the freed inventory slot while crafting is in progress.
	# In that case the reserved materials must return rather than disappear.
	var limited := ContentGroup.new(99)
	limited.add(WOOD, 2, true)
	check(manager.crafting.start(plank, limited), "Craft did not account for an ingredient stack freeing an output slot")
	check(limited.add(IRON, 99) == 0, "Cannot fill the reserved output slot for refund check")
	manager.crafting.failed.connect(func(_message: String, _source: ContentGroup) -> void: refunds += 1)
	while manager.crafting.active_job != null: await get_tree().process_frame
	check(refunds == 1 and limited.get_count(WOOD) == 2 and limited.get_count(IRON) == 99 and limited.get_count(plank) == 0, "Failed output lost ingredients or duplicated goods")
	limited.free()
	var empty := ContentGroup.new()
	check(not manager.crafting.start(plank, empty) and manager.crafting.active_job == null, "Craft accepted missing materials")
	empty.free()
	plank.crafting_duration = original_duration
	print("CRAFTING TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
