extends Interaction

@export var items: Dictionary[ItemInfo, int];
var requests: Array[ItemRequest];

func _ready() -> void:
	for key in items.keys():
		var rq := ItemRequest.new(0, key, items[key]);
		rq.completed.connect(_on_request_complete)
		requests.append(rq)
		
func _on_request_complete() -> void:
	if requests.all(func(rq: ItemRequest) -> bool: return rq.is_full()):
		pass;

func interact() -> void:
	pass

func can_interact() -> bool:
	return true;
