class_name ResourceHud extends Control

@onready var _day_label: Label = $Margin/Content/TimeRow/Day
@onready var _phase_label: Label = $Margin/Content/TimeRow/Phase
@onready var _clock_label: Label = $Margin/Content/TimeRow/Clock

func _ready() -> void:
	_connect_time_signals()
	_refresh_time()

func _exit_tree() -> void:
	var cycle := _get_time_of_day()
	if cycle != null:
		if cycle.time_changed.is_connected(_on_time_changed):
			cycle.time_changed.disconnect(_on_time_changed)
		if cycle.phase_changed.is_connected(_on_phase_changed):
			cycle.phase_changed.disconnect(_on_phase_changed)

func _process(_delta: float) -> void:
	_connect_time_signals()
	if _get_time_of_day() != null:
		set_process(false)

func _connect_time_signals() -> void:
	var cycle := _get_time_of_day()
	if cycle == null:
		return
	if not cycle.time_changed.is_connected(_on_time_changed):
		cycle.time_changed.connect(_on_time_changed)
	if not cycle.phase_changed.is_connected(_on_phase_changed):
		cycle.phase_changed.connect(_on_phase_changed)

func _refresh_time() -> void:
	var cycle := _get_time_of_day()
	if cycle == null:
		_day_label.text = tr("HUD_TIME_DAY") % 1
		_phase_label.text = ""
		_clock_label.text = "--:--"
		return
	_on_time_changed(cycle.get_day_number(), cycle.get_clock_hour(), cycle.get_clock_minute())
	_on_phase_changed(cycle.current_phase)

func _on_time_changed(day: int, hour: int, minute: int) -> void:
	_day_label.text = tr("HUD_TIME_DAY") % day
	_clock_label.text = "%02d:%02d" % [hour, minute]

func _on_phase_changed(phase: TimeOfDayPhase) -> void:
	_phase_label.text = phase.get_display_name() if phase != null else ""

func _get_time_of_day() -> TimeOfDay:
	return Manager.instance.time_of_day if Manager.instance != null else null
