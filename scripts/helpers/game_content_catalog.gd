class_name GameContentCatalog
extends Resource

@export_group("Scene Data")
@export var hexes: Array[HexInfo] = []
@export var structures: Array[StructureInfo] = []
@export var scenes: Array[SceneInfo] = []

@export_group("World Data")
@export var regions: Array[RegionInfo] = []
@export var ocean_region: RegionInfo

@export_group("Item Data")
@export var items: Array[ItemInfo] = []

@export_group("NPC Data")
@export var npcs: Array[NpcInfo] = []
@export var faction_definitions: Array[FactionDefinition] = []

func get_scene_data() -> Array[SceneInfo]:
	var content: Array[SceneInfo] = []
	content.append_array(hexes)
	content.append_array(structures)
	content.append_array(scenes)
	return content

func get_world_scene_data() -> Array[SceneInfo]:
	var content: Array[SceneInfo] = []
	content.append_array(hexes)
	content.append_array(structures)
	return content
