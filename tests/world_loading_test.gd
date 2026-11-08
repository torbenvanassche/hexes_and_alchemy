extends Node
var failures: Array[String] = []
var deadline := 0
var phase := 0
var last_progress := 0.0
var saw_generation := false
var saw_restoration := false
var captures: Dictionary[int, bool] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 60000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid:
			node.world_seed = 20261102
			node.max_streaming_steps_per_frame = 16
	)
	check(WorldLoading.visible and WorldLoading.blocks_input, "Startup is not covered from the first frame")
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("Loading-screen test timed out")
		get_tree().quit(1)
		return
	if not WorldLoading.blocks_input: return
	check(WorldLoading.visible, "Input is blocked without a visible loading cover")
	check(WorldLoading.displayed_progress >= last_progress, "Loading progress moved backwards")
	last_progress = WorldLoading.displayed_progress
	var grid := WorldLoading._grid
	if not is_instance_valid(grid): return
	if not grid.initialized or grid.is_streaming_busy() or SaveGames.is_loading:
		check(is_equal_approx(WorldLoading.cover.modulate.a, 1.0), "Incomplete world was revealed")
		check(WorldLoading.displayed_progress < 1.0, "Loading claimed 100% before completion")
		check(WorldLoading.cover.size.is_equal_approx(get_viewport().get_visible_rect().size), "Loading cover does not fill viewport")
	if not grid.initialized: saw_generation = true
	if SaveGames._restoring:
		saw_restoration = true
		check(WorldLoading.process_mode == Node.PROCESS_MODE_ALWAYS, "Loading screen freezes during paused restoration")
	if OS.get_cmdline_user_args().has("--capture") and phase < 2 and not captures.has(phase) and WorldLoading.displayed_progress > 0.3 and WorldLoading.displayed_progress < 0.7:
		captures[phase] = true
		_capture.call_deferred(phase)

func _capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/loading-screen-%d.png" % index)

func _wait_ready() -> void:
	while not SaveGames.save_block_reason().is_empty() or WorldLoading.blocks_input:
		await get_tree().process_frame

func _run() -> void:
	await _wait_ready()
	check(saw_generation, "No generation phase was observed")
	check(not WorldLoading.visible and WorldLoading.bar.value == 100.0, "Completed loading cover did not close at 100%")
	check(Manager.instance.player_instance._world_accepts_input(), "Player stayed locked after loading")
	var grid := Manager.instance.transport.get_grid() as MainGrid
	grid.generate_chunk(grid.chunk_radius + 1, 0)
	while grid.is_streaming_busy():
		check(not WorldLoading.visible, "Ordinary chunk streaming reopened the loading screen")
		await get_tree().process_frame
	check(SaveGames.save_slot("Loading regression"), "Cannot write loading fixture")
	reparent(SaveGames)
	get_window().size = Vector2i(960, 540)
	phase = 1
	last_progress = 0.0
	check(SaveGames.load_slot(SaveGames.slot_id("Loading regression")), "Cannot begin checkpoint loading")
	check(WorldLoading.visible and WorldLoading.cover.modulate.a == 1.0, "Save transition exposed the scene change")
	var result: Array = await SaveGames.load_finished
	check(result[0], "Checkpoint restoration failed")
	await _wait_ready()
	check(saw_restoration, "Save restoration was not covered")
	check(Manager.instance.player_instance._world_accepts_input(), "Save loading left input blocked")
	# Failure feedback must replace an endless loading bar and allow a fresh world.
	SaveGames._fail_load("Loading-screen regression failure")
	check(WorldLoading.retry.visible and WorldLoading.blocks_input, "Failed loading has no recovery action")
	check(WorldLoading.status.text == "Loading-screen regression failure", "Failure reason was lost")
	phase = 2
	last_progress = 0.0
	WorldLoading.retry.pressed.emit()
	await _wait_ready()
	check(not WorldLoading.visible, "New world did not recover from the loading failure")
	print("WORLD LOADING TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
