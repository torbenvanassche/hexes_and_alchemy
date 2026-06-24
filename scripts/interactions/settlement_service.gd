@abstract class_name SettlementService extends Interaction

func get_settlement() -> Settlement:
	if settlement != null:
		return settlement
	if Manager.instance == null:
		return null
	return Manager.instance.get_settlement(self)

func has_settlement_service(type_name: StringName) -> bool:
	var owner_settlement: Settlement = get_settlement()
	return owner_settlement != null and owner_settlement.has_service(type_name)

func get_settlement_service(type_name: StringName) -> Interaction:
	var owner_settlement: Settlement = get_settlement()
	if owner_settlement == null:
		return null
	return owner_settlement.get_service(type_name)
