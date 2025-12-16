class_name DataManager extends Node

@export var scenes: Array[SceneInfo];
@export var regions: Array[RegionInfo];

static var instance: DataManager;
func _ready() -> void:
	DataManager.instance = self;
	for scene in scenes:
		scene.ready();
		
	for region in regions:
		for scene in scenes:
			if not region.scene_multipliers.has(scene):
				region.scene_multipliers[scene] = 0;

func get_scene_by_name(scene_name: String) -> SceneInfo:
	var filtered := scenes.filter(func(scene: SceneInfo) -> bool: return scene != null && scene.id == scene_name);
	if filtered.size() == 1:
		return filtered[0];
	elif filtered.size() == 0:
		Debug.err(scene_name + " was not found, unable to instantiate!")
		return null;
	Debug.err(scene_name + " has multiple references, this is not allowed!")
	return null;

func node_to_info(node: Node) -> SceneInfo:
	var filtered: Array[SceneInfo] = scenes.filter(func(x: SceneInfo) -> bool: return x.node == node);
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
	
func pick_scene(x: int, y: int) -> SceneInfo:
	var total_weight := 0.0
	var cumulative: Array[float] = []
	var region := get_region_for(x, y);

	for info in scenes:
		var w := info.spawn_weight

		if region != null and region.scene_multipliers.has(info):
			w *= region.scene_multipliers[info]

		w = max(w, 0.0)
		total_weight += w
		cumulative.append(total_weight)

	if total_weight <= 0.0:
		return null

	var r := randf() * total_weight
	for i in cumulative.size():
		if r <= cumulative[i]:
			return scenes[i]

	return scenes[-1]

func get_region_for(x: int, y: int) -> RegionInfo:
	var best_region: RegionInfo = null
	var best_score := -INF

	for region in regions:
		if region.noise == null:
			continue

		var n := (region.noise.get_noise_2d(x, y) + 1.0) * 0.5
		var score := n * region.region_weight

		if score > best_score:
			best_score = score
			best_region = region

	return best_region
