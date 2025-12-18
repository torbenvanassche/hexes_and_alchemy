class_name RegionInstance
extends RefCounted

var info: RegionInfo
var hexes: Dictionary[Vector2i, HexBase] = {}

func _init(p_info: RegionInfo) -> void:
	info = p_info

func add_hex(coord: Vector2i, hex: HexBase) -> void:
	hexes[coord] = hex

func has_hex(coord: Vector2i) -> bool:
	return hexes.has(coord)

func merge_from(other: RegionInstance) -> void:
	for coord in other.hexes:
		add_hex(coord, other.hexes[coord])
