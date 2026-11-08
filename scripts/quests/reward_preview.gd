class_name RewardPreview
extends RefCounted

var item: ItemInfo
var minimum := 0
var maximum := 0

func _init(reward_item: ItemInfo = null, min_amount := 0, max_amount := 0) -> void:
	item = reward_item
	minimum = min_amount
	maximum = max_amount
