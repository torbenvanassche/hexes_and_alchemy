class_name QuestPostingService extends RefCounted

class PostResult extends RefCounted:
	var success := false
	var quest: Quest
	var message_key := ""

signal quest_posted(quest: Quest)
signal posting_failed(message_key: String, quest: Quest)

var quest_manager: QuestManager
var hub: HubState
var player: PlayerController

func _init(
	_manager: QuestManager = null,
	_hub: HubState = null,
	_player: PlayerController = null
) -> void:
	quest_manager = _manager
	hub = _hub
	player = _player

func post_quest(
	location: HexBase,
	quest_type_key: String,
	reward_amount: int,
	minimum_rank_override: int,
	rank_experience_reward: int,
	selected_support_ids: Array[String],
	supply_inventory: ContentGroup,
	extra_context: Dictionary = {}
) -> PostResult:
	var result := PostResult.new()
	if quest_manager == null:
		return _fail(result, "QUEST_POST_FAILED")

	var quest := Quest.new(
		location,
		quest_type_key,
		reward_amount,
		minimum_rank_override,
		rank_experience_reward
	)
	quest.set_selected_support_ids(selected_support_ids)
	quest.context.merge(extra_context, true)
	result.quest = quest

	var posting_error := quest_manager.get_posting_error(quest)
	if posting_error != "":
		return _fail(result, posting_error)
	if not _reserve_reward(quest):
		return _fail(result, "QUEST_POST_NOT_ENOUGH_CURRENCY")

	if quest_type_key != "scout":
		var objective := quest.get_objective()
		if objective == null or not objective.assign_required_supplies(quest, supply_inventory):
			quest_manager.refund_quest_reward(quest)
			return _fail(result, "QUEST_POST_MISSING_SUPPLIES")
		quest.context["supplies_reserved"] = true
		quest.context["supply_source"] = supply_inventory

	if not quest_manager.add_quest(quest):
		quest_manager.release_quest_supplies(quest)
		quest_manager.refund_quest_reward(quest)
		return _fail(result, "QUEST_POST_FAILED")

	result.success = true
	quest_posted.emit(quest)
	return result

func _fail(result: PostResult, message_key: String) -> PostResult:
	result.message_key = message_key
	posting_failed.emit(message_key, result.quest)
	return result

func _reserve_reward(quest: Quest) -> bool:
	var amount := quest.get_offered_currency_reward()
	if amount <= 0:
		return true
	if hub != null:
		if not hub.reserve_currency(amount):
			return false
		quest.context["reward_source"] = hub
	elif player != null and player.currency >= amount:
		player.currency -= amount
		quest.context["reward_source"] = player
	else:
		return false
	quest.context["reward_reserved"] = true
	return true
