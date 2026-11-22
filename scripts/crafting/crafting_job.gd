class_name CraftingJob
extends RefCounted

## Materials are reserved at start; the output is added after this saved timer.
var item: ItemInfo
var inventory: ContentGroup
var ingredients: Dictionary[ItemInfo, int] = {}
var duration := 1.0
var elapsed := 0.0
var quantity := 1
var produced := 0

func remaining() -> int:
	return maxi(0, quantity - produced)

func get_progress() -> float:
	return clampf(elapsed / maxf(0.05, duration), 0.0, 1.0)
