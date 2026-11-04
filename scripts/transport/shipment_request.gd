class_name ShipmentRequest
extends Resource

@export var title_key := ""
@export_multiline var description_key := ""
@export var cargo: Dictionary[ItemInfo, int] = {}
@export_range(1, 500, 1) var payment := 48
@export_range(0, 10, 1) var reputation_reward := 2
