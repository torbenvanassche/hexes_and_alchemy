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
