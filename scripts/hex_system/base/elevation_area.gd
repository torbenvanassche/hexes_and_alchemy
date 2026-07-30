class_name ElevationArea
extends RefCounted

var id: int
var elevation_units: int
var hexes: Array[HexBase] = []
var entrance_count: int = 0
var is_reachable_from_start: bool = false
