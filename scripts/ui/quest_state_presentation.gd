class_name QuestStatePresentation extends RefCounted

const WAITING_COLOR := GameUI.WARNING
const TRAVEL_COLOR := GameUI.TRAVEL
const ACTIVE_COLOR := GameUI.SUCCESS
const COMPLETE_COLOR := GameUI.SUCCESS
const FAILED_COLOR := GameUI.DANGER
const CANCELLED_COLOR := GameUI.MUTED

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
