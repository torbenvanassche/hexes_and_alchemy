class_name Helpers extends Node

static func apply_margin_uniform(margin_container: MarginContainer, margin: int) -> void:
	margin_container.add_theme_constant_override("margin_left", margin)
	margin_container.add_theme_constant_override("margin_top", margin)
	margin_container.add_theme_constant_override("margin_right", margin)
	margin_container.add_theme_constant_override("margin_bottom", margin)
