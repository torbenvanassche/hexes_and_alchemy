class_name Quest extends Resource

enum Type {
	FETCH,
	SLAY
}

var quest_type: Type;
var supplies: ContentGroup;

func _init(type: Type = Type.FETCH, _supplies: ContentGroup = ContentGroup.new()) -> void:
	quest_type = type;
	self.supplies = _supplies;
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource)
