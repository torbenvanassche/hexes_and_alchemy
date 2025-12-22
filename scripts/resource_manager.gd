class_name DataManager extends Node

@export var hexes: Array[HexInfo];
@export var regions: Array[RegionInfo];
@export var structures: Array[StructureInfo];

@export var player: SceneInfo;
@export var pause_menu: SceneInfo;

var scene_data: Array[SceneInfo];

const CUBE_DIRS : Array[Vector3i] = [
	Vector3i(1,-1,0), Vector3i(1,0,-1), Vector3i(0,1,-1),
	Vector3i(-1,1,0), Vector3i(-1,0,1), Vector3i(0,-1,1)
]

static var instance: DataManager;
func _ready() -> void:
	DataManager.instance = self;
	for object in [hexes, regions, structures]:
		for item in object:
			item.initialize();
			
	scene_data.append_array(hexes)
	scene_data.append_array(structures);
	scene_data.append(player)

func get_scene_by_name(scene_name: String) -> SceneInfo:
	var filtered := scene_data.filter(func(scene: SceneInfo) -> bool: return scene != null && scene.id == scene_name);
	if filtered.size() == 1:
		return filtered[0];
	elif filtered.size() == 0:
		Debug.err(scene_name + " was not found, unable to instantiate!")
		return null;
	Debug.err(scene_name + " has multiple references, this is not allowed!")
	return null;

func node_to_info(node: Node) -> SceneInfo:
	var filtered: Array[SceneInfo] = scene_data.filter(func(x: SceneInfo) -> bool: return x.node == node);
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
	
func pick_scene(x: int, y: int) -> HexInfo:
	var region := get_region_for(x, y)
	if region == null:
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
		return null

	var r := randf() * total_weight
	for i in cumulative.size():
		if r <= cumulative[i]:
			return valid_scenes[i]

	return valid_scenes[-1]
	
func get_region_for(x: int, y: int) -> RegionInfo:
	var best_region: RegionInfo = null
	var best_score := -INF

	for region in regions:
		if region.noise == null:
			continue

		var n := (region.noise.get_noise_2d(x, y) + 1.0) * 0.5
		if n < region.activation_threshold:
			continue

		var score := n + region.priority * 10.0

		if score > best_score:
			best_score = score
			best_region = region
			
	if best_region == null:
		best_region = regions.pick_random();

	return best_region
