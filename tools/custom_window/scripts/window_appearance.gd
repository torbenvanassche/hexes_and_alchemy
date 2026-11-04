@tool
class_name WindowAppearance
extends Resource

## Shared frame settings. Duplicate the resource to give a family of windows its own skin.
@export var theme: Theme = preload("res://themes/game_theme.tres")
@export var frame_style: StyleBox
@export var header_color := Color("18232c")
@export_range(36, 96) var header_height := 56
@export_range(28, 56) var action_size := 40
@export_range(16, 32) var icon_size := 22
@export_range(16, 36) var title_size := 26
@export var title_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
@export var content_margins := Vector4i(20, 12, 20, 20)
@export var locked_icon: Texture2D = preload("res://sprites/ui/line/locked.svg")
@export var unlocked_icon: Texture2D = preload("res://sprites/ui/line/unlocked.svg")
