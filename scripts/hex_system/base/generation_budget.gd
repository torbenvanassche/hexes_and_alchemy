class_name GenerationBudget
extends RefCounted
## Cooperative startup work. Call checkpoint inside loops, never once per phase.
var grid: HexGrid
var deadline := 0
var slice_started := 0
var slices := 0
var maximum_slice_usec := 0

func _init(owner_grid: HexGrid) -> void:
	grid = owner_grid
	_restart()

func _restart() -> void:
	slice_started = Time.get_ticks_usec()
	deadline = slice_started + int(grid.startup_work_budget_ms * 1000.0)

func checkpoint(force := false) -> void:
	if not force and Time.get_ticks_usec() < deadline: return
	finish_slice()
	await grid.get_tree().process_frame
	if not is_instance_valid(grid): return
	_restart()

func finish_slice() -> void:
	var elapsed := Time.get_ticks_usec() - slice_started
	maximum_slice_usec = maxi(maximum_slice_usec, elapsed)
	grid.generation_metrics.record("startup_slice", elapsed)
	slices += 1

func restart_after_wait() -> void:
	_restart()
