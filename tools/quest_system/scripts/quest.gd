class_name Quest extends Resource

enum Type {
	FETCH,
	SLAY
}

var quest_type: Type;
var supplies: ContentGroup;
var location: HexBase;

var status: String = "Waiting";
var progress: float;

signal update_status();

func _init(_location: HexBase = null, _type: Type = Type.FETCH, _supplies: ContentGroup = ContentGroup.new()) -> void:
	self.quest_type = _type;
	self.supplies = _supplies;
	self.location = _location;
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource)
