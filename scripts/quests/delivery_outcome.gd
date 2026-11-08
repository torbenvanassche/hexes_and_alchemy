class_name DeliveryOutcome
extends QuestOutcome

var title_key := ""
var payment := 0
var reputation_reward := 0

func apply(quest: Quest) -> void:
	if is_applied() or quest == null: return
	# Guard before inventory/standing signals can re-enter resolution.
	_is_applied = true
	quest.context["delivery_paid"] = true
	quest.context["supplies_reserved"] = false
	var contents := Manager.instance.quests._get_inventory_contents(quest.supplies)
	for item: Resource in contents: quest.supplies.remove(item, int(contents[item]))
	Manager.instance.hub.add_currency(payment)
	Manager.instance.reputation.record_quest(quest)
	complete_journal_task()
	applied.emit(self)

func get_summary() -> String:
	return tr("DELIVERY_REPORT") % [tr(title_key), payment, reputation_reward] if is_applied() else ""
