class_name CraftingManager
extends Node

signal changed()
signal progress_changed()
signal completed(item: ItemInfo, inventory: ContentGroup)
signal failed(message: String, inventory: ContentGroup)

const MAX_ORDERS := 8
var active_job: CraftingJob
var queued_jobs: Array[CraftingJob] = []
var last_error := ""
var _display_percent := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func start(item: ItemInfo, inventory: ContentGroup, quantity := 1) -> bool:
	last_error = ""
	quantity = clampi(quantity, 1, 99)
	if queued_jobs.size() + (1 if active_job != null else 0) >= MAX_ORDERS: last_error = tr("CRAFTING_QUEUE_FULL")
	elif inventory == null: last_error = tr("CRAFTING_NO_INVENTORY")
	elif item == null or not item.has_recipe(): last_error = tr("CRAFTING_NO_RECIPE_SELECTED")
	elif not Manager.instance.regional.recipe_available(item): last_error = tr("COMMUNITY_RECIPE_LOCKED")
	elif not inventory.has_all(ingredients_for(item, quantity)): last_error = tr("CRAFTING_NOT_ENOUGH_MATERIALS")
	elif not can_fit_output(item, inventory, quantity): last_error = tr("CRAFTING_INVENTORY_FULL")
	if not last_error.is_empty(): return false
	var job := CraftingJob.new()
	job.item = item
	job.inventory = inventory
	job.ingredients = item.recipe.duplicate()
	job.quantity = quantity
	job.duration = duration_for(item)
	# Occupy the queue before inventory signals can post another order.
	queued_jobs.append(job)
	var reserved := ContentGroup.new()
	var transferred := inventory.transfer_all_to(reserved, ingredients_for(item, quantity), true)
	reserved.free()
	if not transferred:
		queued_jobs.erase(job)
		last_error = tr("CRAFTING_NOT_ENOUGH_MATERIALS")
		return false
	_advance()
	changed.emit()
	return true

func ingredients_for(item: ItemInfo, quantity := 1) -> Dictionary[ItemInfo, int]:
	var result: Dictionary[ItemInfo, int] = {}
	if item != null:
		for ingredient: ItemInfo in item.recipe: result[ingredient] = item.recipe[ingredient] * quantity
	return result

func duration_for(item: ItemInfo) -> float:
	return maxf(0.05, item.crafting_duration * Manager.instance.regional.crafting_multiplier(item.unique_id))

func _advance() -> void:
	if active_job == null and not queued_jobs.is_empty():
		active_job = queued_jobs.pop_front()
		_display_percent = -1

func _process(delta: float) -> void:
	if SaveGames.is_loading: return
	if active_job == null:
		_advance()
		if active_job == null: return
		changed.emit()
	active_job.elapsed = minf(active_job.duration, active_job.elapsed + delta)
	var percent := floori(active_job.get_progress() * 100.0)
	if percent != _display_percent:
		_display_percent = percent
		progress_changed.emit()
	if active_job.elapsed >= active_job.duration: _finish_unit()

func _finish_unit() -> void:
	var job := active_job
	if job == null: return
	if not is_instance_valid(job.inventory) or job.inventory.add(job.item, 1) != 0:
		_refund(job)
		active_job = null
		last_error = tr("CRAFTING_REFUNDED")
		_advance()
		changed.emit()
		Manager.instance.toast.notify(last_error, GameUI.WARNING)
		failed.emit(last_error, job.inventory)
		return
	job.produced += 1
	job.elapsed = 0.0
	_display_percent = -1
	Manager.instance.journal.complete_task("craft_" + job.item.unique_id)
	if job.remaining() == 0:
		active_job = null
		_advance()
		Manager.instance.toast.notify_rewards(tr("CRAFTING_CRAFT"), {job.item: job.quantity})
		completed.emit(job.item, job.inventory)
	changed.emit()

func cancel_order(index: int = -1) -> void:
	var job: CraftingJob
	if index == -1:
		job = active_job
		active_job = null
	elif index >= 0 and index < queued_jobs.size():
		job = queued_jobs[index]
		queued_jobs.remove_at(index)
	if job == null: return
	_refund(job)
	_advance()
	changed.emit()

func _refund(job: CraftingJob) -> void:
	if not is_instance_valid(job.inventory): return
	for ingredient: ItemInfo in job.ingredients:
		job.inventory.add(ingredient, job.ingredients[ingredient] * job.remaining(), true)

func can_fit_output(item: ItemInfo, inventory: ContentGroup, quantity := 1) -> bool:
	if inventory == null or item == null: return false
	# Simulate consumption and output, including partial stacks and multi-unit orders.
	var preview := ContentGroup.new(inventory.stack_size)
	for slot: ContentSlotResource in inventory.data:
		preview.add_slot(slot.duplicate())
	for ingredient: ItemInfo in item.recipe: preview.remove(ingredient, item.recipe[ingredient] * quantity)
	var fits := preview.add(item, quantity) == 0
	preview.free()
	return fits

func capture_state(codec: SaveCodec) -> Dictionary[String, Variant]:
	return codec.fields(self, ["active_job", "queued_jobs"])

func restore_state(data: Dictionary[String, Variant], codec: SaveCodec) -> void:
	codec.apply_fields(self, data)
	_display_percent = -1
	changed.emit()
