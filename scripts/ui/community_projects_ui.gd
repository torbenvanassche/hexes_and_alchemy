class_name CommunityProjectsUI
extends VBoxContainer

const INCIDENT_REQUEST := "local_incident"
const FACT_ROW := preload("res://scenes/ui/components/request_fact_row.tscn")
const COIN := preload("res://sprites/items/HA_ICON_02_Coin.png")
const PRESTIGE := preload("res://sprites/ui/line/lucide/prestige.svg")
const REPUTATION := preload("res://sprites/ui/line/lucide/reputation.svg")
const CHECKED := preload("res://sprites/ui/line/checkbox_checked.svg")
const UNCHECKED := preload("res://sprites/ui/line/checkbox_empty.svg")

var request_id := "water"
var _refresh_gate: RefreshGate

@onready var title_label: Label = %Title
@onready var resident_label: Label = %Resident
@onready var request_label: Label = %Description
@onready var objectives: VBoxContainer = %Objectives
@onready var contribution: VBoxContainer = %Contribution
@onready var currency_costs: VBoxContainer = %CurrencyCosts
@onready var cost_card: PanelContainer = %Costs
@onready var reward_items: VBoxContainer = %RewardItems
@onready var status: Label = %Status
@onready var work: Button = %Work
@onready var complete: Button = %Complete
@onready var fund: Button = %Fund
@onready var actions: HFlowContainer = %Actions
@onready var recipe: Button = %Recipe
@onready var forge: Button = %Forge

func _ready() -> void:
	_refresh_gate = RefreshGate.new(self, refresh)
	work.pressed.connect(_open_work)
	complete.pressed.connect(_complete)
	recipe.pressed.connect(_view_recipe)
	fund.pressed.connect(_fund)
	forge.pressed.connect(_open_forge_project)
	Manager.instance.regional.changed.connect(_queue_refresh)
	Manager.instance.hub.changed.connect(_queue_refresh)
	refresh()

func select_request(id: String) -> void:
	request_id = id
	if id != INCIDENT_REQUEST:
		Manager.instance.regional.selected_project = id

func _queue_refresh() -> void:
	_refresh_gate.request()

func refresh() -> void:
	if not is_node_ready() or not is_visible_in_tree() or is_queued_for_deletion() or SaveGames.is_loading:
		return
	for container: Container in [objectives, contribution, currency_costs, reward_items]:
		_clear(container)
	var regional := Manager.instance.regional
	if request_id == INCIDENT_REQUEST:
		_refresh_incident(regional)
		return

	var definition := regional.get_definition(request_id)
	if definition == null:
		return
	var state := regional.projects[request_id]
	title_label.text = definition.get_title()
	resident_label.text = "%s · %s" % [definition.resident_name, tr(definition.resident_role_key)]
	request_label.text = tr(definition.complete_key if state.completed else definition.request_key)
	%Benefit.text = tr(definition.benefit_key)
	_refresh_steps(ProjectProgress.stages(definition, state, regional))
	_refresh_costs(definition, state, regional)
	_refresh_rewards(definition)
	_refresh_project_actions(definition, state, regional)

func _refresh_steps(stages: Array[Dictionary]) -> void:
	var finished := 0
	var next_found := false
	for stage: Dictionary in stages:
		var done := bool(stage.done)
		var next := not done and not next_found
		next_found = next_found or next
		finished += int(done)
		var text := str(stage.text)
		var label := tr("QUEST_REQUEST_NEXT_STEP") % text if next else text
		var row := _fact(objectives, CHECKED if done else UNCHECKED, label)
		if next:
			var fact_label: Label = row.get_node("Fact")
			fact_label.add_theme_color_override("font_color", get_theme_color("font_color", &"SectionHeading"))

	%StepCount.text = tr("QUEST_REQUEST_PROGRESS") % [finished, stages.size()]
	%Progress.max_value = maxi(1, stages.size())
	%Progress.value = finished

func _refresh_costs(definition: CommunityProjectDefinition, state: CommunityProjectState, regional: RegionalProgression) -> void:
	cost_card.visible = not state.completed
	if state.completed:
		return
	var hub := Manager.instance.hub
	%ContributionHeading.text = "QUEST_REQUEST_COSTS"
	var remaining := regional.remaining_materials(request_id)
	%AmountsHeading.visible = not remaining.is_empty() or (not state.blueprint_issued and (definition.coin_cost > 0 or definition.prestige_cost > 0))
	for item: ItemInfo in remaining:
		var needed := int(remaining[item])
		_requirement(contribution, item.texture, item.get_display_name(), hub.stockpile.get_count(item), needed)
	if state.blueprint_issued:
		_fact(currency_costs, null, tr("PROJECT_COSTS_PAID"))
	else:
		if definition.coin_cost > 0:
			_requirement(currency_costs, COIN, tr("GUILD_COINS_LABEL"), hub.currency, definition.coin_cost)
		if definition.prestige_cost > 0:
			_requirement(currency_costs, PRESTIGE, tr("GUILD_PRESTIGE_LABEL"), hub.prestige, definition.prestige_cost)
		if remaining.is_empty() and definition.coin_cost == 0 and definition.prestige_cost == 0:
			_fact(contribution, null, tr("QUEST_REQUEST_NO_COSTS"))
	contribution.visible = contribution.get_child_count() > 0
	currency_costs.visible = currency_costs.get_child_count() > 0

func _refresh_rewards(definition: CommunityProjectDefinition) -> void:
	for item: ItemInfo in definition.reward_items:
		_fact(reward_items, item.texture, item.get_display_name(), "×%d" % int(definition.reward_items[item]))
	if definition.reputation_reward > 0:
		_fact(reward_items, REPUTATION, tr("GUILD_REPUTATION_LABEL"), "%+d" % definition.reputation_reward)
	if not definition.recipe_unlock.is_empty():
		var recipe_item := load("res://resources/item_info/%s.tres" % definition.recipe_unlock) as ItemInfo
		if recipe_item != null:
			_fact(reward_items, recipe_item.texture, tr("QUEST_REQUEST_RECIPE_REWARD") % recipe_item.get_display_name())
	%RewardsCard.visible = reward_items.get_child_count() > 0

func _refresh_project_actions(definition: CommunityProjectDefinition, state: CommunityProjectState, regional: RegionalProgression) -> void:
	var needs_forge := not state.completed and not regional.is_unlocked()
	forge.visible = needs_forge
	work.visible = not state.completed and not state.fieldwork_done
	fund.hide()
	work.text = "COMMUNITY_ARRANGE_WORK"
	work.tooltip_text = tr("QUEST_REQUEST_ASSIGN_HINT")
	var site := regional.get_project_work_site(request_id)
	if site == null:
		work.text = definition.exploration_key
		work.tooltip_text = tr("QUEST_REQUEST_EXPLORE_HINT")
	else:
		var available_types := site.get_filtered_quest_types()
		if not definition.commission_types.any(func(type: String) -> bool: return available_types.has(type)):
			work.text = "QUEST_REQUEST_PREPARE_SOURCE"
			work.tooltip_text = tr("QUEST_REQUEST_PREPARE_HINT")
	work.tooltip_text += "\n" + tr("REQUEST_MATCHING_WORK") + ": " + _commission_names(definition)

	var reason := regional.completion_block_reason(request_id)
	var has_blueprint := definition.construction != null and state.blueprint_issued
	var foundation_missing := regional.get_project_buildable(request_id) == null if has_blueprint else false
	complete.visible = not state.completed or (has_blueprint and foundation_missing)
	complete.disabled = not reason.is_empty() and not has_blueprint
	complete.text = "COMMUNITY_ISSUE_BLUEPRINT" if definition.construction != null else "QUEST_REQUEST_HAND_IN"
	if has_blueprint:
		complete.text = "COMMUNITY_PLACE_BLUEPRINT" if foundation_missing else "COMMUNITY_FIND_FOUNDATION"
	complete.tooltip_text = reason

	var needed := _needed_recipe() if not state.completed else null
	recipe.visible = needed != null
	if needed != null:
		recipe.tooltip_text = needed.get_tooltip_text()
	status.text = reason
	status.visible = not reason.is_empty() and (state.completed or (not needs_forge and not work.visible and complete.disabled))
	_style_actions()

func _refresh_incident(regional: RegionalProgression) -> void:
	var incident := regional.active_incident
	if incident == null:
		return
	var definition := incident.definition
	var author := regional.get_incident_requester()
	title_label.text = definition.get_title()
	resident_label.text = "%s · %s" % [author.resident_name, tr(author.resident_role_key)]
	request_label.text = tr(definition.description_key)
	%Benefit.text = tr("QUEST_REQUEST_RESTORE_SOURCE")
	_refresh_steps([{"text": tr("QUEST_REQUEST_REPAIR_SHORT"), "done": false}])
	%RewardsCard.show()
	_fact(reward_items, COIN, tr("GUILD_COINS_LABEL"), str(definition.coin_reward))
	cost_card.show()
	%ContributionHeading.text = "QUEST_REQUEST_INCIDENT_PAY"
	%AmountsHeading.show()
	contribution.hide()
	currency_costs.show()
	_requirement(currency_costs, COIN, tr("GUILD_COINS_LABEL"), Manager.instance.hub.currency, definition.funding_cost)
	forge.hide()
	recipe.hide()
	complete.hide()
	work.show()
	work.text = "COMMUNITY_ARRANGE_WORK"
	work.tooltip_text = tr("QUEST_REQUEST_ASSIGN_HINT")
	fund.show()
	fund.text = tr("COMMUNITY_FUND_INCIDENT") % definition.funding_cost
	fund.tooltip_text = tr("QUEST_REQUEST_INCIDENT_HELP") % definition.funding_cost
	fund.disabled = Manager.instance.hub.currency < definition.funding_cost
	status.hide()
	_style_actions()

func _style_actions() -> void:
	var has_primary := false
	for action: Button in [forge, work, complete, fund]:
		var primary := not has_primary and action.visible and not action.disabled
		action.theme_type_variation = &"PrimaryButton" if primary else &""
		has_primary = has_primary or primary

func _open_forge_project() -> void:
	var player := Manager.instance.player_instance
	if player != null:
		player.open_hub_tab("projects")

func _requirement(parent: Container, icon: Texture2D, label: String, owned: int, needed: int) -> void:
	var row := _fact(parent, icon, label, "%d / %d" % [owned, needed])
	row.tooltip_text = tr("QUEST_SUPPLY_COUNTS") % [needed, owned]
	var amount: Label = row.get_node("Amount")
	amount.theme_type_variation = &"StatusSuccessLabel" if owned >= needed else &"StatusWarningLabel"

func _fact(parent: Container, icon: Texture2D, label: String, amount := "") -> HBoxContainer:
	var row: HBoxContainer = FACT_ROW.instantiate()
	var sprite: TextureRect = row.get_node("Icon")
	sprite.texture = icon
	sprite.visible = icon != null
	row.get_node("Fact").text = label
	var amount_label: Label = row.get_node("Amount")
	amount_label.text = amount
	amount_label.visible = not amount.is_empty()
	parent.add_child(row)
	return row

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
