class_name QuestActiveCardUI extends PanelContainer

signal claim_requested(quest: Quest)

var quest: Quest

func setup(value: Quest) -> void:
	quest = value
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_state := quest.state_machine.get_current_state()
	theme_type_variation = &"CardPanel"

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	add_child(content)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(header)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.theme_type_variation = &"SectionTitle"
	title.text = _get_quest_type_name()
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)

	var state_label := Label.new()
	state_label.theme_type_variation = _state_variation(current_state)
	state_label.text = _get_state_name(current_state)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(state_label)

	var party_label := Label.new()
	party_label.text = _get_party_text()
	party_label.theme_type_variation = &"MutedLabel"
	party_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(party_label)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 12)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.value = QuestStatePresentation.get_progress(current_state)
	progress.self_modulate = QuestStatePresentation.get_color(current_state)
	progress.visible = not QuestStatePresentation.is_terminal(current_state)
	content.add_child(progress)

	if current_state in ["failed", "cancelled"]:
		var result_label := Label.new()
		var reason_key := str(quest.context.get("failure_reason_key", "QUEST_CANCELLED"))
		result_label.text = tr(reason_key)
		result_label.theme_type_variation = _state_variation(current_state)
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(result_label)

	if quest.is_state(Quest.QuestState.COMPLETE):
		var claim_button := Button.new()
		claim_button.text = tr("QUEST_ACTION_CLAIM_REWARD")
		claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim_button.pressed.connect(claim_requested.emit.bind(quest))
		content.add_child(claim_button)

	if QuestStatePresentation.is_terminal(current_state) and quest.uses_guild_roster() and quest.quest_key != "scout":
		var repeat := Button.new()
		repeat.text = tr("QUEST_REPEAT_ORDER")
		repeat.tooltip_text = tr("QUEST_REPEAT_HINT")
		repeat.pressed.connect(_repeat_order)
		content.add_child(repeat)

func _repeat_order() -> void:
	var result := Manager.instance.quests.repeat_order(quest)
	if not result.success: Manager.instance.toast.notify(tr(result.message_key), GameUI.WARNING)

func _state_variation(state: String) -> StringName:
	match state:
		"waiting": return &"StatusWarningLabel"
		"en_route", "returning": return &"StatusTravelLabel"
		"in_progress", "complete": return &"StatusSuccessLabel"
		"failed": return &"StatusDangerLabel"
		_: return &"StatusMutedLabel"

func _get_quest_type_name() -> String:
	if quest.quest_key == "scout":
		return tr("QUEST_TYPE_SCOUT")
	var profile := quest.get_profile()
	if profile != null:
		return profile.get_display_name()
	var key := "QUEST_TYPE_%s" % quest.quest_key.to_upper()
	var translated := tr(key)
	return quest.quest_key.capitalize() if translated == key else translated

func _get_state_name(state: String) -> String:
	var key := "QUEST_STATE_%s" % state.to_upper()
	var translated := tr(key)
	return state.capitalize() if translated == key else translated

func _get_party_text() -> String:
	if quest == null or quest.party.is_empty():
		return tr("QUEST_PARTY_UNASSIGNED")
	if quest.party.size() == 1:
		return tr("QUEST_PARTY_ONE_ADVENTURER")
	return tr("QUEST_PARTY_ADVENTURERS") % [quest.party.size()]
