extends Node

var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	# Compile scripts outside the currently open scenes too: editor import alone
	# does not load every UI, test and development script.
	var script_count := 0
	for folder: String in ["res://scripts", "res://tools", "res://tests", "res://development", "res://addons/settlement_designer"]:
		for path: String in FileUtils.get_resource_paths(folder):
			if not path.ends_with(".gd"): continue
			var script := load(path) as GDScript
			check(script != null and (script.can_instantiate() or (script.has_method("is_abstract") and script.call("is_abstract"))), "Script does not compile: " + path)
			script_count += 1
	for path: String in FileUtils.get_resource_paths("res://resources/quest_profiles"):
		if not path.ends_with(".tres"): continue
		var profile := load(path) as QuestProfile
		check(profile != null, "Quest profile no longer loads: " + path)
		if profile == null: continue
		for preview: RewardPreview in profile.get_reward_preview():
			check(preview.item != null and preview.minimum <= preview.maximum, "Invalid typed reward preview: " + path)
	# Generic inventory APIs must still accept both concrete resource key types.
	var item := load("res://resources/item_info/wood_raw.tres") as ItemInfo
	var items: Dictionary[ItemInfo, int] = {item: 2}
	var resources: Dictionary[Resource, int] = {item: 1}
	var source := ContentGroup.new()
	var destination := ContentGroup.new()
	source.add(item, 3, true)
	check(source.has_all(items) and source.has_all(resources), "Inventory rejected compatible typed resource maps")
	check(source.transfer_all_to(destination, items, true) and source.transfer_all_to(destination, resources, true), "Typed inventory transfer failed")
	check(source.get_count(item) == 0 and destination.get_count(item) == 3, "Inventory type conversion duplicated or lost resources")
	source.free()
	destination.free()
	# Old serialized journeys still decode into typed fields and typed cargo.
	var codec := SaveCodec.new()
	var transport := TransportManager.new()
	transport.restore_saved_state({"villages": codec.encode({Vector3i.ZERO: {"cycle": 1, "completed": 1, "phase": "fulfilled"}}), "active_shipment": codec.encode({"phase": "returning", "destination": Vector3i.ZERO, "route": [Vector3i.ZERO], "cargo": items, "payment": 24})}, codec)
	check(transport.villages[Vector3i.ZERO].deliveries.get(TransportManager.REQUESTS[0].id, 0) == 1, "Legacy trade proof migration changed")
	check(transport.active_shipment.delivery_paid and transport.active_shipment.cargo.get_typed_key_script() == ItemInfo, "Legacy journey did not acquire typed cargo or its payout guard")
	transport.free()
	print("TYPED DATA TEST %s (%d scripts)" % ["PASS" if failures.is_empty() else "FAIL " + str(failures), script_count])
	get_tree().quit(0 if failures.is_empty() else 1)
