class_name QuestStatePresentation extends RefCounted

static var WAITING_COLOR: Color:
	get: return GameUI.WARNING
static var TRAVEL_COLOR: Color:
	get: return GameUI.TRAVEL
static var ACTIVE_COLOR: Color:
	get: return GameUI.SUCCESS
static var COMPLETE_COLOR: Color:
	get: return GameUI.SUCCESS
static var FAILED_COLOR: Color:
	get: return GameUI.DANGER
static var CANCELLED_COLOR: Color:
	get: return GameUI.MUTED

static func get_color(state: String) -> Color:
	match state:
		"waiting":
			return WAITING_COLOR
		"en_route", "returning":
			return TRAVEL_COLOR
		"in_progress":
			return ACTIVE_COLOR
		"complete":
			return COMPLETE_COLOR
		"failed":
			return FAILED_COLOR
		"cancelled":
			return CANCELLED_COLOR
	return GameUI.MUTED

static func get_progress(state: String) -> float:
	match state:
		"waiting":
			return 0.08
		"en_route":
			return 0.28
		"in_progress":
			return 0.55
		"returning":
			return 0.8
		"complete", "failed", "cancelled":
			return 1.0
	return 0.0

static func is_terminal(state: String) -> bool:
	return state in ["complete", "failed", "cancelled"]
