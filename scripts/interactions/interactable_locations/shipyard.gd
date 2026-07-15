class_name Shipyard extends SettlementService

@export var enabled: bool = true:
	set(value):
		enabled = value
		refresh_service_state()
@export_range(1, 10, 1) var required_settlement_level: int = 3

var buildable_structure: Buildable

func _ready() -> void:
	super()
	refresh_service_state.call_deferred()

func interact() -> void:
	pass

func can_interact() -> bool:
	return false

func is_service_enabled() -> bool:
	return enabled and _meets_level_requirement() and _is_built()

func refresh_service_state() -> void:
	visible = is_service_enabled()

func _meets_level_requirement() -> bool:
	var owner_settlement := get_settlement()
	if owner_settlement != null and owner_settlement.level < required_settlement_level:
		return false
	return true

func _is_built() -> bool:
	return buildable_structure == null or buildable_structure.current_step == self
