class_name SettlementHome
extends SettlementService

@export var upgrade_window: SceneInfo

func interact() -> void:
	if upgrade_window == null:
		return
	window_instance = open_ui_window(upgrade_window, false)

func can_interact() -> bool:
	return upgrade_window != null and (window_instance == null or not SceneManager.is_visible(window_instance))
