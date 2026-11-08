class_name CraftingManager
extends Node

signal changed()
signal completed(item: ItemInfo, inventory: ContentGroup)
signal failed(message: String, inventory: ContentGroup)

var active_job: CraftingJob
var last_error := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func start(item: ItemInfo, inventory: ContentGroup) -> bool:
	last_error = ""
	if active_job != null: last_error = tr("CRAFTING_BUSY")
	elif inventory == null: last_error = tr("CRAFTING_NO_INVENTORY")
	elif item == null or not item.has_recipe(): last_error = tr("CRAFTING_NO_RECIPE_SELECTED")
	elif not Manager.instance.regional.recipe_available(item): last_error = tr("COMMUNITY_RECIPE_LOCKED")
	elif not inventory.has_all(item.recipe): last_error = tr("CRAFTING_NOT_ENOUGH_MATERIALS")
	elif not can_fit_output(item, inventory): last_error = tr("CRAFTING_INVENTORY_FULL")
	if not last_error.is_empty(): return false

	var job := CraftingJob.new()
	job.item = item
	job.inventory = inventory
	job.ingredients = item.recipe.duplicate()
	job.duration = duration_for(item)
	# Occupy the workshop before inventory signals can trigger another request.
	active_job = job
	var reserved := ContentGroup.new()
	var transferred := inventory.transfer_all_to(reserved, job.ingredients, true)
	reserved.free()
	if not transferred:
		active_job = null
		last_error = tr("CRAFTING_NOT_ENOUGH_MATERIALS")
		changed.emit()
		return false
	changed.emit()
	return true

func duration_for(item: ItemInfo) -> float:
	var multiplier := Manager.instance.regional.crafting_multiplier(item.unique_id)
	return maxf(0.05, item.crafting_duration * multiplier)

func _process(delta: float) -> void:
	if active_job == null or SaveGames.is_loading: return
	active_job.elapsed = minf(active_job.duration, active_job.elapsed + delta)
	if active_job.elapsed >= active_job.duration: _finish()

func _finish() -> void:
	var job := active_job
	if job == null: return
	# Keep the job occupied while the inventory emits its changes.
	var success := is_instance_valid(job.inventory) and job.inventory.add(job.item, 1) == 0
	if not success and is_instance_valid(job.inventory):
		for ingredient: ItemInfo in job.ingredients:
			job.inventory.add(ingredient, job.ingredients[ingredient], true)
	active_job = null
	changed.emit()
	if success:
		Manager.instance.journal.complete_task("craft_" + job.item.unique_id)
		Manager.instance.toast.notify_crafted_item(job.item)
		completed.emit(job.item, job.inventory)
	else:
		last_error = tr("CRAFTING_REFUNDED")
		Manager.instance.toast.notify(last_error, GameUI.WARNING)
		failed.emit(last_error, job.inventory)

func can_fit_output(item: ItemInfo, inventory: ContentGroup) -> bool:
	if inventory == null or item == null: return false
	if not inventory.get_available_slots(item, true).is_empty(): return true
	# Consuming an entire ingredient stack can make room for the output.
	var remaining: Dictionary[ItemInfo, int] = item.recipe.duplicate()
	for slot: ContentSlotResource in inventory.data:
		if slot == null or not slot.is_unlocked: continue
		var content := slot.get_content() as ItemInfo
		if content == null or not remaining.has(content): continue
		var needed := remaining[content]
		if needed >= slot.count: return true
		remaining[content] = needed - slot.count
	return false
