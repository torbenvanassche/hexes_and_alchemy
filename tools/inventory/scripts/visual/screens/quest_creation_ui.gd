class_name QuestCreationUI extends Control

@onready var type_row: HBoxContainer = $MarginContainer/VBoxContainer/TypeRow
@onready var quest_type: OptionButton = $MarginContainer/VBoxContainer/TypeRow/QuestType
@onready var location_row: HBoxContainer = $MarginContainer/VBoxContainer/LocationRow
@onready var quest_location: OptionButton = $MarginContainer/VBoxContainer/LocationRow/QuestLocation
@onready var scout_distance_row: HBoxContainer = $MarginContainer/VBoxContainer/ScoutDistanceRow
@onready var scout_distance_spin_box: SpinBox = $MarginContainer/VBoxContainer/ScoutDistanceRow/ScoutDistance
@onready var scout_direction_row: HBoxContainer = $MarginContainer/VBoxContainer/ScoutDirectionRow
@onready var scout_direction_option: OptionButton = $MarginContainer/VBoxContainer/ScoutDirectionRow/ScoutDirection
@onready var minimum_rank_row: HBoxContainer = $MarginContainer/VBoxContainer/MinimumRankRow
@onready var minimum_rank_option: OptionButton = $MarginContainer/VBoxContainer/MinimumRankRow/MinimumRank
@onready var reward_offer_row: HBoxContainer = $MarginContainer/VBoxContainer/RewardOfferRow
@onready var reward_offer_spin_box: SpinBox = $MarginContainer/VBoxContainer/RewardOfferRow/RewardOfferAmount
@onready var interest_label: RichTextLabel = $MarginContainer/VBoxContainer/InterestLabel
@onready var active_quests_section: VBoxContainer = $MarginContainer/VBoxContainer/ActiveQuestsSection
@onready var active_quests_list: VBoxContainer = $MarginContainer/VBoxContainer/ActiveQuestsSection/ActiveQuestsList
@onready var details_panel: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel
@onready var description_top_divider: ColorRect = $MarginContainer/VBoxContainer/DetailsPanel/DescriptionTopDivider
@onready var description_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/DescriptionLabel
@onready var details_divider: ColorRect = $MarginContainer/VBoxContainer/DetailsPanel/DetailsDivider
@onready var meta_row: HBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow
@onready var duration_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/DurationBox
@onready var duration_title: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/DurationBox/DurationTitle
@onready var duration_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/DurationBox/DurationLabel
@onready var risk_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RiskBox
@onready var risk_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RiskBox/RiskLabel
@onready var reward_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RewardBox
@onready var reward_items: FlowContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RewardBox/RewardItems
@onready var reward_text_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/RewardBox/RewardText
@onready var context_box: VBoxContainer = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/ContextBox
@onready var context_label: Label = $MarginContainer/VBoxContainer/DetailsPanel/MetaRow/ContextBox/ContextLabel
@onready var quest_supplies: Control = $MarginContainer/VBoxContainer/QuestSupplies
@onready var supplies_grid: GridContainer = $MarginContainer/VBoxContainer/QuestSupplies/SuppliesGrid
@onready var quest_support: VBoxContainer = $MarginContainer/VBoxContainer/QuestSupport
@onready var support_options: VBoxContainer = $MarginContainer/VBoxContainer/QuestSupport/SupportOptions
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var actions_row: HBoxContainer = $MarginContainer/VBoxContainer/Actions
@onready var finish_quest_creation: Button = $MarginContainer/VBoxContainer/Actions/FinishQuestCreation
@onready var window: DraggableControl = $"../../../.."

@export var packed_slot: PackedScene
@export var support_row_scene: PackedScene
@export var slot_size: int = 56
@export var target_dropdown_max_height: int = 220

signal quest_created(quest: Quest)

const SCOUT_QUEST_KEY := "scout"

var forced_interaction: Interaction;
var scout_only := false
var _selected_support_ids: Array[String] = []
var _support_selection_context := ""
var _posting_service: QuestPostingService
var _target_selector: QuestTargetSelector

func _reset_ui() -> void:
	_apply_mode_visibility()
	quest_type.clear();
	quest_location.clear();
	quest_type.disabled = true;
	_clear_active_quest_cards()
	if minimum_rank_option != null:
		minimum_rank_option.clear()
		minimum_rank_option.disabled = true
	finish_quest_creation.disabled = true;
	if reward_offer_spin_box != null:
		reward_offer_spin_box.value = 0.0
	_refresh_reward_offer_limit()
	_set_details("")
	_set_status("")
	_set_interest_feedback("")
	_refresh_required_supplies()
	_clear_optional_supports()
	if finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.disconnect(_create_quest)

func _ready() -> void:
	_configure_location_dropdown()
	quest_location.item_selected.connect(_on_location_selected)
	quest_type.item_selected.connect(_on_quest_type_selected)
	if minimum_rank_option != null:
		minimum_rank_option.item_selected.connect(_on_minimum_rank_selected)
	if reward_offer_spin_box != null:
		reward_offer_spin_box.value_changed.connect(_on_reward_offer_changed)
	if scout_distance_spin_box != null:
		scout_distance_spin_box.value_changed.connect(_on_scout_distance_changed)
	if scout_direction_option != null:
		_setup_scout_direction_options()
		scout_direction_option.item_selected.connect(_on_scout_direction_selected)
	_connect_player_currency_signal()
	_refresh_reward_offer_limit()
	_request_window_refit()

func _configure_location_dropdown() -> void:
	var popup := quest_location.get_popup()
	if popup == null:
		return
	popup.max_size = Vector2i(4096, target_dropdown_max_height)

func clear_forced_data() -> void:
	forced_interaction = null
	scout_only = false
	_apply_mode_visibility()

func setup_scouting_request() -> void:
	forced_interaction = null
	scout_only = true
	_apply_mode_visibility()
	if is_inside_tree():
		_reset_ui()
		_connect_finish_button()
		_apply_scouting_request()

func force_data(interaction: Interaction) -> void:
	forced_interaction = interaction
	scout_only = false
	if is_inside_tree():
		_reset_ui()
		_connect_finish_button()
		_apply_forced_interaction()

func _connect_finish_button() -> void:
	if not finish_quest_creation.pressed.is_connected(_create_quest):
		finish_quest_creation.pressed.connect(_create_quest)

func _on_location_selected(idx: int) -> void:
	if idx == -1:
		_refresh_active_quests_for_location(null)
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		_set_details("")
		_set_status("")
		_set_interest_feedback("")
		_refresh_required_supplies()
		_clear_optional_supports()
		return;

	var location: HexBase = quest_location.get_item_metadata(idx) as HexBase;
	if location == null:
		_refresh_active_quests_for_location(null)
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		_set_details("")
		_set_status("")
		_set_interest_feedback("")
		_refresh_required_supplies()
		_clear_optional_supports()
		return;
	_refresh_active_quests_for_location(location)

	if _get_target_selector().is_scout_location(location):
		quest_type.clear()
		quest_type.add_item(_get_quest_type_label(SCOUT_QUEST_KEY))
		quest_type.set_item_metadata(0, SCOUT_QUEST_KEY)
		quest_type.disabled = true
		_refresh_minimum_rank_options()
		_refresh_quest_type_availability()
		_refresh_required_supplies()
		_refresh_optional_supports(true)
		_refresh_quest_details()
		_refresh_interest_feedback()
		_update_finish_button()
		return

	if location.structure == null:
		_refresh_active_quests_for_location(location)
		_set_creation_controls_visible(false)
		quest_type.clear()
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		_set_details("")
		_set_status("")
		_set_interest_feedback("")
		_refresh_required_supplies()
		_clear_optional_supports()
		return;

	quest_type.clear();
	var objective: QuestObjective = location.structure.instance as QuestObjective;
	if objective:
		var postable_types := _get_target_selector().get_postable_types(location)
		for state: String in postable_types:
			quest_type.add_item(_get_quest_type_label(state));
			quest_type.set_item_metadata(quest_type.item_count - 1, state)

	var has_types: bool = quest_type.item_count > 0
	_set_creation_controls_visible(has_types)
	if not has_types:
		quest_type.disabled = true
		finish_quest_creation.disabled = true
		_set_details("")
		_set_status("")
		_set_interest_feedback("")
		_refresh_required_supplies()
		_clear_optional_supports()
		return

	quest_type.disabled = not has_types;
	_select_first_creatable_quest_type(objective)
	_refresh_minimum_rank_options()
	_refresh_quest_type_availability()
	_refresh_required_supplies()
	_refresh_optional_supports(true)
	_refresh_quest_details()
	_refresh_interest_feedback()
	_update_finish_button()

func _on_quest_type_selected(_idx: int) -> void:
	_refresh_minimum_rank_options()
	_refresh_quest_type_availability()
	_refresh_required_supplies()
	_refresh_optional_supports(true)
	_refresh_quest_details()
	_refresh_interest_feedback()
	_update_finish_button()

func _on_minimum_rank_selected(_idx: int) -> void:
	_refresh_quest_type_availability()
	_refresh_quest_details()
	_refresh_interest_feedback()
	_update_finish_button()

func _on_reward_offer_changed(_value: float) -> void:
	_refresh_quest_type_availability()
	_select_first_creatable_quest_type(_get_selected_objective())
	_refresh_minimum_rank_options()
	_refresh_required_supplies()
	_refresh_optional_supports(false)
	_refresh_quest_details()
	_refresh_interest_feedback()
	_update_finish_button()

func _on_scout_distance_changed(_value: float) -> void:
	if not scout_only:
		return
	_apply_scouting_request()
	_request_window_refit()

func _on_scout_direction_selected(_idx: int) -> void:
	if not scout_only:
		return
	_apply_scouting_request()
	_request_window_refit()

func _on_player_currency_amount_changed() -> void:
	_refresh_reward_offer_limit()
	_refresh_quest_type_availability()
	_refresh_required_supplies()
	_refresh_optional_supports(false)
	_refresh_interest_feedback()
	_update_finish_button()

func _on_hub_faction_activity_changed() -> void:
	_refresh_optional_supports(false)
	_refresh_interest_feedback()

func _add_location_option(hex: HexBase, require_reachable: bool = true, allow_active_location: bool = false) -> bool:
	var selector := _get_target_selector()
	if selector.is_scout_location(hex):
		return false
	if not selector.can_offer_location(hex, require_reachable, allow_active_location):
		return false

	var distance := selector.get_distance(hex)
	quest_location.add_item(tr("QUEST_LOCATION_DISTANCE") % [hex.structure.structure_info.get_display_name(), distance])
	quest_location.set_item_metadata(quest_location.item_count - 1, hex)
	return true

func _apply_forced_interaction() -> void:
	quest_location.disabled = true;
	if forced_interaction == null:
		return

	if forced_interaction.hex == null:
		_set_details("")
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		return

	var grid := _get_target_selector().get_grid()
	if grid != null and not Manager.instance.quests.is_quest_location_reachable(forced_interaction.hex, grid):
		_set_details("")
		_set_status(tr("QUEST_CREATION_UNREACHABLE"))
		return

	if not _add_location_option(forced_interaction.hex, true, true):
		_set_details("")
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		return

	_set_status("")
	quest_location.select(0)
	_on_location_selected(0)

func _apply_scouting_request() -> void:
	quest_location.disabled = true
	quest_type.disabled = true
	quest_location.clear()
	quest_type.clear()
	var selector := _get_target_selector()
	var grid := selector.get_grid()
	if grid == null:
		_set_details("")
		_set_status(tr("QUEST_CREATION_NO_SCOUTING_AVAILABLE"))
		return

	_configure_scout_distance_limit()
	var scout_location := selector.resolve_scout_target(
		_get_requested_scout_direction(),
		_get_requested_scout_distance()
	)
	if scout_location == null:
		_set_details("")
		_set_status(tr("QUEST_CREATION_NO_SCOUTING_AVAILABLE"))
		return

	_set_status("")
	quest_location.add_item(tr("QUEST_LOCATION_SCOUT_SELECTED") % [
		_get_scout_direction_label(_get_requested_scout_direction()),
		selector.get_scout_distance(scout_location),
	])
	quest_location.set_item_metadata(0, scout_location)
	quest_location.select(0)
	quest_type.add_item(_get_quest_type_label(SCOUT_QUEST_KEY))
	quest_type.set_item_metadata(0, SCOUT_QUEST_KEY)
	quest_type.select(0)
	_refresh_minimum_rank_options()
	_refresh_quest_type_availability()
	_refresh_required_supplies()
	_refresh_optional_supports(true)
	_refresh_quest_details()
	_refresh_interest_feedback()
	_update_finish_button()

func on_enter() -> void:
	_reset_ui()
	_connect_finish_button()
	_connect_player_currency_signal()
	_refresh_reward_offer_limit()
	if scout_only:
		_apply_scouting_request()
		if window != null:
			window.request_fit_to_content();
		return
	if forced_interaction != null:
		_apply_forced_interaction()
		if window != null:
			window.request_fit_to_content();
		return

	quest_location.disabled = false;
	var selector := _get_target_selector()
	if selector.get_grid() == null:
		_on_location_selected(-1)
		return

	for hex in selector.get_available_quest_locations():
		_add_location_option(hex)

	if quest_location.item_count > 0:
		quest_location.select(0)
		_on_location_selected(0);
	else:
		_set_status(tr("QUEST_CREATION_NO_AVAILABLE_QUESTS"))
		_on_location_selected(-1);
	_refresh_interest_feedback()

	if window != null:
		window.request_fit_to_content();

func _create_quest() -> void:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return

	var reward_amount := _get_reward_offer_amount()
	if quest_type_key == SCOUT_QUEST_KEY:
		_create_scout_quest(location, reward_amount)
		return

	var objective := location.structure.instance as QuestObjective
	if objective == null or not _can_create_quest(location, objective, quest_type_key):
		_update_finish_button()
		return
	var minimum_rank_override := _get_minimum_rank_override()
	var quest_rank_experience := objective.get_quest_rank_experience_reward(quest_type_key, minimum_rank_override)
	var result := _get_posting_service().post_quest(
		location,
		quest_type_key,
		reward_amount,
		minimum_rank_override,
		quest_rank_experience,
		_selected_support_ids,
		_get_player_inventory()
	)
	if not result.success:
		_set_status(tr(result.message_key))
		_update_finish_button()
		return

	quest_created.emit(result.quest);
	if window != null:
		window.close_requested.emit();

func _get_quest_type_name(quest_type_key: String) -> String:
	if quest_type_key == SCOUT_QUEST_KEY:
		return tr("QUEST_TYPE_SCOUT")

	var objective := _get_selected_objective()
	if objective != null:
		var profile := objective.get_profile(quest_type_key)
		if profile != null:
			return profile.get_display_name()
	var translation_key := "QUEST_TYPE_%s" % [quest_type_key.to_upper()]
	var translated := tr(translation_key)
	if translated == translation_key:
		return quest_type_key.capitalize()
	return translated

func _get_quest_type_label(quest_type_key: String) -> String:
	return _get_quest_type_name(quest_type_key)

func _select_first_creatable_quest_type(objective: QuestObjective) -> void:
	if objective == null:
		return
	var location := quest_location.get_item_metadata(quest_location.selected) as HexBase
	for i in quest_type.item_count:
		var quest_type_key := _get_quest_type_key(i)
		if quest_type_key == "":
			continue
		if _can_create_quest(location, objective, quest_type_key):
			quest_type.select(i)
			return

	if quest_type.item_count > 0:
		quest_type.select(0)

func _refresh_minimum_rank_options() -> void:
	if minimum_rank_option == null:
		return

	var previous_rank := _get_minimum_rank_override()
	minimum_rank_option.clear()
	var selected := _get_selected_quest_type_and_objective()
	var objective := selected.get("objective") as QuestObjective
	var quest_type_key := str(selected.get("quest_type", ""))
	if quest_type_key == SCOUT_QUEST_KEY:
		for rank_index in range(int(AdventurerRank.Rank.F), int(AdventurerRank.get_max_rank()) + 1):
			var rank := AdventurerRank.clamp_rank(rank_index)
			minimum_rank_option.add_item(AdventurerRank.get_display_name(rank))
			minimum_rank_option.set_item_metadata(minimum_rank_option.item_count - 1, int(rank))
		minimum_rank_option.disabled = false
		_select_minimum_rank(previous_rank)
		return

	if objective == null or quest_type_key == "":
		minimum_rank_option.disabled = true
		return

	var profile_minimum := objective.get_quest_minimum_rank(quest_type_key)
	for rank_index in range(int(profile_minimum), int(AdventurerRank.get_max_rank()) + 1):
		var rank := AdventurerRank.clamp_rank(rank_index)
		minimum_rank_option.add_item(AdventurerRank.get_display_name(rank))
		minimum_rank_option.set_item_metadata(minimum_rank_option.item_count - 1, int(rank))

	minimum_rank_option.disabled = minimum_rank_option.item_count == 0
	if minimum_rank_option.item_count > 0:
		_select_minimum_rank(previous_rank)

func _select_minimum_rank(preferred_rank: int) -> void:
	if minimum_rank_option == null or minimum_rank_option.item_count == 0:
		return

	var fallback_index := 0
	for i in minimum_rank_option.item_count:
		var rank := int(minimum_rank_option.get_item_metadata(i))
		if preferred_rank >= 0 and rank >= preferred_rank:
			minimum_rank_option.select(i)
			return
	minimum_rank_option.select(fallback_index)

func _refresh_quest_type_availability() -> void:
	var location_idx: int = quest_location.selected
	if location_idx < 0:
		return

	var location := quest_location.get_item_metadata(location_idx) as HexBase
	if _get_target_selector().is_scout_location(location):
		for i in quest_type.item_count:
			quest_type.set_item_disabled(i, not _can_create_scout_quest(location))
		return

	if location == null or location.structure == null:
		return

	var objective := location.structure.instance as QuestObjective
	if objective == null:
		return

	for i in quest_type.item_count:
		var quest_type_key := _get_quest_type_key(i)
		quest_type.set_item_disabled(i, not _can_create_quest(location, objective, quest_type_key))

func _update_finish_button() -> void:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		finish_quest_creation.disabled = true
		return

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		finish_quest_creation.disabled = true
		return

	if quest_type_key == SCOUT_QUEST_KEY:
		if not _has_reward_budget():
			finish_quest_creation.disabled = true
			_set_status(tr("QUEST_CREATION_NOT_ENOUGH_COINS"))
			return
		_set_status("")
		finish_quest_creation.disabled = not _can_create_scout_quest(location)
		return

	if location.structure == null:
		finish_quest_creation.disabled = true
		return

	var objective := location.structure.instance as QuestObjective
	if not _has_reward_budget():
		finish_quest_creation.disabled = true
		_set_status(tr("QUEST_CREATION_NOT_ENOUGH_COINS"))
		return

	_set_status("")
	finish_quest_creation.disabled = not _can_create_quest(location, objective, quest_type_key)

func _can_create_quest(location: HexBase, objective: QuestObjective, quest_type_key: String) -> bool:
	if Manager.instance == null or Manager.instance.quests == null:
		return false
	if location == null or objective == null or quest_type_key == "":
		return false
	if not _has_reward_budget():
		return false
	if not objective.has_required_supplies(quest_type_key, _get_player_inventory()):
		return false
	return true

func _refresh_active_quests_for_location(location: HexBase) -> void:
	_clear_active_quest_cards()
	if active_quests_section == null or active_quests_list == null:
		return
	if Manager.instance == null or Manager.instance.quests == null or location == null:
		active_quests_section.visible = false
		_request_window_refit()
		return

	var quests := Manager.instance.quests.get_quests_for_location(location)
	for quest in quests:
		if quest == null:
			continue
		active_quests_list.add_child(_create_active_quest_row(quest))
		var state_callable := _on_active_location_quest_changed.bind(location)
		if not quest.state_machine.state_entered.is_connected(state_callable):
			quest.state_machine.state_entered.connect(state_callable)
		var completed_callable := _on_active_location_quest_completed.bind(location)
		if not quest.completed.is_connected(completed_callable):
			quest.completed.connect(completed_callable, CONNECT_ONE_SHOT)

	active_quests_section.visible = not active_quests_list.get_children().is_empty()
	_request_window_refit()

func _create_active_quest_row(quest: Quest) -> Control:
	var card := QuestActiveCardUI.new()
	card.setup(quest)
	card.claim_requested.connect(_claim_active_location_quest.bind(quest.location))
	return card

func _claim_active_location_quest(quest: Quest, location: HexBase) -> void:
	if quest == null:
		return
	quest.parse_reward()
	_close_status_if_no_claimable_quests.call_deferred(location)

func _close_status_if_no_claimable_quests(location: HexBase) -> void:
	if Manager.instance != null and Manager.instance.quests != null:
		for quest in Manager.instance.quests.get_quests_for_location(location):
			if quest != null and quest.is_state(Quest.QuestState.COMPLETE):
				return
	if window != null:
		window.close_requested.emit()

func _clear_active_quest_cards() -> void:
	if active_quests_list == null:
		return
	for child in active_quests_list.get_children():
		active_quests_list.remove_child(child)
		child.queue_free()
	if active_quests_section != null:
		active_quests_section.visible = false

func _on_active_location_quest_changed(_state: String, location: HexBase) -> void:
	if not is_inside_tree():
		return
	var selected_location: HexBase = null
	if quest_location != null and quest_location.selected >= 0:
		selected_location = quest_location.get_item_metadata(quest_location.selected) as HexBase
	if selected_location == location:
		_refresh_active_quests_for_location.call_deferred(location)

func _on_active_location_quest_completed(location: HexBase) -> void:
	if not is_inside_tree():
		return
	var selected_location: HexBase = null
	if quest_location != null and quest_location.selected >= 0:
		selected_location = quest_location.get_item_metadata(quest_location.selected) as HexBase
	if selected_location == location:
		_refresh_active_quests_for_location.call_deferred(location)

func _refresh_required_supplies() -> void:
	for child in supplies_grid.get_children():
		supplies_grid.remove_child(child)
		child.queue_free()

	var required_supplies := _get_selected_required_supplies()
	var has_visible_supplies := false
	for item: ItemInfo in required_supplies.keys():
		if item == null:
			continue
		var amount := int(required_supplies[item])
		if amount <= 0:
			continue
		var slot := _create_supply_slot(item, amount)
		supplies_grid.add_child(slot)
		slot.tooltip_text = _build_supply_tooltip(item, amount)
		has_visible_supplies = true

	quest_supplies.visible = has_visible_supplies
	_request_window_refit()

func _build_supply_tooltip(item: ItemInfo, required_amount: int) -> String:
	if item == null:
		return ""
	var lines: Array[String] = [item.get_display_name()]
	var inventory := _get_player_inventory()
	var available_amount := inventory.get_count(item) if inventory != null else 0
	lines.append(tr("QUEST_SUPPLY_COUNTS") % [required_amount, available_amount])
	var description_text := item.get_description()
	if description_text != "":
		lines.append(description_text)
	var effect_text := _get_selected_required_supply_effect(item)
	if effect_text != "" and effect_text != description_text:
		lines.append(tr("QUEST_SUPPLY_EFFECT") % [effect_text])
	return "\n".join(lines)

func _get_selected_required_supply_effect(item: ItemInfo) -> String:
	var profile := _get_selected_profile()
	return profile.get_required_supply_effect(item) if profile != null else ""

func _request_window_refit() -> void:
	if window == null:
		return

	if window.visible:
		if window.has_method("request_fit_to_content"):
			window.request_fit_to_content(2)
		else:
			window.call_deferred("_fit_to_content")

func _set_detail_value(label: Label, container: Control, message: String) -> bool:
	if label == null or container == null:
		return false
	label.text = message
	var should_show := message != ""
	label.visible = should_show
	container.visible = should_show
	return should_show

func _clear_reward_preview() -> void:
	if reward_items == null:
		return
	for child in reward_items.get_children():
		reward_items.remove_child(child)
		child.queue_free()

func _set_reward_preview(preview: Array[Dictionary]) -> bool:
	_clear_reward_preview()
	if reward_box == null or reward_items == null:
		return false

	var has_rewards := false
	for entry in preview:
		var item := entry.get("item") as ItemInfo
		if item == null:
			continue

		var min_amount := int(entry.get("min", 0))
		var max_amount := int(entry.get("max", 0))
		if max_amount <= 0:
			continue
		var slot := _create_reward_slot()
		reward_items.add_child(slot)

		_set_reward_slot(slot, item, min_amount, max_amount)
		has_rewards = true

	if reward_text_label != null:
		reward_text_label.text = ""
		reward_text_label.visible = false

	reward_box.visible = has_rewards
	return has_rewards

func _create_reward_slot() -> ContentSlotUI:
	var slot: ContentSlotUI = packed_slot.instantiate()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.can_drag = false
	return slot

func _set_reward_slot(slot: ContentSlotUI, item: ItemInfo, min_amount: int, max_amount: int) -> void:
	var range_text := _format_reward_range(min_amount, max_amount)
	var count := maxi(1, max_amount)
	slot.visible = true
	slot.set_content(ContentSlotResource.new(count, item, count, true, false))
	slot.redraw()
	if slot.counter != null:
		slot.counter.visible = true
		slot.counter.text = range_text
	slot.tooltip_text = "%s: %s" % [item.get_display_name(), range_text]

func _format_reward_range(min_amount: int, max_amount: int) -> String:
	var clamped_min := maxi(0, min_amount)
	var clamped_max := maxi(clamped_min, max_amount)
	if clamped_min == clamped_max:
		return str(clamped_max)
	return "%s-%s" % [clamped_min, clamped_max]

func _set_details(
	description: String,
	duration: String = "",
	risk: String = "",
	reward_preview: Array[Dictionary] = [],
	context: String = ""
) -> void:
	var has_description := false
	if description_label != null:
		description_label.text = description
		has_description = description != ""
		description_label.visible = has_description

	var has_duration := _set_detail_value(duration_label, duration_box, duration)
	var has_risk := _set_detail_value(risk_label, risk_box, risk)
	var has_reward := _set_reward_preview(reward_preview)
	var has_context := _set_detail_value(context_label, context_box, context)
	var has_detail_meta := has_duration or has_risk or has_reward or has_context

	if description_top_divider != null:
		description_top_divider.visible = has_description
	if details_divider != null:
		details_divider.visible = has_description
	if meta_row != null:
		meta_row.visible = has_detail_meta

	var has_details := has_description or has_detail_meta
	if details_panel != null:
		details_panel.visible = has_details
	_request_window_refit()

func _set_status(message: String) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.visible = message != ""
	_request_window_refit()

func _set_interest_feedback(message: String) -> void:
	if interest_label == null:
		return
	interest_label.text = message
	interest_label.visible = message != ""
	_request_window_refit()

func _refresh_interest_feedback() -> void:
	var interested_count := _get_interested_npc_count()
	if interested_count < 0:
		_set_interest_feedback("")
		return

	var availability_text := ""
	if interested_count == 0:
		availability_text = tr("QUEST_CREATION_INTEREST_NONE")
	elif interested_count == 1:
		availability_text = tr("QUEST_CREATION_INTEREST_ONE")
	else:
		availability_text = tr("QUEST_CREATION_INTEREST_COUNT") % [interested_count]

	var role_label := _get_role_display_name(_get_selected_required_role())
	var highlighted_role := "[b][color=#8A451A]%s[/color][/b]" % [role_label]
	var requirement_text := tr("QUEST_CREATION_REQUIRED_PROFESSION") % [highlighted_role]
	_set_interest_feedback("[center]%s\n%s[/center]" % [requirement_text, availability_text])

func _get_selected_required_role() -> String:
	var location_idx := quest_location.selected
	var quest_type_idx := quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return ""
	var location := quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return ""
	if Manager.instance != null and Manager.instance.hub != null:
		return Manager.instance.hub.get_required_role_for_quest(_create_selected_quest_preview())
	if quest_type_key == SCOUT_QUEST_KEY:
		return "hunter"
	var profile := _get_selected_profile()
	return profile.get_required_role() if profile != null else ""

func _get_role_display_name(role: String) -> String:
	if role == "":
		return tr("QUEST_ROLE_ANY")
	var translation_key := "QUEST_ROLE_%s" % [role.to_upper()]
	var translated := tr(translation_key)
	return role.capitalize().replace("_", " ") if translated == translation_key else translated

func _get_selected_required_supplies() -> Dictionary[ItemInfo, int]:
	var selected := _get_selected_quest_type_and_objective()
	var objective := selected.get("objective") as QuestObjective
	var quest_type_key := str(selected.get("quest_type", ""))
	if quest_type_key == SCOUT_QUEST_KEY:
		return {}
	if objective == null or quest_type_key == "":
		return {}

	return objective.get_required_supplies(quest_type_key)

func _refresh_quest_details() -> void:
	var selected := _get_selected_quest_type_and_objective()
	var objective := selected.get("objective") as QuestObjective
	var quest_type_key := str(selected.get("quest_type", ""))
	if quest_type_key == SCOUT_QUEST_KEY:
		if duration_title != null:
			duration_title.text = tr("QUEST_DETAIL_DISTANCE_LABEL")
		var distance_text := ""
		var location := quest_location.get_item_metadata(quest_location.selected) as HexBase
		if location != null:
			distance_text = tr("QUEST_DETAIL_SCOUT_DISTANCE") % [_get_target_selector().get_scout_distance(location)]
		_set_details(
			tr("QUEST_DESC_SCOUT"),
			distance_text,
			tr("QUEST_RISK_UNCERTAIN"),
			[]
		)
		return
	if objective == null or quest_type_key == "":
		_set_details("")
		return
	if duration_title != null:
		duration_title.text = tr("QUEST_DETAIL_DURATION_LABEL")

	var description := objective.get_quest_profile_description(quest_type_key)

	var duration_text := ""
	var duration := objective.get_quest_duration(quest_type_key, 0.0)
	if duration > 0.0:
		duration_text = tr("QUEST_DETAIL_DURATION") % [ceil(duration)]

	var risk_text := ""
	var risk := objective.get_quest_profile_risk(quest_type_key)
	if risk != "":
		risk_text = risk
	var preview := _create_selected_quest_preview()
	if preview != null:
		var effective_risk_key := preview.get_effective_risk_key()
		var preview_profile := preview.get_profile()
		if effective_risk_key != "" and preview_profile != null and effective_risk_key != preview_profile.risk_key:
			var effective_risk := tr(effective_risk_key)
			if effective_risk != effective_risk_key:
				risk_text = effective_risk

	var reward_preview := objective.get_quest_profile_reward_preview(quest_type_key)
	var context_text := objective.get_quest_context_label(quest_type_key)
	_set_details(description, duration_text, risk_text, reward_preview, context_text)

func _get_selected_objective() -> QuestObjective:
	var selected := _get_selected_quest_type_and_objective()
	return selected.get("objective") as QuestObjective

func _get_selected_profile() -> QuestProfile:
	var selected := _get_selected_quest_type_and_objective()
	var objective := selected.get("objective") as QuestObjective
	var quest_type_key := str(selected.get("quest_type", ""))
	if objective == null or quest_type_key == "":
		return null
	return objective.get_profile(quest_type_key)

func _create_selected_quest_preview() -> Quest:
	var location_idx := quest_location.selected
	var quest_type_idx := quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return null
	var location := quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return null
	var preview := Quest.new(
		location,
		quest_type_key,
		_get_reward_offer_amount(),
		_get_minimum_rank_override(),
		0
	)
	preview.set_selected_support_ids(_selected_support_ids)
	return preview

func _clear_optional_supports() -> void:
	_selected_support_ids.clear()
	_support_selection_context = ""
	_clear_support_rows()
	if quest_support != null:
		quest_support.visible = false
	_request_window_refit()

func _clear_support_rows() -> void:
	if support_options == null:
		return
	for child in support_options.get_children():
		support_options.remove_child(child)
		child.queue_free()

func _refresh_optional_supports(reset_defaults: bool = false) -> void:
	if quest_support == null or support_options == null:
		return
	var profile := _get_selected_profile()
	var definitions: Array[QuestSupportDefinition] = []
	if profile != null:
		definitions = profile.get_optional_supports()
	var context_key := _get_support_selection_context_key()
	if definitions.is_empty() or context_key == "" or support_row_scene == null:
		_clear_optional_supports()
		return

	var should_reset := reset_defaults or context_key != _support_selection_context
	if should_reset:
		_selected_support_ids.clear()
		_support_selection_context = context_key
		for definition: QuestSupportDefinition in definitions:
			var provider_count := _get_available_support_provider_count(definition)
			if definition.selected_by_default and (definition.provider_role == "" or provider_count > 0):
				_selected_support_ids.append(str(definition.id))
	else:
		var valid_ids: Array[String] = []
		for definition: QuestSupportDefinition in definitions:
			valid_ids.append(str(definition.id))
		var preserved_ids: Array[String] = []
		for support_id in _selected_support_ids:
			if valid_ids.has(support_id):
				preserved_ids.append(support_id)
		_selected_support_ids = preserved_ids

	_clear_support_rows()
	for definition: QuestSupportDefinition in definitions:
		var row := support_row_scene.instantiate() as QuestSupportRowUI
		if row == null:
			continue
		support_options.add_child(row)
		row.setup(
			definition,
			_selected_support_ids.has(str(definition.id)),
			_get_available_support_provider_count(definition)
		)
		row.selection_changed.connect(_on_support_selection_changed)

	quest_support.visible = support_options.get_child_count() > 0
	_request_window_refit()

func _get_support_selection_context_key() -> String:
	var location_idx := quest_location.selected
	var quest_type_idx := quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return ""
	var location := quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return ""
	return "%s:%s" % [location.get_instance_id(), quest_type_key]

func _get_available_support_provider_count(definition: QuestSupportDefinition) -> int:
	if definition == null or definition.provider_role == "":
		return -1
	if Manager.instance == null or Manager.instance.quests == null:
		return 0
	var preview := _create_selected_quest_preview()
	return Manager.instance.quests.get_available_support_provider_count(preview, definition)

func _on_support_selection_changed(definition: QuestSupportDefinition, selected: bool) -> void:
	if definition == null:
		return
	var support_id := str(definition.id)
	if selected and not _selected_support_ids.has(support_id):
		_selected_support_ids.append(support_id)
	elif not selected:
		_selected_support_ids.erase(support_id)
	_refresh_quest_details()
	_request_window_refit()

func _get_selected_quest_type_and_objective() -> Dictionary:
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return {}

	var location: HexBase = quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return {}

	if quest_type_key == SCOUT_QUEST_KEY:
		return {
			"objective": null,
			"quest_type": quest_type_key,
		}

	if location.structure == null:
		return {}

	var objective := location.structure.instance as QuestObjective
	if objective == null:
		return {}

	return {
		"objective": objective,
		"quest_type": quest_type_key,
	}

func _get_quest_type_key(index: int) -> String:
	if index < 0 or index >= quest_type.item_count:
		return ""
	var metadata = quest_type.get_item_metadata(index)
	return str(metadata) if metadata is String else ""

func _create_supply_slot(item: ItemInfo, count: int) -> ContentSlotUI:
	var slot: ContentSlotUI = packed_slot.instantiate()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.can_drag = false
	slot.set_content(ContentSlotResource.new(count, item, max(1, count), true, false))
	return slot

func _get_player_inventory() -> ContentGroup:
	if Manager.instance == null:
		return null
	if Manager.instance.hub != null and Manager.instance.hub.stockpile != null:
		return Manager.instance.hub.stockpile
	if Manager.instance.player_instance == null:
		return null
	return Manager.instance.player_instance.inventory

func _get_player() -> PlayerController:
	if Manager.instance == null:
		return null
	return Manager.instance.player_instance

func _connect_player_currency_signal() -> void:
	if Manager.instance != null and Manager.instance.hub != null:
		if not Manager.instance.hub.changed.is_connected(_on_player_currency_amount_changed):
			Manager.instance.hub.changed.connect(_on_player_currency_amount_changed)
		if not Manager.instance.hub.faction_activity_changed.is_connected(_on_hub_faction_activity_changed):
			Manager.instance.hub.faction_activity_changed.connect(_on_hub_faction_activity_changed)
	var player := _get_player()
	if player == null:
		return
	if not player.currency_amount_changed.is_connected(_on_player_currency_amount_changed):
		player.currency_amount_changed.connect(_on_player_currency_amount_changed)

func _refresh_reward_offer_limit() -> void:
	if reward_offer_spin_box == null:
		return
	var player := _get_player()
	var available_currency := Manager.instance.hub.currency if Manager.instance != null and Manager.instance.hub != null else (player.currency if player != null else 0)
	reward_offer_spin_box.allow_greater = false
	reward_offer_spin_box.max_value = maxf(0.0, float(available_currency))
	if reward_offer_spin_box.value > reward_offer_spin_box.max_value:
		reward_offer_spin_box.value = reward_offer_spin_box.max_value

func _get_reward_offer_amount() -> int:
	if reward_offer_spin_box == null:
		return 0
	return maxi(0, roundi(reward_offer_spin_box.value))

func _get_minimum_rank_override() -> int:
	if minimum_rank_option == null or minimum_rank_option.selected < 0:
		return -1
	return int(minimum_rank_option.get_item_metadata(minimum_rank_option.selected))

func _has_reward_budget() -> bool:
	var player := _get_player()
	if Manager.instance != null and Manager.instance.hub != null:
		return Manager.instance.hub.currency >= _get_reward_offer_amount()
	return player != null and player.currency >= _get_reward_offer_amount()

func _get_interested_npc_count() -> int:
	if Manager.instance == null or Manager.instance.quests == null:
		return -1
	var location_idx: int = quest_location.selected
	var quest_type_idx: int = quest_type.selected
	if location_idx < 0 or quest_type_idx < 0:
		return -1
	var location := quest_location.get_item_metadata(location_idx) as HexBase
	var quest_type_key := _get_quest_type_key(quest_type_idx)
	if location == null or quest_type_key == "":
		return -1
	return Manager.instance.quests.get_available_npcs_for_quest(
		location,
		quest_type_key,
		_get_reward_offer_amount(),
		_get_minimum_rank_override()
	).size()

func _get_posting_service() -> QuestPostingService:
	var quest_manager := Manager.instance.quests if Manager.instance != null else null
	var hub := Manager.instance.hub if Manager.instance != null else null
	var player := _get_player()
	if (
		_posting_service == null
		or _posting_service.quest_manager != quest_manager
		or _posting_service.hub != hub
		or _posting_service.player != player
	):
		_posting_service = QuestPostingService.new(quest_manager, hub, player)
	return _posting_service

func _get_target_selector() -> QuestTargetSelector:
	var quest_manager := Manager.instance.quests if Manager.instance != null else null
	var player := _get_player()
	if (
		_target_selector == null
		or _target_selector.quest_manager != quest_manager
		or _target_selector.player != player
	):
		_target_selector = QuestTargetSelector.new(quest_manager, player)
		_target_selector.target_unavailable.connect(_on_target_unavailable)
	return _target_selector

func _on_target_unavailable(message_key: String) -> void:
	_set_details("")
	_set_status(tr(message_key))

func _apply_mode_visibility() -> void:
	if location_row != null:
		location_row.visible = not scout_only
	if scout_distance_row != null:
		scout_distance_row.visible = scout_only
	if scout_direction_row != null:
		scout_direction_row.visible = scout_only
	_set_creation_controls_visible(true)
	if finish_quest_creation != null:
		finish_quest_creation.text = tr("QUEST_CREATION_SCOUT_FRONTIER") if scout_only else tr("QUEST_CREATION_CREATE")
	if window != null:
		window.change_title.emit("QUEST_CREATION_SCOUT_FRONTIER" if scout_only else "WINDOW_NEW_QUEST")

func _set_creation_controls_visible(controls_visible: bool) -> void:
	if type_row != null:
		type_row.visible = controls_visible and not scout_only
	if minimum_rank_row != null:
		minimum_rank_row.visible = controls_visible and not scout_only
	if reward_offer_row != null:
		reward_offer_row.visible = controls_visible and not scout_only
	if actions_row != null:
		actions_row.visible = controls_visible
	if window != null and not scout_only:
		window.change_title.emit("WINDOW_NEW_QUEST" if controls_visible else "WINDOW_QUEST_STATUS")

func _configure_scout_distance_limit() -> void:
	if scout_distance_spin_box == null or Manager.instance == null or Manager.instance.quests == null:
		return
	scout_distance_spin_box.min_value = 1.0
	scout_distance_spin_box.max_value = maxf(1.0, float(Manager.instance.quests.max_quest_distance))
	scout_distance_spin_box.step = 1.0
	scout_distance_spin_box.allow_greater = false
	if scout_distance_spin_box.value < scout_distance_spin_box.min_value:
		scout_distance_spin_box.value = scout_distance_spin_box.min_value
	if scout_distance_spin_box.value > scout_distance_spin_box.max_value:
		scout_distance_spin_box.value = scout_distance_spin_box.max_value

func _get_requested_scout_distance() -> int:
	if scout_distance_spin_box == null:
		return 1
	return maxi(1, roundi(scout_distance_spin_box.value))

func _setup_scout_direction_options() -> void:
	if scout_direction_option == null:
		return
	if scout_direction_option.item_count > 0:
		return
	for direction_index in range(6):
		scout_direction_option.add_item(_get_scout_direction_label(direction_index))
		scout_direction_option.set_item_metadata(direction_index, direction_index)
	scout_direction_option.select(0)

func _get_requested_scout_direction() -> int:
	if scout_direction_option == null or scout_direction_option.selected < 0:
		return 0
	return int(scout_direction_option.get_item_metadata(scout_direction_option.selected))

func _get_scout_direction_label(direction_index: int) -> String:
	var translation_key := "QUEST_SCOUT_DIRECTION_%s" % [direction_index]
	var translated := tr(translation_key)
	return translated if translated != translation_key else str(direction_index + 1)

func _can_create_scout_quest(location: HexBase) -> bool:
	return _has_reward_budget() and _get_target_selector().can_post_scout(location)

func _create_scout_quest(location: HexBase, reward_amount: int) -> void:
	if not _can_create_scout_quest(location):
		_update_finish_button()
		return

	var minimum_rank_override := _get_minimum_rank_override()
	var scout_rank_experience := 1
	if minimum_rank_override >= 0:
		scout_rank_experience = int(AdventurerRank.clamp_rank(minimum_rank_override)) + 1
	var scout_context := {
		"scout_direction_key": "QUEST_SCOUT_DIRECTION_%s" % [_get_requested_scout_direction()],
		"scout_distance": _get_target_selector().get_scout_distance(location),
	}
	var no_supports: Array[String] = []
	var result := _get_posting_service().post_quest(
		location,
		SCOUT_QUEST_KEY,
		reward_amount,
		minimum_rank_override,
		scout_rank_experience,
		no_supports,
		_get_player_inventory(),
		scout_context
	)
	if not result.success:
		_set_status(tr(result.message_key))
		_update_finish_button()
		return
	quest_created.emit(result.quest)
	if window != null:
		window.close_requested.emit()
