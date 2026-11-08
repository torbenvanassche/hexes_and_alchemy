class_name CommunityProjectsUI
extends VBoxContainer

const INCIDENT_REQUEST := "local_incident"
const STAT := preload("res://scenes/ui/components/reward_stat.tscn")
const COIN := preload("res://sprites/items/coin_single.png")
const PRESTIGE := preload("res://sprites/ui/line/lucide/prestige.svg")
const REPUTATION := preload("res://sprites/ui/line/lucide/reputation.svg")
var request_id := "water"
var title_label: Label
var resident_label: Label
var request_label: Label
var objectives: HFlowContainer
var contribution: HFlowContainer
var currency_costs: HFlowContainer
var cost_column: VBoxContainer
var reward_items: HFlowContainer
var benefits: HFlowContainer
var contribution_heading: Label
var status: Label
var work: Button
var complete: Button
var fund: Button
var actions: HFlowContainer
var recipe: Button

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	title_label = _label(self, "", "Heading")
	title_label.add_theme_font_size_override("font_size", 20)
	resident_label = _label(self, "", "MutedLabel")
	resident_label.add_theme_font_size_override("font_size", 14)
	request_label = _label(self, "", "MutedLabel")
	request_label.hide()
	request_label.max_lines_visible = 1
	request_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objectives = HFlowContainer.new()
	objectives.tooltip_text = tr("QUEST_REQUEST_OBJECTIVES_SHORT")
	objectives.add_theme_constant_override("h_separation", 16)
	objectives.add_theme_constant_override("v_separation", 4)
	add_child(objectives)
	add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)
	cost_column = VBoxContainer.new()
	cost_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_column.add_theme_constant_override("separation", 8)
	columns.add_child(cost_column)
	contribution_heading = _label(cost_column, "QUEST_REQUEST_SUPPLIES", "MutedLabel")
	contribution = _flow(cost_column)
	currency_costs = _flow(cost_column)
	var rewards := VBoxContainer.new()
	rewards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards.add_theme_constant_override("separation", 8)
	columns.add_child(rewards)
	_label(rewards, "QUEST_REQUEST_REWARDS", "MutedLabel")
	reward_items = _flow(rewards)
	benefits = _flow(rewards)
	status = _label(self, "", "MutedLabel")
	actions = _flow()
	work = _button("COMMUNITY_ARRANGE_WORK", _open_work)
	work.tooltip_text = tr("QUEST_REQUEST_ASSIGN_HINT")
	complete = _button("QUEST_REQUEST_HAND_IN", _complete)
	recipe = _button("REQUEST_VIEW_RECIPE", _view_recipe)
	fund = _button("", _fund)
	Manager.instance.regional.changed.connect(refresh)
	Manager.instance.hub.changed.connect(refresh)
	refresh()

func _exit_tree() -> void:
	if not is_instance_valid(Manager.instance): return
	if is_instance_valid(Manager.instance.regional) and Manager.instance.regional.changed.is_connected(refresh):
		Manager.instance.regional.changed.disconnect(refresh)
	if is_instance_valid(Manager.instance.hub) and Manager.instance.hub.changed.is_connected(refresh):
		Manager.instance.hub.changed.disconnect(refresh)

func select_request(id: String) -> void:
	request_id = id
	if id != INCIDENT_REQUEST: Manager.instance.regional.selected_project = id
	refresh()

func refresh() -> void:
	if not is_inside_tree() or not is_node_ready() or is_queued_for_deletion() or SaveGames.is_loading: return
	for container: Container in [objectives, contribution, currency_costs, reward_items, benefits]: _clear(container)
	if request_id == INCIDENT_REQUEST:
		_refresh_incident()
		return
	var regional := Manager.instance.regional
	var definition := regional.get_definition(request_id)
	if definition == null: return
	var state := regional.projects[request_id]
	title_label.text = definition.get_title()
	resident_label.text = "%s · %s" % [definition.resident_name, tr(definition.resident_role_key)]
	request_label.text = tr(definition.complete_key if state.completed else definition.request_key)
	title_label.tooltip_text = request_label.text
	if not regional.is_unlocked(): _objective(tr("QUEST_REQUEST_FORGE_REQUIRED"), false)
	_objective(tr(definition.objective_key), state.fieldwork_done or state.completed)
	if definition.construction != null:
		_objective(tr("COMMUNITY_PLACE_WELL"), state.completed or regional.get_project_buildable(request_id) != null)
		_objective(tr("COMMUNITY_FINISH_WELL"), state.completed)
	contribution_heading.visible = not state.completed
	contribution_heading.text = tr("REQUEST_CONSTRUCTION_SUPPLIES" if definition.construction != null else "QUEST_REQUEST_SUPPLIES")
	contribution.visible = not state.completed
	cost_column.visible = not state.completed
	if not state.completed:
		var remaining := regional.remaining_materials(request_id)
		for item: ItemInfo in remaining:
			_item(contribution, item, remaining[item], true)
		_cost(COIN, definition.coin_cost, Manager.instance.hub.currency, "GUILD_COINS_LABEL")
		_cost(PRESTIGE, definition.prestige_cost, Manager.instance.hub.prestige, "GUILD_PRESTIGE_LABEL")
	for item: ItemInfo in definition.reward_items: _item(reward_items, item, definition.reward_items[item])
	_stat(reward_items, REPUTATION, "%+d" % definition.reputation_reward, "GUILD_REPUTATION_LABEL")
	if not definition.recipe_unlock.is_empty():
		var recipe := load("res://resources/item_info/%s.tres" % definition.recipe_unlock) as ItemInfo
		if recipe != null:
			var slot := _item(reward_items, recipe, 1)
			slot.counter.text = tr("QUEST_REQUEST_RECIPE")
			slot.tooltip_text = tr("QUEST_REQUEST_UNLOCK_RECIPE") % recipe.get_display_name() + "\n" + recipe.get_tooltip_text()
	for benefit: CommunityBenefit in definition.benefits:
		_stat(benefits, benefit.icon, benefit.value, benefit.label_key, tr(definition.benefit_key))
	status.text = tr("COMMUNITY_FINISHED") if state.completed else regional.completion_block_reason(request_id)
	status.visible = not status.text.is_empty()
	work.visible = not state.completed and not state.fieldwork_done
	var site := regional.get_project_work_site(request_id)
	work.text = tr("COMMUNITY_ARRANGE_WORK")
	work.tooltip_text = tr("QUEST_REQUEST_ASSIGN_HINT")
	if site == null:
		work.text = tr(definition.exploration_key)
		work.tooltip_text = tr("QUEST_REQUEST_EXPLORE_HINT")
	else:
		var ready := false
		for key: String in definition.commission_types:
			if site.get_filtered_quest_types().has(key): ready = true
		if not ready:
			work.text = tr("QUEST_REQUEST_PREPARE_SOURCE")
			work.tooltip_text = tr("QUEST_REQUEST_PREPARE_HINT")
	complete.visible = not state.completed or (definition.construction != null and state.blueprint_issued and regional.get_project_buildable(request_id) == null)
	complete.disabled = not regional.completion_block_reason(request_id).is_empty()
	complete.text = tr("COMMUNITY_ISSUE_BLUEPRINT") if definition.construction != null else tr("QUEST_REQUEST_HAND_IN")
	if definition.construction != null and state.blueprint_issued:
		complete.text = tr("COMMUNITY_PLACE_BLUEPRINT") if regional.get_project_buildable(request_id) == null else tr("COMMUNITY_FIND_FOUNDATION")
		complete.disabled = false
	complete.tooltip_text = regional.completion_block_reason(request_id)
	if complete.visible and state.completed: complete.tooltip_text = tr("COMMUNITY_BUILD_FOUNDATION")
	work.tooltip_text += "\n" + tr("REQUEST_MATCHING_WORK") + ": " + _commission_names(definition)
	fund.hide()
	recipe.visible = not state.completed and _needed_recipe() != null
	if recipe.visible: recipe.tooltip_text = _needed_recipe().get_tooltip_text()
	if state.blueprint_issued:
		currency_costs.hide()
	else: currency_costs.show()

func _refresh_incident() -> void:
	recipe.hide()
	var regional := Manager.instance.regional
	var incident := regional.active_incident
	work.visible = incident != null
	work.text = tr("COMMUNITY_ARRANGE_WORK")
	work.tooltip_text = tr("QUEST_REQUEST_ASSIGN_HINT")
	fund.visible = incident != null
	complete.hide()
	contribution_heading.hide()
	contribution.hide()
	cost_column.hide()
	if incident == null: return
	var definition := incident.definition
	var author := regional.get_incident_requester()
	title_label.text = definition.get_title()
	resident_label.text = "%s · %s" % [author.resident_name, tr(author.resident_role_key)]
	request_label.text = tr(definition.description_key)
	title_label.tooltip_text = request_label.text
	_objective(tr("QUEST_REQUEST_REPAIR_SHORT"), false)
	_stat(reward_items, COIN, str(definition.coin_reward), "GUILD_COINS_LABEL", tr("QUEST_REQUEST_INCIDENT_REWARD") % definition.coin_reward)
	_label(benefits, "QUEST_REQUEST_RESTORE_SOURCE", "MutedLabel")
	fund.text = tr("COMMUNITY_FUND_INCIDENT") % definition.funding_cost
	fund.tooltip_text = tr("QUEST_REQUEST_INCIDENT_HELP") % definition.funding_cost
	fund.disabled = Manager.instance.hub.currency < definition.funding_cost
	status.hide()

func _objective(text: String, done: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(168, 24)
	row.tooltip_text = text
	row.add_theme_constant_override("separation", 8)
	objectives.add_child(row)
	var icon := TextureRect.new()
	icon.texture = preload("res://sprites/ui/line/checkbox_checked.svg") if done else preload("res://sprites/ui/line/checkbox_empty.svg")
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := _label(row, text)
	label.add_theme_font_size_override("font_size", 14)

func _item(parent: Container, item: ItemInfo, amount: int, required := false) -> ContentSlotUI:
	var slot := ItemPreview.create(item, amount)
	parent.add_child(slot)
	slot.redraw()
	if required:
		var owned := Manager.instance.hub.stockpile.get_count(item)
		slot.counter.text = "%d/%d" % [owned, amount]
		slot.counter.visible = true
		slot.counter.modulate = GameUI.SUCCESS if owned >= amount else GameUI.WARNING
		slot.tooltip_text = "%s\n%s" % [item.get_display_name(), tr("QUEST_SUPPLY_COUNTS") % [amount, owned]]
	else:
		slot.counter.visible = true
		slot.counter.text = str(amount)
		slot.tooltip_text = "%s ×%d" % [item.get_display_name(), amount]
	return slot

func _cost(icon: Texture2D, amount: int, owned: int, label_key: String) -> void:
	var stat := _stat(currency_costs, icon, str(amount), label_key, tr("QUEST_SUPPLY_COUNTS") % [amount, owned])
	stat.get_node("Text/Value").modulate = GameUI.ACCENT if owned >= amount else GameUI.WARNING

func _stat(parent: Container, icon: Texture2D, value: String, label_key: String, hint := "") -> RewardStatUI:
	var stat := STAT.instantiate() as RewardStatUI
	stat.icon = icon
	stat.label_key = label_key
	stat.tooltip_text = hint
	parent.add_child(stat)
	stat.set_text_value(value)
	return stat

func _flow(parent: Node = self) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 8)
	parent.add_child(flow)
	return flow

func _label(parent: Node, text: String, variation := "") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not variation.is_empty(): label.theme_type_variation = variation
	if variation == "MutedLabel": label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	actions.add_child(button)
	return button

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _open_work() -> void:
	if request_id == INCIDENT_REQUEST: Manager.instance.regional.open_incident_work()
	else: Manager.instance.regional.open_project_work(request_id)

func _complete() -> void:
	var regional := Manager.instance.regional
	var definition := regional.get_definition(request_id)
	if definition.construction != null and regional.projects[request_id].blueprint_issued:
		regional.place_project(request_id)
	else: regional.complete_project(request_id)
	refresh()

func _needed_recipe() -> ItemInfo:
	var definition := Manager.instance.regional.get_definition(request_id)
	if definition == null: return null
	var remaining := Manager.instance.regional.remaining_materials(request_id)
	for item: ItemInfo in remaining:
		if item.has_recipe() and Manager.instance.hub.stockpile.get_count(item) < remaining[item]: return item
	return null

func _view_recipe() -> void:
	CraftingGuidance.view_recipe(_needed_recipe())

func _commission_names(definition: CommunityProjectDefinition) -> String:
	var names := PackedStringArray()
	for key: String in definition.commission_types:
		var label := tr("QUEST_TYPE_" + key.to_upper())
		if label.begins_with("QUEST_TYPE_"): label = key.replace("_", " ").capitalize()
		names.append(label)
	return ", ".join(names)

func _fund() -> void:
	var regional := Manager.instance.regional
	var success := regional.fund_incident() if request_id == INCIDENT_REQUEST else regional.complete_project(request_id, true)
	if not success:
		status.text = regional.last_error
		status.show()
	else: refresh()
