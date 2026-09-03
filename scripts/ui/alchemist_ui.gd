class_name AlchemistUI extends MarginContainer

@onready var currency_label: Label = $Content/Currency
@onready var patients: VBoxContainer = $Content/Patients
@onready var relics: VBoxContainer = $Content/Relics
@onready var feedback: Label = $Content/Feedback

var alchemist: Alchemist

func setup_interaction(interaction: Interaction) -> void:
	alchemist = interaction as Alchemist
	if alchemist != null and not alchemist.services_changed.is_connected(_queue_refresh):
		alchemist.services_changed.connect(_queue_refresh)

func _ready() -> void:
	if Manager.instance != null and Manager.instance.hub != null and not Manager.instance.hub.changed.is_connected(_queue_refresh):
		Manager.instance.hub.changed.connect(_queue_refresh)

func on_enter() -> void:
	_refresh()

func _queue_refresh() -> void:
	call_deferred("_refresh")

func _refresh() -> void:
	if not is_node_ready() or alchemist == null:
		return
	_clear_rows(patients)
	_clear_rows(relics)
	var currency := Manager.instance.hub.currency if Manager.instance != null and Manager.instance.hub != null else 0
	currency_label.text = tr("ALCHEMIST_CURRENCY") % currency
	var has_patients := false
	for npc in alchemist.get_adventurers():
		for injury in npc.active_injuries:
			has_patients = true
			patients.add_child(_create_treatment_row(npc, injury))
	if not has_patients:
		patients.add_child(_create_label(tr("ALCHEMIST_NO_PATIENTS")))
	var available_relics := alchemist.get_relics()
	if available_relics.is_empty():
		relics.add_child(_create_label(tr("ALCHEMIST_NO_RELICS")))
	else:
		for item in available_relics:
			relics.add_child(_create_enchantment_row(item))

func _create_treatment_row(npc: NPC, injury: AdventurerInjury) -> Control:
	var row := HBoxContainer.new()
	var label := _create_label("%s — %s" % [npc.get_display_name(), injury.get_display_name()])
	label.tooltip_text = injury.get_description()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = tr("ALCHEMIST_TREAT_BUTTON") % injury.treatment_cost
	button.disabled = npc.current_quest != null
	button.pressed.connect(_on_treat.bind(npc, injury))
	row.add_child(button)
	return row

func _create_enchantment_row(item: EquipmentInfo) -> Control:
	var row := HBoxContainer.new()
	var label := _create_label(item.get_display_name())
	label.tooltip_text = item.get_tooltip_text()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = tr("ALCHEMIST_ENCHANT_BUTTON") % alchemist.enchantment_cost
	button.pressed.connect(_on_enchant.bind(item))
	row.add_child(button)
	return row

func _on_treat(npc: NPC, injury: AdventurerInjury) -> void:
	feedback.text = tr("ALCHEMIST_TREATMENT_SUCCESS") if alchemist.treat_injury(npc, injury) else tr("ALCHEMIST_ACTION_FAILED")

func _on_enchant(item: EquipmentInfo) -> void:
	feedback.text = tr("ALCHEMIST_ENCHANT_SUCCESS") if alchemist.enchant_relic(item) else tr("ALCHEMIST_ACTION_FAILED")

func _create_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _clear_rows(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
