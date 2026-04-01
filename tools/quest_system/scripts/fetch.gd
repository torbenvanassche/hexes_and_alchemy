class_name FetchQuest extends Quest

@export var requested_items: Dictionary[ItemInfo, int];
var progress_tracker: ContentGroup;

func initialize() -> void:
	progress_tracker = ContentGroup.new();
	for key: ItemInfo in requested_items.keys():
		var slot := ContentSlotResource.new(0, key, requested_items[key], true, false);
		progress_tracker.add_slot(slot)
