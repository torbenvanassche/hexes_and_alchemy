class_name Quest extends Resource

enum Type {
	FETCH,
	SLAY
}

var quest_type: Type;
var supplies: ContentGroup;
var location: HexBase;

func _init(_location: HexBase, type: Type = Type.FETCH, _supplies: ContentGroup = ContentGroup.new()) -> void:
	self.quest_type = type;
	self.supplies = _supplies;
	self.location = _location;
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource)
