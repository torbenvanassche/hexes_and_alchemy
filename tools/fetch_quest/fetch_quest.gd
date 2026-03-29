class_name FetchQuest extends Interaction

@export var items: Dictionary[ItemInfo, int];
var requests: ContentGroup;

var window_instance: SceneInstance;

signal completed();

func _ready() -> void:
	super();
	
	requests = ContentGroup.new();
	for key: ItemInfo in items.keys():
		requests.data.append(ContentSlotResource.new(0, key, items[key], true, false))
	requests.changed.connect(_on_deposit_changed)
		
func _on_deposit_changed() -> void:
	if requests.all(func(rq: ContentSlotResource) -> bool: return rq.is_full()):
		completed.emit();

func interact() -> void:
	DataManager.instance.get_scene_by_name("deposit_ui").queue(_open_window)
	
func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var inventory_ui: InventoryUI = (window_instance.node as DraggableControl).content as InventoryUI;
	inventory_ui.inventory = requests;
	window_instance.on_enter.emit();

func _on_area_exit(other: Area3D) -> void:
	if window_instance:
		window_instance.hide();
	super(other);
