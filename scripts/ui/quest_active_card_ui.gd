class_name QuestActiveCardUI extends PanelContainer

signal claim_requested(quest: Quest)

var quest: Quest

func setup(value: Quest) -> void:
	quest = value
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_state := quest.state_machine.get_current_state()
	var state_color := QuestStatePresentation.get_color(current_state)
	_apply_style(state_color)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	add_child(content)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(header)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.17, 0.1, 0.04, 1.0))
	title.text = _get_quest_type_name()
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)

	var state_label := Label.new()
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", state_color)
	state_label.text = _get_state_name(current_state)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(state_label)

	var party_label := Label.new()
	party_label.text = _get_party_text()
	party_label.modulate = Color(0.32, 0.22, 0.12, 1.0)
	party_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(party_label)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 12)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.value = QuestStatePresentation.get_progress(current_state)
	progress.self_modulate = state_color
	progress.visible = not QuestStatePresentation.is_terminal(current_state)
	content.add_child(progress)

	if current_state in ["failed", "cancelled"]:
		var result_label := Label.new()
		var reason_key := str(quest.context.get("failure_reason_key", "QUEST_CANCELLED"))
		result_label.text = tr(reason_key)
		result_label.add_theme_color_override("font_color", state_color)
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(result_label)

	if quest.is_state(Quest.QuestState.COMPLETE):
		var claim_button := Button.new()
		claim_button.text = tr("QUEST_ACTION_CLAIM_REWARD")
		claim_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim_button.pressed.connect(claim_requested.emit.bind(quest))
		content.add_child(claim_button)

func _apply_style(state_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.74, 0.62, 0.42, 0.16).lerp(Color(state_color, 0.22), 0.35)
	style.border_color = state_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin(SIDE_LEFT, 10)
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_RIGHT, 10)
	style.set_content_margin(SIDE_BOTTOM, 8)
	add_theme_stylebox_override("panel", style)

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
