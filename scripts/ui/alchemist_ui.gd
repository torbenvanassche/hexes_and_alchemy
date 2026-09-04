class_name AlchemistUI extends PanelContainer

const SERVICE_ROW := preload("res://scenes/ui/components/alchemist_service_row.tscn")
const COLOR_SUCCESS := Color(0.18, 0.46, 0.25, 1.0)
const COLOR_FAILURE := Color(0.62, 0.2, 0.14, 1.0)

@onready var currency_label: Label = $Margin/Content/Header/Currency
@onready var patients: VBoxContainer = $Margin/Content/Services/TreatmentPanel/Margin/Content/Scroll/Rows
@onready var patient_count: Label = $Margin/Content/Services/TreatmentPanel/Margin/Content/Header/Count
@onready var patients_empty: Label = $Margin/Content/Services/TreatmentPanel/Margin/Content/Empty
@onready var relics: VBoxContainer = $Margin/Content/Services/EnchantmentPanel/Margin/Content/Scroll/Rows
@onready var relic_count: Label = $Margin/Content/Services/EnchantmentPanel/Margin/Content/Header/Count
@onready var relics_empty: Label = $Margin/Content/Services/EnchantmentPanel/Margin/Content/Empty
@onready var feedback: Label = $Margin/Content/Feedback

var alchemist: Alchemist

func setup_interaction(interaction: Interaction) -> void:
	if alchemist != null and is_instance_valid(alchemist) and alchemist.services_changed.is_connected(_queue_refresh):
		alchemist.services_changed.disconnect(_queue_refresh)
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
	var currency := _get_currency()
	currency_label.text = tr("ALCHEMIST_CURRENCY") % currency

	var injuries: Array[Dictionary] = []
	for npc: NPC in alchemist.get_adventurers():
		for injury: AdventurerInjury in npc.active_injuries:
			if injury != null:
				injuries.append({"npc": npc, "injury": injury})
	patient_count.text = tr("ALCHEMIST_AVAILABLE_COUNT") % injuries.size()
	patients_empty.visible = injuries.is_empty()
	for entry: Dictionary in injuries:
		_add_treatment_row(entry.npc as NPC, entry.injury as AdventurerInjury, currency)

	var available_relics := alchemist.get_relics()
	relic_count.text = tr("ALCHEMIST_AVAILABLE_COUNT") % available_relics.size()
	relics_empty.visible = available_relics.is_empty()
	for item: EquipmentInfo in available_relics:
		_add_enchantment_row(item, currency)

func _add_treatment_row(npc: NPC, injury: AdventurerInjury, currency: int) -> void:
	var row := SERVICE_ROW.instantiate() as AlchemistServiceRowUI
	patients.add_child(row)
	var is_assigned := npc.current_quest != null
	var can_afford := currency >= injury.treatment_cost
	var disabled_reason := ""
	if is_assigned:
		disabled_reason = tr("ALCHEMIST_PATIENT_ASSIGNED")
	elif not can_afford:
		disabled_reason = tr("ALCHEMIST_NOT_ENOUGH_FUNDS")
	row.setup(
		npc.get_display_name(),
		tr("ALCHEMIST_INJURY_DETAIL") % [injury.get_display_name(), injury.severity],
		injury.treatment_cost,
		tr("ALCHEMIST_TREAT_ACTION"),
		tr("ALCHEMIST_INJURY_BADGE") % injury.severity,
		injury.get_description(),
		not is_assigned and can_afford,
		disabled_reason
	)
	row.action_requested.connect(_on_treat.bind(npc, injury))

func _add_enchantment_row(item: EquipmentInfo, currency: int) -> void:
	var row := SERVICE_ROW.instantiate() as AlchemistServiceRowUI
	relics.add_child(row)
	var can_afford := currency >= alchemist.enchantment_cost
	var properties := _get_enchantment_summary(item)
	row.setup(
		item.get_display_name(),
		tr("ALCHEMIST_RELIC_DETAIL") % [item.get_slot_name(), properties],
		alchemist.enchantment_cost,
		tr("ALCHEMIST_ENCHANT_ACTION"),
		tr("EQUIPMENT_TIER_RELIC").to_upper(),
		item.get_tooltip_text(),
		can_afford,
		"" if can_afford else tr("ALCHEMIST_NOT_ENOUGH_FUNDS")
	)
	row.action_requested.connect(_on_enchant.bind(item))

func _get_enchantment_summary(item: EquipmentInfo) -> String:
	if item.enchantment_names.is_empty():
		return tr("ALCHEMIST_RELIC_UNATTUNED")
	var names: Array[String] = []
	for enchantment: String in item.enchantment_names:
		names.append(tr("EQUIPMENT_ENCHANTMENT_%s" % enchantment.to_upper()))
	return ", ".join(names)

func _on_treat(npc: NPC, injury: AdventurerInjury) -> void:
	_set_feedback(alchemist.treat_injury(npc, injury), "ALCHEMIST_TREATMENT_SUCCESS")

func _on_enchant(item: EquipmentInfo) -> void:
	_set_feedback(alchemist.enchant_relic(item), "ALCHEMIST_ENCHANT_SUCCESS")

func _set_feedback(success: bool, success_key: String) -> void:
	feedback.text = tr(success_key) if success else tr("ALCHEMIST_ACTION_FAILED")
	feedback.add_theme_color_override("font_color", COLOR_SUCCESS if success else COLOR_FAILURE)
	if not success:
		_queue_refresh()

func _get_currency() -> int:
	return Manager.instance.hub.currency if Manager.instance != null and Manager.instance.hub != null else 0

func _clear_rows(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
