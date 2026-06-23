class_name CraftingUI
extends VBoxContainer

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
@onready var status_label: Label = $StatusLabel

var recipes: Array[ItemInfo] = []
var selected_item: ItemInfo
var result_slot_ui: ContentSlotUI
var _is_crafting := false

func _ready() -> void:
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_craft_selected_item)
	_create_result_slot()
	_rebuild_recipes()

func on_enter() -> void:
	_rebuild_recipes()

func _rebuild_recipes() -> void:
	recipes.clear()
	recipe_list.clear()
	selected_item = null

	if DataManager.instance == null:
		_refresh_recipe_preview()
		return

	for item in DataManager.instance.items:
		if item != null and item.has_recipe():
			recipes.append(item)
			recipe_list.add_item(item.get_display_name(), item.texture)

	if not recipes.is_empty():
		recipe_list.select(0)
		_select_recipe(0)
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
	for child in ingredients_grid.get_children():
		child.queue_free()

	if result_slot_ui:
		if selected_item:
			result_slot_ui.set_content(ContentSlotResource.new(1, selected_item, 1, true, false))
		else:
			result_slot_ui.set_content(ContentSlotResource.new(0, null, 1, true, false))

	if selected_item:
		for ingredient in selected_item.recipe:
			if ingredient is ItemInfo:
				var count := int(selected_item.recipe[ingredient])
				ingredients_grid.add_child(_create_preview_slot(ingredient, count))

		var missing := _get_missing_ingredients()
		craft_button.disabled = inventory == null or not missing.is_empty()
		status_label.text = _get_status_text(missing)
	else:
		craft_button.disabled = true
		status_label.text = tr("CRAFTING_NO_RECIPES")

func _create_result_slot() -> void:
	result_slot_ui = _create_preview_slot(null, 0)
	result_slot_container.add_child(result_slot_ui)

func _create_preview_slot(item: ItemInfo, count: int) -> ContentSlotUI:
	var slot: ContentSlotUI = packed_slot.instantiate()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.can_drag = false
	slot.set_content(ContentSlotResource.new(count, item, max(1, count), true, false))
	return slot

func _craft_selected_item() -> void:
	if inventory == null or selected_item == null:
		return

	if not _get_missing_ingredients().is_empty():
		_refresh_recipe_preview()
		return

	if not _can_fit_crafted_item():
		status_label.text = tr("CRAFTING_INVENTORY_FULL")
		return

	_is_crafting = true
	for ingredient in selected_item.recipe:
		if ingredient is ItemInfo:
			inventory.remove(ingredient, int(selected_item.recipe[ingredient]))

	var remaining := inventory.add(selected_item, 1)
	_is_crafting = false
	if remaining > 0:
		for ingredient in selected_item.recipe:
			if ingredient is ItemInfo:
				inventory.add(ingredient, int(selected_item.recipe[ingredient]))
		status_label.text = tr("CRAFTING_INVENTORY_FULL")
	else:
		status_label.text = tr("CRAFTING_SUCCESS") % selected_item.get_display_name()

	_refresh_recipe_preview()

func _get_missing_ingredients() -> Dictionary:
	var missing := {}
	if inventory == null or selected_item == null:
		return missing

	for ingredient in selected_item.recipe:
		if not (ingredient is ItemInfo):
			continue

		var required := int(selected_item.recipe[ingredient])
		var available := _get_item_count(ingredient)
		if available < required:
			missing[ingredient] = required - available
	return missing

func _can_fit_crafted_item() -> bool:
	if inventory == null or selected_item == null:
		return false

	if not inventory.get_available_slots(selected_item, true).is_empty():
		return true

	var remaining_recipe := selected_item.recipe.duplicate()
	for slot in inventory.data:
		if slot == null or not slot.is_unlocked:
			continue

		var content := slot.get_content()
		if not remaining_recipe.has(content):
			continue

		var remaining_required := int(remaining_recipe[content])
		if remaining_required >= slot.count:
			return true
		remaining_recipe[content] = remaining_required - slot.count

	return false

func _get_item_count(item: ItemInfo) -> int:
	var count := 0
	if inventory == null:
		return count

	for slot in inventory.data:
		if slot.get_content() == item:
			count += slot.count
	return count

func _get_status_text(missing: Dictionary) -> String:
	if selected_item == null:
		return tr("CRAFTING_NO_RECIPE_SELECTED")
	if inventory == null:
		return tr("CRAFTING_NO_INVENTORY")
	if missing.is_empty():
		return tr("CRAFTING_READY")

	var parts: Array[String] = []
	for item in missing:
		if item is ItemInfo:
			parts.append("%s x%s" % [item.get_display_name(), missing[item]])
	return tr("CRAFTING_MISSING") % ", ".join(parts)

func _on_inventory_changed() -> void:
	if _is_crafting:
		return
	_refresh_recipe_preview()
