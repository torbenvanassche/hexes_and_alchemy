extends PanelContainer

func _ready() -> void:
	$Journal.pressed.connect(func() -> void:
		if Manager.instance.player_instance != null:
			Manager.instance.player_instance.toggle_journal()
	)

func _process(_delta: float) -> void:
	if DataManager.instance != null:
		$Journal.set_pressed_no_signal(DataManager.instance.is_active("hub_window"))