class_name NpcDetailsUI
extends PanelContainer

const SLOT_WEAPON := &"weapon"
const SLOT_ARMOR := &"armor"
const SLOT_TOOL := &"tool"
const SLOT_ACCESSORY := &"accessory"

@export var equipment_slot_scene: PackedScene

@onready var name_label: Label = $MarginContainer/VBoxContainer/Header/NameLabel
@onready var rank_label: Label = $MarginContainer/VBoxContainer/Header/RankLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var slots_grid: GridContainer = $MarginContainer/VBoxContainer/SlotsGrid

var npc: NPC
var equipment_slots: Dictionary[StringName, ContentSlotResource] = {}

func setup_npc(selected_npc: NPC) -> void:
	npc = selected_npc
	if npc != null and npc.equipment == null:
		npc.equipment = NpcEquipmentSlots.new()
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
		return

	name_label.text = _get_npc_display_name()
	rank_label.text = tr("ADVENTURER_ROSTER_RANK") % npc.get_rank_progress_label()
	status_label.text = tr("ADVENTURER_STATUS_AVAILABLE") if npc.current_quest == null else tr("ADVENTURER_STATUS_ASSIGNED")
	_update_window_title()

	_add_equipment_slot(SLOT_WEAPON, tr("NPC_EQUIPMENT_WEAPON"), npc.equipment.weapon)
	_add_equipment_slot(SLOT_ARMOR, tr("NPC_EQUIPMENT_ARMOR"), npc.equipment.armor)
	_add_equipment_slot(SLOT_TOOL, tr("NPC_EQUIPMENT_TOOL"), npc.equipment.tool)
	_add_equipment_slot(SLOT_ACCESSORY, tr("NPC_EQUIPMENT_ACCESSORY"), npc.equipment.accessory)
	_request_window_fit()

func _add_equipment_slot(slot_key: StringName, label_text: String, item: EquipmentInfo) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.theme = theme
	label.theme_type_variation = "Label"
	label.add_theme_color_override("font_color", Color(0.42, 0.31, 0.2, 1))
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.uppercase = true
	column.add_child(label)

	var slot_ui := equipment_slot_scene.instantiate() as EquipmentSlotUI
	slot_ui.can_drag = true
	slot_ui.tooltip_text = label_text
	var slot_resource := ContentSlotResource.new(1 if item != null else 0, item, 1, true)
	slot_resource.changed.connect(_on_equipment_slot_changed.bind(slot_key))
	slot_ui.set_content(slot_resource)
	equipment_slots[slot_key] = slot_resource
	column.add_child(slot_ui)

	slots_grid.add_child(column)

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
	for child in slots_grid.get_children():
		slots_grid.remove_child(child)
		child.queue_free()

func _get_npc_display_name() -> String:
	if npc == null or npc.npc_info == null:
		return tr("SCENE_ADVENTURER_NAME")
	var display_name := npc.npc_info.get_display_name()
	return tr("SCENE_ADVENTURER_NAME") if display_name == npc.npc_info.id.capitalize() else display_name

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
