class_name DataManager extends Node

@export var hexes: Array[HexInfo];
@export var regions: Array[RegionInfo];
@export var structures: Array[StructureInfo];
@export var scenes: Array[SceneInfo];
@export var items: Array[ItemInfo];
@export var npcs: Array[NpcInfo];

var scene_data: Array[SceneInfo];
var _scene_lookup: Dictionary[StringName, SceneInfo] = {}
var _item_lookup: Dictionary[StringName, ItemInfo] = {}
var _node_lookup: Dictionary[int, SceneInfo] = {}

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
		_index_scene_info(object)
	
	for item in items:
		_index_item_info(item)

func _index_scene_info(scene_info: SceneInfo) -> void:
	if scene_info == null:
		return
	
	var lookup_key := StringName(scene_info.id)
	if _scene_lookup.has(lookup_key):
		Debug.err(scene_info.id + " has multiple references, this is not allowed!")
		return
	
	_scene_lookup[lookup_key] = scene_info

func _index_item_info(item_info: ItemInfo) -> void:
	if item_info == null:
		return
	
	var lookup_key := StringName(item_info.unique_id)
	if _item_lookup.has(lookup_key):
		Debug.err(item_info.unique_id + " has multiple references, this is not allowed!")
		return
	
	_item_lookup[lookup_key] = item_info

func register_scene_instance(scene_instance: SceneInstance) -> void:
	if scene_instance == null or scene_instance.node == null:
		return
	
	_node_lookup[scene_instance.node.get_instance_id()] = scene_instance.scene_info

func unregister_scene_instance(scene_instance: SceneInstance) -> void:
	if scene_instance == null or scene_instance.node == null:
		return
	
	unregister_node(scene_instance.node)

func unregister_node(node: Node) -> void:
	if node == null:
		return
	
	_node_lookup.erase(node.get_instance_id())

func get_scene_by_name(scene_name: String) -> SceneInfo:
	var scene_info := _scene_lookup.get(StringName(scene_name)) as SceneInfo
	if scene_info != null:
		return scene_info
	
	if scene_name != "":
		Debug.err(scene_name + " was not found!")
	return null;
	
func get_item_by_name(item_name: String) -> ItemInfo:
	var item_info := _item_lookup.get(StringName(item_name)) as ItemInfo
	if item_info != null:
		return item_info
	
	if item_name != "":
		Debug.err(item_name + " was not found!")
	return null;

func node_to_info(node: Node) -> SceneInfo:
	if node == null:
		return null
	
	var cached_info := _node_lookup.get(node.get_instance_id()) as SceneInfo
	if cached_info != null:
		return cached_info
	
	for scene_info in scene_data:
		if scene_info != null and scene_info.has_instance(node):
			_node_lookup[node.get_instance_id()] = scene_info
			return scene_info
	
	Debug.err("Could not find " + node.name + " in scenes.")
	return null

func is_active(scene_name: String) -> bool:
	var scene_info := get_scene_by_name(scene_name);
	if scene_info == null:
		return false
	
	for scene_instance in scene_info.get_live_instances():
		if SceneManager.is_visible(scene_instance):
			return true
	return false
	
func pick_scene(x: int, y: int, region_options: Array[RegionInfo] = regions, rng: RandomNumberGenerator = null) -> HexInfo:
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

	var r := (rng.randf() if rng != null else randf()) * total_weight
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
