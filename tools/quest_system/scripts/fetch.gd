class_name FetchQuest extends Quest

@export var requested_items: Dictionary[ItemInfo, int];
var progress_tracker: ContentGroup;

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(progress_tracker):
		progress_tracker.free()

func initialize() -> void:
	quest_key = "fetch"
	if progress_tracker != null:
		return
	
	progress_tracker = ContentGroup.new();
	for key: ItemInfo in requested_items.keys():
		var slot := ContentSlotResource.new(0, key, requested_items[key], true, false);
		progress_tracker.add_slot(slot)
