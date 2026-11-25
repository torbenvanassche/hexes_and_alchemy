class_name GameUI
extends RefCounted

## Semantic UI colors are shared by the game theme and code-created visual states.
const UI_THEME: Theme = preload("res://themes/game_theme.tres")

static var SURFACE: Color:
	get:
		return UI_THEME.get_color("surface_color", "GamePalette")
static var RAISED: Color:
	get:
		return UI_THEME.get_color("raised_color", "GamePalette")
static var BORDER: Color:
	get:
		return UI_THEME.get_color("border_color", "GamePalette")
static var TEXT: Color:
	get:
		return UI_THEME.get_color("text_color", "GamePalette")
static var MUTED: Color:
	get:
		return UI_THEME.get_color("muted_color", "GamePalette")
static var ACCENT: Color:
	get:
		return UI_THEME.get_color("accent_color", "GamePalette")
static var SUCCESS: Color:
	get:
		return UI_THEME.get_color("success_color", "GamePalette")
static var WARNING: Color:
	get:
		return UI_THEME.get_color("warning_color", "GamePalette")
static var DANGER: Color:
	get:
		return UI_THEME.get_color("danger_color", "GamePalette")
static var TRAVEL: Color:
	get:
		return UI_THEME.get_color("travel_color", "GamePalette")
