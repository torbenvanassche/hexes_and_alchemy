class_name DeliveryQuest
extends Quest

## A delivery's cargo, outcome and lifecycle, independent of its movement driver.
## A player, courier or caravan controller decides when it arrives and returns.
var _profile: QuestProfile
var required_cargo: Dictionary[ItemInfo, int] = {}
signal delivered()

func _init(destination: HexBase = null) -> void:
	super(destination, "delivery", 0, -1, 0)

func uses_guild_roster() -> bool:
	return false

func requires_objective() -> bool:
	return false

func configure_delivery(definition: DeliveryDefinition) -> void:
	if definition == null or not is_state(QuestState.WAITING) or context.get("supplies_reserved", false): return
	# Snapshot authored values so editing a resource cannot change an active job.
	context["definition_id"] = definition.id
	context["title_key"] = definition.title_key
	required_cargo = definition.cargo.duplicate()
	context["reputation_reward"] = maxi(0, definition.reputation_reward)
	context["prestige_reward"] = maxi(0, definition.prestige_reward)
	context["return_required"] = definition.return_required
	var delivery := DeliveryOutcome.new()
	delivery.title_key = definition.title_key
	delivery.payment = maxi(0, definition.payment)
	delivery.reputation_reward = maxi(0, definition.reputation_reward)
	delivery.completes_journal_task = definition.completion_task
	outcome = delivery

## Transfers cargo once; QuestManager returns it to this source on cancellation.
func reserve_cargo(source: ContentGroup) -> bool:
	if not is_state(QuestState.WAITING) or context.get("supplies_reserved", false): return false
	var cargo := required_cargo
	if source == null or cargo.is_empty() or not source.has_all(cargo): return false
	for item in cargo:
		if not item is ItemInfo or int(cargo[item]) <= 0: return false
	context["supply_source"] = source
	context["supplies_reserved"] = true
	if not source.transfer_all_to(supplies, cargo, true):
		context["supplies_reserved"] = false
		return false
	return true

func get_prestige_reward() -> int:
	return int(context.get("prestige_reward", 0))

func get_profile() -> QuestProfile:
	if _profile == null:
		_profile = QuestProfile.new()
		_profile.rank_experience_reward = 0
	_profile.quest_key = quest_key
	_profile.translation_key_name = str(context.get("title_key", "QUEST_TYPE_DELIVERY"))
	_profile.guild_reputation_reward = int(context.get("reputation_reward", 0))
	return _profile

## Call after the movement driver has verified arrival at the recipient.
func resolve_delivery() -> void:
	if not is_state(QuestState.IN_PROGRESS) or context.get("delivery_paid", false): return
	if not context.get("supplies_reserved", false) or not supplies.has_all(required_cargo): return
	_resolve_return_outcome()
	if context.get("delivery_paid", false): delivered.emit()
	if context.get("delivery_paid", false) and not context.get("return_required", false):
		_finish_delivery()

func finish_return() -> void:
	if not is_state(QuestState.RETURNING) or not context.get("delivery_paid", false): return
	_finish_delivery()

func _finish_delivery() -> void:
	set_state(QuestState.COMPLETE)
	# Externally driven deliveries finish even if board auto-collection is off.
	parse_reward()

func parse_reward() -> void:
	if context.get("reward_claimed", false) or not is_state(QuestState.COMPLETE): return
	if not context.get("delivery_paid", false): return
	context["reward_resolved"] = true
	context["reward_claimed"] = true
	context["supplies_reserved"] = false
	Manager.instance.quests.remove_quest(self)
	completed.emit()
