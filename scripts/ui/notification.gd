class_name Toast
extends RichTextLabel

@export var display_time: float = 2.5
@export var slide_time: float = 0.25
@export var edge_padding: float = 10.0

var target_position: Vector2

@onready var colorRect: ColorRect = $ColorRect;
var base_color: Color;

func _ready() -> void:
	await get_tree().process_frame
	base_color = colorRect.color;
	target_position = position
	visible = false

func notify(txt: String, c: Color = base_color) -> void:
	self.text = txt
	visible = true
	colorRect.color = c;

	await get_tree().process_frame
	
	var slide_distance := size.x + edge_padding
	position = target_position + Vector2(slide_distance, 0)

	var tween := get_tree().create_tween()
	tween.tween_property(self, "position", target_position, slide_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(display_time).timeout

	var tween_out := get_tree().create_tween()
	tween_out.tween_property(self, "position", target_position + Vector2(slide_distance, 0), slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tween_out.tween_callback(func() -> void: visible = false)
