class_name MarketManager extends Node

@export var sale_check_interval: float = 5.0
@export var base_sale_chance: float = 0.35
@export var min_sale_chance: float = 0.05
@export var max_sale_chance: float = 0.95
@onready var market_timer: Timer = Timer.new();

signal tick();

func _ready() -> void:
	market_timer.wait_time = sale_check_interval
	market_timer.timeout.connect(tick.emit);
	market_timer.autostart = true;
	add_child(market_timer)
