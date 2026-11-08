class_name ShipmentQuest
extends DeliveryQuest

## Trade-specific identity; the reusable DeliveryQuest owns cargo and rewards.

func _init(destination: HexBase = null) -> void:
	super(destination)
	quest_key = "shipment"

func prepare(request: ShipmentRequest, cargo: Dictionary[ItemInfo, int], payment: int, reputation: int, already_delivered := false) -> void:
	configure_delivery(request)
	# Keep the payout agreed at dispatch when migrating older journey snapshots.
	context["reputation_reward"] = reputation
	(outcome as DeliveryOutcome).payment = payment
	(outcome as DeliveryOutcome).reputation_reward = reputation
	context["request_id"] = request.id
	# Migration adopts cargo that was already removed from stores by older saves.
	context["supply_source"] = Manager.instance.hub.stockpile
	context["supplies_reserved"] = not already_delivered and not cargo.is_empty()
	context["delivery_paid"] = already_delivered
	if not already_delivered:
		for item: ItemInfo in cargo: add_supply(item, int(cargo[item]))
		if not cargo.is_empty(): required_cargo = cargo.duplicate()
	outcome._is_applied = already_delivered
