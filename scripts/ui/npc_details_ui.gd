class_name NpcDetailsUI
extends PanelContainer

const SLOT_WEAPON := &"weapon"
const SLOT_ARMOR := &"armor"
const SLOT_TOOL := &"tool"
const SLOT_ACCESSORY := &"accessory"

@onready var name_label: Label = $MarginContainer/VBoxContainer/Header/NameLabel
@onready var rank_label: Label = $MarginContainer/VBoxContainer/Header/RankLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var identity_label: Label = $MarginContainer/VBoxContainer/IdentityLabel
@onready var role_label: Label = $MarginContainer/VBoxContainer/RoleLabel
@onready var traits_label: Label = $MarginContainer/VBoxContainer/TraitsLabel
@onready var earnings_label: Label = $MarginContainer/VBoxContainer/EarningsLabel
@onready var slots_grid: GridContainer = $MarginContainer/VBoxContainer/SlotsGrid
@onready var equipment_slot_uis: Dictionary[StringName, EquipmentSlotUI] = {
	SLOT_WEAPON: $MarginContainer/VBoxContainer/SlotsGrid/Weapon/Slot,
	SLOT_ARMOR: $MarginContainer/VBoxContainer/SlotsGrid/Armor/Slot,
	SLOT_TOOL: $MarginContainer/VBoxContainer/SlotsGrid/Tool/Slot,
	SLOT_ACCESSORY: $MarginContainer/VBoxContainer/SlotsGrid/Accessory/Slot,
}

var npc: NPC
var equipment_slots: Dictionary[StringName, ContentSlotResource] = {}

func setup_npc(selected_npc: NPC) -> void:
	if npc != null and npc.activity_changed.is_connected(_refresh_npc_activity):
		npc.activity_changed.disconnect(_refresh_npc_activity)
	npc = selected_npc
	if npc != null and npc.equipment == null:
		npc.equipment = NpcEquipmentSlots.new()
	if npc != null and not npc.activity_changed.is_connected(_refresh_npc_activity):
		npc.activity_changed.connect(_refresh_npc_activity)
	_refresh()

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
		return

	name_label.text = _get_npc_display_name()
	rank_label.text = tr("ADVENTURER_ROSTER_RANK") % npc.get_rank_progress_label()
	status_label.text = npc.get_activity_status_label()
	identity_label.text = "%s: %s" % [tr("NPC_PROFESSION"), npc.get_profession_label()]
	role_label.text = "%s: %s" % [tr("NPC_ROLE"), npc.get_role_label()]
	traits_label.text = "%s: %s" % [tr("NPC_TRAITS"), npc.get_traits_label()]
	earnings_label.text = "%s: %s" % [tr("NPC_EARNINGS"), npc.earned_currency]
	_update_window_title()

	_set_equipment_slot(SLOT_WEAPON, tr("NPC_EQUIPMENT_WEAPON"), npc.equipment.weapon)
	_set_equipment_slot(SLOT_ARMOR, tr("NPC_EQUIPMENT_ARMOR"), npc.equipment.armor)
	_set_equipment_slot(SLOT_TOOL, tr("NPC_EQUIPMENT_TOOL"), npc.equipment.tool)
	_set_equipment_slot(SLOT_ACCESSORY, tr("NPC_EQUIPMENT_ACCESSORY"), npc.equipment.accessory)
	_request_window_fit()

func _refresh_npc_activity(_npc: NPC) -> void:
	if npc != null and is_instance_valid(npc):
		status_label.text = npc.get_activity_status_label()


func _set_equipment_slot(slot_key: StringName, label_text: String, item: EquipmentInfo) -> void:
	var slot_ui := equipment_slot_uis.get(slot_key) as EquipmentSlotUI
	if slot_ui == null:
		return
	slot_ui.can_drag = true
	slot_ui.tooltip_text = label_text
	var slot_resource := ContentSlotResource.new(1 if item != null else 0, item, 1, true)
	slot_resource.changed.connect(_on_equipment_slot_changed.bind(slot_key))
	slot_ui.set_content(slot_resource)
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

func _clear_slots() -> void:
	equipment_slots.clear()

func _get_npc_display_name() -> String:
	return npc.get_display_name() if npc != null else tr("SCENE_ADVENTURER_NAME")

func _update_window_title() -> void:
	var window := _get_window()
	if window != null:
		window.change_title.emit(_get_npc_display_name())

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
