extends CanvasLayer
## Persistent across scene changes, including paused save restoration.
var blocks_input := true
var displayed_progress := 0.0
var _grid: HexGrid
var _ready_frames := 0
var _finishing := false
var _failed := false
var _fade: Tween
@onready var cover: Control = $Cover
@onready var title: Label = $Cover/Center/Content/Title
@onready var status: Label = $Cover/Center/Content/Status
@onready var bar: ProgressBar = $Cover/Center/Content/Progress/Bar
@onready var percent: Label = $Cover/Center/Content/Progress/Percent
@onready var retry: Button = $Cover/Center/Content/Retry

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	SaveGames.load_started.connect(_on_load_started)
	SaveGames.load_finished.connect(_on_save_finished)
	retry.pressed.connect(_retry)
	_begin()

func _on_node_added(node: Node) -> void:
	if not node is MainGrid: return
	_grid = node
	_begin()

func _on_load_started() -> void:
	_grid = null
	_begin()

func _begin() -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	blocks_input = true
	_ready_frames = 0
	_finishing = false
	_failed = false
	displayed_progress = 0.0
	cover.modulate.a = 1.0
	show()
	retry.hide()
	title.text = tr("LOADING_TITLE")
	_update_display(0.0, "LOADING_PREPARING")

func _input(_event: InputEvent) -> void:
	# Keep GUI button handling available on the failure screen.
	if blocks_input and not _failed: get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if blocks_input: get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not blocks_input or _failed or _finishing: return
	if not is_instance_valid(_grid): return
	if not _grid.loading_progress.error.is_empty():
		_show_error(_grid.loading_progress.error)
		return
	var progress := _grid.loading_progress.value
	var stage := _grid.loading_progress.stage_key
	if SaveGames.is_loading:
		progress *= 0.75
		if _grid.initialized: stage = "LOADING_RESTORING"
		if SaveGames.is_restoring():
			progress = 0.75 + 0.25 * SaveGames.loading_progress.value
			stage = SaveGames.loading_progress.stage_key
	_update_display(minf(progress, 0.99), stage)
	var ready := _grid.initialized and not _grid.is_streaming_busy() and not SaveGames.is_loading
	ready = ready and is_instance_valid(Manager.instance) and is_instance_valid(Manager.instance.player_instance)
	_ready_frames = _ready_frames + 1 if ready else 0
	if _ready_frames >= 2:
		_finishing = true
		_update_display(1.0, "LOADING_READY")
		# Keep covering the first complete world frames, then reveal it gently.
		_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade.tween_interval(0.12)
		_fade.tween_property(cover, "modulate:a", 0.0, 0.18)
		_fade.tween_callback(func() -> void:
			hide()
			blocks_input = false
		)

func _update_display(value: float, stage: String) -> void:
	displayed_progress = maxf(displayed_progress, value)
	bar.value = displayed_progress * 100.0
	percent.text = "%d%%" % floori(bar.value)
	status.text = tr(stage)

func _on_save_finished(success: bool, message: String) -> void:
	if not success: _show_error(message)

func _show_error(message: String) -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	_failed = true
	blocks_input = true
	cover.modulate.a = 1.0
	show()
	title.text = tr("LOADING_FAILED")
	status.text = message
	retry.show()
	retry.grab_focus()

func _retry() -> void:
	_grid = null
	_begin()
	get_tree().paused = false
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
