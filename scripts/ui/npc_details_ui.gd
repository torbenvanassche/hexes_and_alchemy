class_name NpcDetailsUI
extends PanelContainer

const SLOT_WEAPON := &"weapon"
const SLOT_ARMOR := &"armor"
const SLOT_TOOL := &"tool"
const SLOT_ACCESSORY := &"accessory"

@onready var name_label: Label = %NameLabel
@onready var rank_label: Label = %RankLabel
@onready var status_label: Label = %StatusLabel
@onready var identity_label: Label = %IdentityLabel
@onready var role_label: Label = %RoleLabel
@onready var traits_label: Label = %TraitsLabel
@onready var earnings_label: Label = %EarningsLabel
@onready var injuries_label: Label = %InjuriesLabel
@onready var career_label: Label = %CareerLabel
@onready var retire_button: Button = %RetireButton
@onready var slots_grid: GridContainer = $MarginContainer/Scroll/Body/SlotsGrid
@onready var equipment_slot_uis: Dictionary[StringName, EquipmentSlotUI] = {
	SLOT_WEAPON: %WeaponSlot,
	SLOT_ARMOR: %ArmorSlot,
	SLOT_TOOL: %ToolSlot,
	SLOT_ACCESSORY: %AccessorySlot,
}

var npc: NPC
var equipment_slots: Dictionary[StringName, ContentSlotResource] = {}

func setup_npc(selected_npc: NPC) -> void:
	if is_instance_valid(npc):
		if npc.rest_progress_changed.is_connected(_refresh_condition): npc.rest_progress_changed.disconnect(_refresh_condition)
		if npc.tree_exiting.is_connected(_on_npc_exiting): npc.tree_exiting.disconnect(_on_npc_exiting)
	if npc != null and npc.activity_changed.is_connected(_refresh_npc_activity):
		npc.activity_changed.disconnect(_refresh_npc_activity)
	if npc != null and npc.injuries_changed.is_connected(_refresh_npc_activity):
		npc.injuries_changed.disconnect(_refresh_npc_activity)
	if npc != null and npc.rank_progress_changed.is_connected(_refresh):
		npc.rank_progress_changed.disconnect(_refresh)
	npc = selected_npc
	if is_instance_valid(npc):
		npc.rest_progress_changed.connect(_refresh_condition)
		npc.tree_exiting.connect(_on_npc_exiting)
	if npc != null and npc.equipment == null:
		npc.equipment = NpcEquipmentSlots.new()
	if npc != null and not npc.activity_changed.is_connected(_refresh_npc_activity):
		npc.activity_changed.connect(_refresh_npc_activity)
	if npc != null and not npc.injuries_changed.is_connected(_refresh_npc_activity):
		npc.injuries_changed.connect(_refresh_npc_activity)
	if npc != null and not npc.rank_progress_changed.is_connected(_refresh):
		npc.rank_progress_changed.connect(_refresh)
	_refresh()

func _ready() -> void:
	if not retire_button.pressed.is_connected(_on_retire_pressed):
		retire_button.pressed.connect(_on_retire_pressed)

func on_enter() -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	_clear_slots()
	if npc == null:
		name_label.text = tr("NPC_DETAILS_NO_NPC")
		rank_label.text = ""
		status_label.text = ""
		identity_label.text = ""
		role_label.text = ""
		traits_label.text = ""
		earnings_label.text = ""
		injuries_label.text = ""
		career_label.text = ""
		retire_button.disabled = true
		return

	name_label.text = _get_npc_display_name()
	rank_label.text = npc.get_rank_progress_label()
	identity_label.text = "%s · %s" % [npc.get_profession_label(), npc.get_role_label()]
	role_label.text = tr("UI_LABEL_VALUE") % [tr("NPC_ROLE"), npc.get_role_label()]
	traits_label.text = npc.get_traits_label()
	earnings_label.text = tr("UI_LABEL_VALUE") % [tr("NPC_EARNINGS"), npc.earned_currency]
	_refresh_condition()
	var rules := npc.recovery_rules if npc.recovery_rules != null else AdventurerRecoveryRules.new()
	var remaining := maxi(0, ceili(rules.automatic_retirement_seconds - npc.career_age_seconds))
	career_label.text = tr("NPC_CAREER_REMAINING") % remaining if rules.automatic_retirement_seconds > 0.0 else tr("NPC_CAREER_ACTIVE")
	retire_button.disabled = not npc.can_retire()
	retire_button.text = tr("NPC_RETIRE_INJURED_BUTTON") if npc.is_severely_injured() else tr("NPC_RETIRE_BUTTON")
	_update_window_title()

	_set_equipment_slot(SLOT_WEAPON, tr("NPC_EQUIPMENT_WEAPON"), npc.equipment.weapon)
	_set_equipment_slot(SLOT_ARMOR, tr("NPC_EQUIPMENT_ARMOR"), npc.equipment.armor)
	_set_equipment_slot(SLOT_TOOL, tr("NPC_EQUIPMENT_TOOL"), npc.equipment.tool)
	_set_equipment_slot(SLOT_ACCESSORY, tr("NPC_EQUIPMENT_ACCESSORY"), npc.equipment.accessory)
	_request_window_fit()

func _refresh_condition(_person: NPC = null) -> void:
	if not is_instance_valid(npc) or not is_node_ready(): return
	status_label.text = npc.get_activity_status_label()
	status_label.modulate = Color("a8bb92") if npc.is_available_for_quest() else Color("c5aa76")
	injuries_label.text = tr("UI_LABEL_VALUE") % [tr("NPC_INJURIES"), npc.get_injuries_label()] if not npc.active_injuries.is_empty() else tr("NPC_CONDITION_HEALTHY")
	%RecoveryBar.visible = npc.rest_remaining_seconds > 0.0
	%RecoveryBar.value = npc.get_rest_progress_ratio() * 100.0
	%RecoveryBar.tooltip_text = npc.get_activity_status_label()

func _on_npc_exiting() -> void:
	npc = null
	%RecoveryBar.hide()
	_refresh()

func _refresh_npc_activity(_npc: NPC) -> void:
	if npc != null and is_instance_valid(npc):
		_refresh()

func _on_retire_pressed() -> void:
	if npc != null and is_instance_valid(npc):
		npc.retire(false)

func _refresh_equipment_availability() -> void:
	if npc == null:
		return
	var can_change := npc.is_available_for_quest()
	for slot_key: StringName in equipment_slot_uis:
		var slot_ui := equipment_slot_uis[slot_key] as EquipmentSlotUI
		if slot_ui == null:
			continue
		var slot_type := _get_equipment_slot_type(slot_key)
		var required_rank := npc.get_equipment_unlock_rank(slot_type)
		var unlocked := npc.is_equipment_slot_unlocked(slot_type)
		slot_ui.can_drag = can_change and unlocked
		slot_ui.set_rank_lock(not unlocked, required_rank)
		var slot := equipment_slots.get(slot_key) as ContentSlotResource
		if slot != null and slot.is_unlocked != unlocked:
			slot.is_unlocked = unlocked
			slot.changed.emit()
		var item := slot.get_content() as EquipmentInfo if slot != null else null
		if not unlocked:
			slot_ui.tooltip_text = tr("EQUIPMENT_SLOT_LOCKED_TOOLTIP") % [_get_equipment_slot_label(slot_key), AdventurerRank.get_display_name(required_rank)]
		else:
			slot_ui.tooltip_text = _get_equipment_slot_label(slot_key) if item == null else item.get_tooltip_text()
		if unlocked and not can_change:
			slot_ui.tooltip_text += "\n%s" % tr("EQUIPMENT_LOCKED_WHILE_ASSIGNED")


func _set_equipment_slot(slot_key: StringName, label_text: String, item: EquipmentInfo) -> void:
	var slot_ui := equipment_slot_uis.get(slot_key) as EquipmentSlotUI
	if slot_ui == null:
		return
	var slot_type := _get_equipment_slot_type(slot_key)
	var required_rank := npc.get_equipment_unlock_rank(slot_type)
	var unlocked := npc.is_equipment_slot_unlocked(slot_type)
	slot_ui.can_drag = npc.is_available_for_quest() and unlocked
	slot_ui.set_rank_lock(not unlocked, required_rank)
	var slot_resource := ContentSlotResource.new(1 if item != null else 0, item, 1, unlocked)
	slot_resource.changed.connect(_on_equipment_slot_changed.bind(slot_key))
	slot_ui.set_content(slot_resource)
	slot_ui.tooltip_text = tr("EQUIPMENT_SLOT_LOCKED_TOOLTIP") % [label_text, AdventurerRank.get_display_name(required_rank)] if not unlocked else (label_text if item == null else item.get_tooltip_text())
	if unlocked and not slot_ui.can_drag:
		slot_ui.tooltip_text += "\n%s" % tr("EQUIPMENT_LOCKED_WHILE_ASSIGNED")
	equipment_slots[slot_key] = slot_resource

func _on_equipment_slot_changed(slot_key: StringName) -> void:
	if npc == null or npc.equipment == null or not equipment_slots.has(slot_key):
		return
	var slot := equipment_slots[slot_key] as ContentSlotResource
	var equipment := slot.get_content() as EquipmentInfo
	match slot_key:
		SLOT_WEAPON:
			npc.equipment.weapon = equipment
		SLOT_ARMOR:
			npc.equipment.armor = equipment
		SLOT_TOOL:
			npc.equipment.tool = equipment
		SLOT_ACCESSORY:
			npc.equipment.accessory = equipment
	var slot_ui := equipment_slot_uis.get(slot_key) as EquipmentSlotUI
	if slot_ui != null and equipment == null:
		slot_ui.tooltip_text = _get_equipment_slot_label(slot_key)

func _get_equipment_slot_label(slot_key: StringName) -> String:
	return tr("NPC_EQUIPMENT_%s" % String(slot_key).to_upper())

func _get_equipment_slot_type(slot_key: StringName) -> EquipmentInfo.Slot:
	match slot_key:
		SLOT_ARMOR:
			return EquipmentInfo.Slot.ARMOR
		SLOT_TOOL:
			return EquipmentInfo.Slot.TOOL
		SLOT_ACCESSORY:
			return EquipmentInfo.Slot.ACCESSORY
		_:
			return EquipmentInfo.Slot.WEAPON

func _clear_slots() -> void:
	equipment_slots.clear()

func _get_npc_display_name() -> String:
	return npc.get_display_name() if npc != null else tr("SCENE_ADVENTURER_NAME")

func _update_window_title() -> void:
	var window := _get_window()
	if window != null:
		window.change_title.emit(tr("SCENE_NPC_DETAILS_UI_NAME"))

func _request_window_fit() -> void:
	var window := _get_window()
	if window != null:
		window.request_fit_to_content(2)

func _get_window() -> DraggableControl:
	var current := get_parent()
	while current != null:
		if current is DraggableControl:
			return current as DraggableControl
		current = current.get_parent()
	return null
