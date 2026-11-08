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
var _is_crafting: bool:
	get:
		return is_instance_valid(Manager.instance) and Manager.instance.crafting.active_job != null

func _ready() -> void:
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_craft_selected_item)
	Manager.instance.crafting.changed.connect(_on_crafting_changed)
	Manager.instance.crafting.completed.connect(_on_crafting_completed)
	Manager.instance.crafting.failed.connect(_on_crafting_failed)
	Manager.instance.regional.changed.connect(_rebuild_recipes)
	_create_result_slot()
	_rebuild_recipes()

func on_enter() -> void:
	_rebuild_recipes()

func _rebuild_recipes() -> void:
	var preferred := selected_item
	var job := Manager.instance.crafting.active_job
	if job != null and job.inventory == inventory: preferred = job.item
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
	if _is_crafting:
		var job := Manager.instance.crafting.active_job
		if job.inventory == inventory:
			selected_item = job.item
			var active_index := recipes.find(selected_item)
			if active_index >= 0: recipe_list.select(active_index)
		_refresh_recipe_preview()
		return
	if index < 0 or index >= recipes.size():
		selected_item = null
	else:
		selected_item = recipes[index]
	_refresh_recipe_preview()

func _on_recipe_selected(index: int) -> void:
	_select_recipe(index)

func _refresh_recipe_preview() -> void:
	recipe_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if _is_crafting else Control.MOUSE_FILTER_STOP
	recipe_list.focus_mode = Control.FOCUS_NONE if _is_crafting else Control.FOCUS_ALL
	for child in ingredients_grid.get_children():
		child.queue_free()

	if result_slot_ui:
		if selected_item:
			result_slot_ui.set_content(ContentSlotResource.new(1, selected_item, 1, true, false))
		else:
			result_slot_ui.set_content(ContentSlotResource.new(0, null, 1, true, false))

	if selected_item:
		var recipe: Dictionary[ItemInfo, int] = _get_recipe_copy(selected_item)
		for ingredient: ItemInfo in recipe:
			var count: int = recipe[ingredient]
			ingredients_grid.add_child(_create_preview_slot(ingredient, count))

		var missing: Dictionary[ItemInfo, int] = _get_missing_ingredients()
		craft_button.disabled = _is_crafting or inventory == null or not missing.is_empty()
		if not _is_crafting:
			_set_status(_get_status_text(missing))
	else:
		craft_button.disabled = true
		if not _is_crafting:
			_set_status(tr("CRAFTING_NO_RECIPES"))
	if _is_crafting:
		_set_status("")
	craft_button.tooltip_text = tr("CRAFTING_DURATION") % Manager.instance.crafting.duration_for(selected_item) if selected_item != null else ""
	if preview_only:
		craft_button.disabled = false
		craft_button.tooltip_text = tr("CRAFTING_VISIT_FORGE")
	_update_progress()

func _process(_delta: float) -> void:
	_update_progress()

func _update_progress() -> void:
	var job := Manager.instance.crafting.active_job
	var active := job != null and job.inventory == inventory
	craft_progress.visible = active
	craft_progress.value = job.get_progress() if active else 0.0
	# The caption draws above the fill; the button retains its normal idle text.
	craft_progress_text.text = tr("CRAFTING_PROGRESS") % floori(craft_progress.value * 100.0) if active else ""
	craft_button.text = "" if active else tr("CRAFTING_FIND_FORGE" if preview_only else "CRAFTING_CRAFT")

func _on_crafting_changed() -> void:
	_refresh_recipe_preview()

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
	if _is_crafting or inventory == null or selected_item == null:
		return

	if not _get_missing_ingredients().is_empty():
		_refresh_recipe_preview()
		return

	if not _can_fit_crafted_item():
		_set_status(tr("CRAFTING_INVENTORY_FULL"))
		return

	if not Manager.instance.crafting.start(selected_item, inventory):
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
	return Manager.instance.crafting.can_fit_output(selected_item, inventory)

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
	var recipe: Dictionary[ItemInfo, int] = {}
	if item == null:
		return recipe
	for ingredient: ItemInfo in item.recipe:
		recipe[ingredient] = int(item.recipe[ingredient])
	return recipe

func _on_inventory_changed() -> void:
	if _is_crafting:
		return
	_refresh_recipe_preview()
