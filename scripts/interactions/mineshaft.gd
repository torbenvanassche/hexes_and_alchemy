extends Node

func interact() -> void:
	var mine_scene = DataManager.instance.get_scene_by_name("gameplay_mines");
	Manager.instance.player_instance.set_return_position()
	mine_scene.queue(_on_mineshaft_loaded)
	
func _on_mineshaft_loaded(sI: SceneInfo):
	SceneManager.transition(sI)
