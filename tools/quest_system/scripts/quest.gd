class_name Quest extends Resource

enum Type {
	FETCH,
	SLAY
}

var quest_type: Type;
var supplies: ContentGroup;

func _init(type: Type = Type.FETCH) -> void:
	supplies = ContentGroup.new();
	quest_type = type;
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource)
