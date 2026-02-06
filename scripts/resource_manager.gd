class_name DataManager extends Node

@export var hexes: Array[HexInfo];
@export var regions: Array[RegionInfo];
@export var structures: Array[StructureInfo];
@export var scenes: Array[SceneInfo];
@export var items: Array[ItemInfo];

var scene_data: Array[SceneInfo];

@onready var ocean_descriptor: RegionInfo = preload("res://resources/region_info/ocean.tres");

const CUBE_DIRS : Array[Vector3i] = [
	Vector3i(1,-1,0), Vector3i(1,0,-1), Vector3i(0,1,-1),
	Vector3i(-1,1,0), Vector3i(-1,0,1), Vector3i(0,-1,1)
]

static var instance: DataManager;
func _ready() -> void:
	DataManager.instance = self;
	
	scene_data.append_array(hexes)
	scene_data.append_array(structures);
	scene_data.append_array(scenes)
	
	for object in scene_data:
		object.initialize();

func get_scene_by_name(scene_name: String) -> SceneInfo:
	var filtered := scene_data.filter(func(scene: SceneInfo) -> bool: return scene != null && scene.id == scene_name);
	if filtered.size() == 1:
		return filtered[0];
	elif filtered.size() == 0:
		Debug.err(scene_name + " was not found!")
		return null;
	Debug.err(scene_name + " has multiple references, this is not allowed!")
	return null;
	
func get_item_by_name(item_name: String) -> ItemInfo:
	var filtered := items.filter(func(item: ItemInfo) -> bool: return item.unique_id == item_name);
	if filtered.size() == 1:
		return filtered[0];
	elif filtered.size() == 0:
		Debug.err(item_name + " was not found!")
		return null;
	Debug.err(item_name + " has multiple references, this is not allowed!")
	return null;

func node_to_info(node: Node) -> SceneInfo:
	var filtered: Array[SceneInfo] = scene_data.filter(func(x: SceneInfo) -> bool: return x.has_instance(node));
	if filtered.size() == 1:
		return filtered[0];
	elif filtered.size() > 1:
		Debug.err(node.name + " has multiple references, this is not allowed!")
		return null;
	Debug.err("Could not find " + node.name + " in scenes.")
	return null

func is_active(scene_name: String) -> bool:
	var scene_info := get_scene_by_name(scene_name);
	return scene_info.node != null && scene_info.node.visible == true
	
func pick_scene(x: int, y: int, region_options: Array[RegionInfo] = regions) -> HexInfo:
	var region := get_region_for(x, y, region_options)
	if region == null:
		Debug.message("No region found for scene")
		return null

	var total_weight := 0.0
	var cumulative: Array[float] = []
	var valid_scenes: Array[HexInfo] = []

	for info in hexes:
		if not region.scene_multipliers.has(info):
			continue

		var w := region.scene_multipliers[info]
		if w <= 0.0:
			continue

		total_weight += w
		cumulative.append(total_weight)
		valid_scenes.append(info)

	if total_weight <= 0.0:
		Debug.message("Total weight was <= 0")
		return null

	var r := randf() * total_weight
	for i in cumulative.size():
		if r <= cumulative[i]:
			return valid_scenes[i]

	return valid_scenes[-1]
	
func get_region_for(x: int, y: int, region_options: Array[RegionInfo] = regions) -> RegionInfo:
	var best_region: RegionInfo = null
	var best_priority := -INF

	for region: RegionInfo in region_options:
		if not region.matches(x, y):
			continue

		if region.priority > best_priority:
			best_priority = region.priority
			best_region = region
			
	if not best_region:
		return DataManager.instance.ocean_descriptor;
	return best_region
