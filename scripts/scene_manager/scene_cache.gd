class_name SceneCache extends Node

var cached_scenes: Array[SceneInfo] = [];
var loading_queue: Array[SceneInfo] = [];
var timer: Timer;
	
func _init() -> void:
	timer = Timer.new();
	timer.timeout.connect(_check_progress)
	timer.wait_time = 0.1;

func queue(scene_info: SceneInfo) -> Signal:
	print(scene_info.id)
	if not timer.is_inside_tree():
		SceneManager.add_child(timer);
	
	if timer.is_stopped():
		timer.start();
	
	loading_queue.append(scene_info);
	scene_info.is_queued = true;
	var error: Error = ResourceLoader.load_threaded_request(scene_info.packed_scene.resource_path, type_string(typeof(PackedScene)))
	if error:
		loading_queue.erase(scene_info)
		Debug.err(str(error))
		
	return scene_info.cached;

func _check_progress() -> void:
	for loading in loading_queue:
		if ResourceLoader.load_threaded_get_status(loading.packed_scene.resource_path) == ResourceLoader.THREAD_LOAD_LOADED:
			cached_scenes.append(loading)
			loading_queue.erase(loading)
			loading.is_cached = true;
			loading.is_queued = false;
			loading.cached.emit(loading);
			if loading_queue.size() == 0:
				timer.stop();

func get_from_cache(scene_info: SceneInfo) -> SceneInfo:
	if cached_scenes.has(scene_info):
		return cached_scenes[cached_scenes.find(scene_info)];
	else:
		queue(scene_info)
		return scene_info;
		
func is_cached(scene_info: SceneInfo) -> Variant:
	if loading_queue.has(scene_info) || cached_scenes.has(scene_info):
		return ResourceLoader.load_threaded_get_status(scene_info.packed_scene.resource_path)
	else:
		return -1;
		
func remove(scene_info: SceneInfo) -> void:
	if cached_scenes.has(scene_info):
		get_from_cache(scene_info).queue_free();
		cached_scenes.erase(scene_info);
		if scene_info.node and not scene_info.node.is_queued_for_deletion():
			scene_info.node.queue_free();
			
func get_with_type(type: SceneInfo.Type) -> Array[SceneInfo]:
	return cached_scenes.filter(func(x: SceneInfo) -> bool: return x.type == type)
