extends Node

func interact() -> void:
	var mine_scene = DataManager.instance.get_scene_by_name("gameplay_mines");
	mine_scene.queue(_on_mineshaft_loaded)
	
func _on_mineshaft_loaded(sI: SceneInfo):
	pass
