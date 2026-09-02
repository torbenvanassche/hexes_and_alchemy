class_name QuestStatePresentation extends RefCounted

const WAITING_COLOR := Color(0.65, 0.45, 0.16, 1.0)
const TRAVEL_COLOR := Color(0.2, 0.42, 0.62, 1.0)
const ACTIVE_COLOR := Color(0.18, 0.5, 0.34, 1.0)
const COMPLETE_COLOR := Color(0.25, 0.55, 0.28, 1.0)
const FAILED_COLOR := Color(0.65, 0.18, 0.15, 1.0)
const CANCELLED_COLOR := Color(0.5, 0.38, 0.22, 1.0)

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
	return Color(0.42, 0.31, 0.2, 1.0)

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
