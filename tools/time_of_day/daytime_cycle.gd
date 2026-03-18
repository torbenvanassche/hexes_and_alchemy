class_name TimeOfDay extends Node

##Day duration in seconds
@export var duration: int = 100;

@onready var day_timer: Timer = Timer.new();

signal day_ended();

func _ready() -> void:
	day_timer.wait_time = duration
	day_timer.timeout.connect(day_ended.emit);
	day_timer.autostart = true;
	add_child(day_timer)
