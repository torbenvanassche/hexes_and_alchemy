class_name EquipmentSlotUI
extends PlaceableContentSlotUI

@export var accepted_slot: EquipmentInfo.Slot = EquipmentInfo.Slot.WEAPON
@onready var lock_overlay: Control = get_node_or_null("RankLock") as Control
@onready var lock_label: Label = get_node_or_null("RankLock/Label") as Label

var rank_locked := false
var required_rank: AdventurerRank.Rank = AdventurerRank.Rank.F

func _ready() -> void:
	super()
	_apply_rank_lock_visual()

func set_rank_lock(is_locked: bool, minimum_rank: AdventurerRank.Rank) -> void:
	rank_locked = is_locked
	required_rank = minimum_rank
	if is_node_ready():
		_apply_rank_lock_visual()

func _apply_rank_lock_visual() -> void:
	if lock_overlay != null:
		lock_overlay.visible = rank_locked
	if lock_label != null:
		lock_label.text = tr("EQUIPMENT_SLOT_LOCK_OVERLAY") % AdventurerRank.get_display_name(required_rank)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not super._can_drop_data(at_position, data):
		return false
	var equipment_drag_data := data as DragData
	if equipment_drag_data == null or equipment_drag_data.slot == null or equipment_drag_data.slot.contentSlot == null:
		return false
	var item := equipment_drag_data.slot.contentSlot.get_content() as EquipmentInfo
	return item != null and item.slot == accepted_slot

func _get_dragged_placeable() -> PlaceableStructureInfo:
	return null

func controller_activate() -> bool:
	if ContentSlotUI.controller_transfer_active(): return super()
	if not can_drag or rank_locked or contentSlot == null or not contentSlot.is_unlocked: return false
	var stockpile := _get_player_inventory()
	if stockpile == null: return false
	var menu := PopupMenu.new()
	var choices: Array[EquipmentInfo] = [null]
	menu.add_item(tr("UI_UNEQUIP"))
	menu.set_item_disabled(0, contentSlot.get_content() == null)
	for slot: ContentSlotResource in stockpile.data:
		var item := slot.get_content() as EquipmentInfo
		if item == null or item.slot != accepted_slot or slot.count <= 0 or not slot.is_unlocked or choices.has(item): continue
		choices.append(item)
		menu.add_item(item.get_display_name())
	menu.index_pressed.connect(func(index: int) -> void: _choose_equipment(choices[index], stockpile))
	menu.popup_hide.connect(func() -> void:
		if is_instance_valid(self) and is_visible_in_tree(): grab_focus()
		menu.queue_free())
	add_child(menu)
	menu.popup(Rect2i(Vector2i(global_position), Vector2i(300, 0)))
	menu.set_focused_item(1 if choices.size() > 1 else 0)
	return true

func _choose_equipment(item: EquipmentInfo, stockpile: ContentGroup) -> bool:
	if not can_drag or rank_locked or contentSlot == null or not contentSlot.is_unlocked: return false
	var previous := contentSlot.get_content() as EquipmentInfo
	if item == previous: return true
	if item != null and (item.slot != accepted_slot or stockpile.remove(item, 1) != 0): return false
	if previous != null and stockpile.add(previous, 1) != 0:
		if item != null: stockpile.add(item, 1, true)
		if is_instance_valid(Manager.instance) and Manager.instance.toast != null:
			Manager.instance.toast.notify(tr("UI_INVENTORY_FULL"), GameUI.WARNING)
		return false
	contentSlot.count = 0 if item == null else 1
	contentSlot.set_content(item)
	return true
