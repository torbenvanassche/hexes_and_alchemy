class_name DataManager extends Node

@export var scenes: Array[SceneInfo];

var _total_weight: float = 0.0
var _cumulative_weights: Array[float] = []

static var instance: DataManager;
func _ready() -> void:
	DataManager.instance = self;
	for scene in scenes:
		scene.ready();
	_build_weight_table()
	
func _build_weight_table() -> void:
	_total_weight = 0.0
	_cumulative_weights.clear()

	for info in scenes:
		_total_weight += max(info.spawn_weight, 0.0)
		_cumulative_weights.append(_total_weight)

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
	
func pick_random_scene() -> SceneInfo:
	if scenes.is_empty():
		return null

	var r := randf() * _total_weight

	for i in scenes.size():
		if r <= _cumulative_weights[i]:
			return scenes[i]
	return scenes[-1]
