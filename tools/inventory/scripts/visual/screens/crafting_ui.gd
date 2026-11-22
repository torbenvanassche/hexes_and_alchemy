class_name CraftingUI
extends VBoxContainer

signal item_crafted(item: ItemInfo)

@export var inventory: ContentGroup:
	set(value):
		if inventory and inventory.changed.is_connected(_on_inventory_changed):
			inventory.changed.disconnect(_on_inventory_changed)
		inventory = value
		if inventory and not inventory.changed.is_connected(_on_inventory_changed):
			inventory.changed.connect(_on_inventory_changed)
		if is_inside_tree():
			_rebuild_recipes()

@export var packed_slot: PackedScene
@export var slot_size: int = 72

@onready var recipe_list: ItemList = $RecipeList
@onready var ingredients_grid: GridContainer = $CraftingRows/IngredientsPanel/IngredientsGrid
@onready var result_slot_container: CenterContainer = $CraftingRows/ResultPanel/ResultSlot
@onready var craft_button: Button = $CraftButton
@onready var craft_progress: ProgressBar = $CraftButton/CraftProgress
@onready var craft_progress_text: Label = $CraftButton/CraftProgress/Caption
@onready var status_label: Label = $StatusLabel

var recipes: Array[ItemInfo] = []
var selected_item: ItemInfo
var result_slot_ui: ContentSlotUI
var preview_only := false
var quantity: SpinBox
var queue_rows: VBoxContainer
var _refresh_gate: RefreshGate
var _is_crafting: bool:
	get:
		return is_instance_valid(Manager.instance) and Manager.instance.crafting.active_job != null

func _ready() -> void:
	_refresh_gate = RefreshGate.new(self, _refresh_recipe_preview)
	_build_order_controls()
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_craft_selected_item)
	Manager.instance.crafting.changed.connect(_on_crafting_changed)
	Manager.instance.crafting.progress_changed.connect(_update_progress)
	Manager.instance.crafting.completed.connect(_on_crafting_completed)
	Manager.instance.crafting.failed.connect(_on_crafting_failed)
	Manager.instance.regional.changed.connect(_rebuild_recipes)
	_create_result_slot()
	_rebuild_recipes()

func on_enter() -> void:
	_rebuild_recipes()

func _rebuild_recipes() -> void:
	var preferred := selected_item
	recipes.clear()
	recipe_list.clear()
	selected_item = null

	if DataManager.instance == null:
		_refresh_recipe_preview()
		return

	for item in DataManager.instance.items:
		if item != null and item.has_recipe() and Manager.instance.regional.recipe_available(item):
			recipes.append(item)
			var needed := CraftingGuidance.needed_by(item)
			recipe_list.add_item(("• " if not needed.is_empty() else "") + item.get_display_name(), item.texture)
			recipe_list.set_item_tooltip(recipes.size() - 1, item.get_tooltip_text() + ("\n" + tr("CRAFTING_NEEDED_BY") + ": " + ", ".join(needed) if not needed.is_empty() else ""))

	if not recipes.is_empty():
		var index := recipes.find(preferred)
		if index < 0: index = 0
		recipe_list.select(index)
		_select_recipe(index)
	else:
		_refresh_recipe_preview()

func _select_recipe(index: int) -> void:
	if index < 0 or index >= recipes.size():
		selected_item = null
	else:
		selected_item = recipes[index]
	_refresh_recipe_preview()

func _on_recipe_selected(index: int) -> void:
	_select_recipe(index)

func _refresh_recipe_preview() -> void:
	if not is_node_ready(): return
	recipe_list.mouse_filter = Control.MOUSE_FILTER_STOP
	recipe_list.focus_mode = Control.FOCUS_ALL
	_refresh_queue()
	for child in ingredients_grid.get_children():
		child.queue_free()

	if result_slot_ui:
		if selected_item:
			result_slot_ui.set_content(ContentSlotResource.new(int(quantity.value), selected_item, 99, true, false))
		else:
			result_slot_ui.set_content(ContentSlotResource.new(0, null, 1, true, false))

	if selected_item:
		var recipe: Dictionary[ItemInfo, int] = _get_recipe_copy(selected_item)
		for ingredient: ItemInfo in recipe:
			var count: int = recipe[ingredient]
			ingredients_grid.add_child(_create_preview_slot(ingredient, count))

		var missing: Dictionary[ItemInfo, int] = _get_missing_ingredients()
		craft_button.disabled = inventory == null or not missing.is_empty() or Manager.instance.crafting.queued_jobs.size() + (1 if _is_crafting else 0) >= CraftingManager.MAX_ORDERS
		_set_status(_get_status_text(missing))
	else:
		craft_button.disabled = true
		_set_status(tr("CRAFTING_NO_RECIPES"))
	craft_button.tooltip_text = tr("CRAFTING_DURATION") % Manager.instance.crafting.duration_for(selected_item) if selected_item != null else ""
	if preview_only:
		craft_button.disabled = false
		craft_button.tooltip_text = tr("CRAFTING_VISIT_FORGE")
	_update_progress()

func _update_progress() -> void:
	if not is_node_ready() or not is_visible_in_tree(): return
	var job := Manager.instance.crafting.active_job
	var active := job != null and job.inventory == inventory
	craft_progress.visible = active
	craft_progress.value = job.get_progress() if active else 0.0
	# The caption draws above the fill; the button retains its normal idle text.
	craft_progress_text.text = tr("CRAFTING_PROGRESS") % floori(craft_progress.value * 100.0) if active else ""
	craft_button.text = tr("CRAFTING_FIND_FORGE" if preview_only else ("CRAFTING_ADD_ORDER" if _is_crafting else "CRAFTING_CRAFT"))
	if active: craft_progress_text.text += " · %d / %d" % [job.produced, job.quantity]

func _on_crafting_changed() -> void:
	_refresh_gate.request()

func _set_status(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()

func _on_crafting_completed(item: ItemInfo, source: ContentGroup) -> void:
	if source != inventory: return
	_refresh_recipe_preview()
	item_crafted.emit(item)

func _on_crafting_failed(message: String, source: ContentGroup) -> void:
	if source != inventory: return
	_refresh_recipe_preview()
	_set_status(message)

func _create_result_slot() -> void:
	result_slot_ui = _create_preview_slot(null, 0)
	result_slot_container.add_child(result_slot_ui)

func _create_preview_slot(item: ItemInfo, count: int) -> ContentSlotUI:
	return ItemPreview.create(item, count, slot_size, packed_slot)

func _craft_selected_item() -> void:
	if preview_only:
		Manager.instance.campaign.perform_action("blacksmith")
		return
	if inventory == null or selected_item == null:
		return

	if not _get_missing_ingredients().is_empty():
		_refresh_recipe_preview()
		return

	if not _can_fit_crafted_item():
		_set_status(tr("CRAFTING_INVENTORY_FULL"))
		return

	if not Manager.instance.crafting.start(selected_item, inventory, int(quantity.value)):
		_set_status(Manager.instance.crafting.last_error)

func _get_missing_ingredients() -> Dictionary[ItemInfo, int]:
	var missing: Dictionary[ItemInfo, int] = {}
	if inventory == null or selected_item == null:
		return missing

	var recipe: Dictionary[ItemInfo, int] = _get_recipe_copy(selected_item)
	for ingredient: ItemInfo in recipe:
		var required: int = recipe[ingredient]
		var available: int = _get_item_count(ingredient)
		if available < required:
			missing[ingredient] = required - available
	return missing

func _can_fit_crafted_item() -> bool:
	return Manager.instance.crafting.can_fit_output(selected_item, inventory, int(quantity.value))

func _get_item_count(item: ItemInfo) -> int:
	var count: int = 0
	if inventory == null:
		return count

	for slot: ContentSlotResource in inventory.data:
		if slot.get_content() == item:
			count += slot.count
	return count

func _get_status_text(missing: Dictionary[ItemInfo, int]) -> String:
	if selected_item == null:
		return tr("CRAFTING_NO_RECIPE_SELECTED")
	if inventory == null:
		return tr("CRAFTING_NO_INVENTORY")
	if missing.is_empty():
		return ""

	var parts: Array[String] = []
	for item: ItemInfo in missing:
		parts.append("%s x%s" % [item.get_display_name(), missing[item]])
	return tr("CRAFTING_MISSING") % ", ".join(parts)

func _get_recipe_copy(item: ItemInfo) -> Dictionary[ItemInfo, int]:
	return Manager.instance.crafting.ingredients_for(item, int(quantity.value))

func _on_inventory_changed() -> void:
	if _refresh_gate != null: _refresh_gate.request()

func _build_order_controls() -> void:
	craft_progress.reparent(self)
	craft_progress.custom_minimum_size.y = 22
	craft_progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
	move_child(craft_progress, craft_button.get_index())
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = tr("CRAFTING_QUANTITY")
	row.add_child(caption)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 99
	quantity.value = 1
	quantity.value_changed.connect(func(_value: float) -> void: _refresh_gate.request())
	row.add_child(quantity)
	add_child(row)
	move_child(row, craft_button.get_index())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 72
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_rows = VBoxContainer.new()
	queue_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(queue_rows)
	add_child(scroll)
	move_child(scroll, craft_button.get_index())

func _refresh_queue() -> void:
	for child in queue_rows.get_children():
		queue_rows.remove_child(child)
		child.queue_free()
	var manager := Manager.instance.crafting
	if manager.active_job != null: _add_order_row(manager.active_job, -1)
	for index in manager.queued_jobs.size(): _add_order_row(manager.queued_jobs[index], index)
	quantity.get_parent().visible = not preview_only
	queue_rows.get_parent().visible = not preview_only and queue_rows.get_child_count() > 0

func _add_order_row(job: CraftingJob, index: int) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = ("%s · " % tr("CRAFTING_ACTIVE") if index == -1 else "") + "%s × %d / %d" % [job.item.get_display_name(), job.produced, job.quantity]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var cancel := Button.new()
	cancel.text = tr("CRAFTING_CANCEL_ORDER")
	cancel.tooltip_text = tr("CRAFTING_CANCEL_REFUND")
	cancel.pressed.connect(manager_cancel.bind(index))
	row.add_child(cancel)
	queue_rows.add_child(row)

func manager_cancel(index: int) -> void:
	Manager.instance.crafting.cancel_order(index)
