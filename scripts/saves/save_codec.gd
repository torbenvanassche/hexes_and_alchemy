class_name SaveCodec
extends RefCounted

## JSON values only. Runtime references are resolved after world/NPC/quest creation.
var grid: HexGrid
var npcs: Dictionary[String, NPC] = {}
var quests: Dictionary[String, Quest] = {}
var errors: Array[String] = []
## Structure references follow a migrated building; ordinary terrain coordinates
## and player positions keep their original meaning.
var relocated_sites: Dictionary[Vector3i, Vector3i] = {}

func encode(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_STRING: return value
		TYPE_FLOAT: return value if is_finite(value) else {"$float": str(value)}
		TYPE_STRING_NAME: return {"$name": str(value)}
		TYPE_NODE_PATH: return {"$path": str(value)}
		TYPE_VECTOR3I: return {"$v3i": [value.x, value.y, value.z]}
		TYPE_VECTOR2I: return {"$v2i": [value.x, value.y]}
		TYPE_VECTOR3: return {"$v3": [value.x, value.y, value.z]}
		TYPE_VECTOR2: return {"$v2": [value.x, value.y]}
		TYPE_COLOR: return {"$color": [value.r, value.g, value.b, value.a]}
		TYPE_PACKED_INT32_ARRAY: return {"$i32": Array(value)}
		TYPE_ARRAY:
			var array: Array = []
			for item in value: array.append(encode(item))
			return array
		TYPE_DICTIONARY:
			var pairs: Array = []
			for key in value: pairs.append([encode(key), encode(value[key])])
			return {"$dict": pairs}
	if not is_instance_valid(value): return null
	if value == Manager.instance.hub: return {"$service": "hub"}
	if value == Manager.instance.player_instance: return {"$service": "player"}
	if value is NPC: return {"$npc": str(value.get_instance_id())}
	if value is Quest: return {"$quest": str(value.get_instance_id())}
	if value is HexBase: return {"$hex": encode(value.cube_id)}
	if value is StateMachine: return {"$state": value.get_current_state()}
	if value is SceneTreeTimer: return {"$timer": value.time_left}
	if value is RandomNumberGenerator: return {"$rng": [str(value.seed), str(value.state)]}
	if value is ContentGroup:
		if value == Manager.instance.hub.stockpile: return {"$hub": true}
		return {"$inventory": inventory(value)}
	if value is Resource and not value.resource_path.is_empty():
		return {"$resource": value.resource_path}
	if value is Node:
		var parent: Node = value
		while parent != null and not parent is HexBase: parent = parent.get_parent()
		if parent is HexBase:
			return {"$node": encode(parent.cube_id), "path": str(parent.get_path_to(value))}
		return null
	if value is Object and value.get_script() != null:
		return {"$object": value.get_script().resource_path, "fields": fields(value)}
	errors.append("Unsupported saved value: %s" % type_string(typeof(value)))
	return null

func decode(value: Variant) -> Variant:
	if value is Array:
		var array: Array = []
		for item in value: array.append(decode(item))
		return array
	if not value is Dictionary: return value
	if value.has("$v3i"): return Vector3i(value["$v3i"][0], value["$v3i"][1], value["$v3i"][2])
	if value.has("$v2i"): return Vector2i(value["$v2i"][0], value["$v2i"][1])
	if value.has("$v3"): return Vector3(value["$v3"][0], value["$v3"][1], value["$v3"][2])
	if value.has("$v2"): return Vector2(value["$v2"][0], value["$v2"][1])
	if value.has("$color"): return Color(value["$color"][0], value["$color"][1], value["$color"][2], value["$color"][3])
	if value.has("$name"): return StringName(value["$name"])
	if value.has("$i32"): return PackedInt32Array(value["$i32"])
	if value.has("$path"): return NodePath(value["$path"])
	if value.has("$float"): return INF if value["$float"] == "inf" else NAN
	if value.has("$dict"):
		# Resource, coordinate and string keys all pass through this generic codec.
		# Concrete receiving properties apply their declared types with assign().
		var dictionary: Dictionary[Variant, Variant] = {}
		for pair in value["$dict"]: dictionary[decode(pair[0])] = decode(pair[1])
		return dictionary
	if value.has("$npc"): return npcs.get(value["$npc"])
	if value.has("$service"):
		return Manager.instance.hub if value["$service"] == "hub" else Manager.instance.player_instance
	if value.has("$quest"): return quests.get(value["$quest"])
	if value.has("$hex"):
		var coord: Vector3i = decode(value["$hex"])
		return grid.get_hex_at_cube_id(relocated_sites.get(coord, coord))
	if value.has("$node"):
		var coord: Vector3i = decode(value["$node"])
		var hex := grid.get_hex_at_cube_id(relocated_sites.get(coord, coord))
		# The first village prototype kept trade at its arrival marker.
		var path := str(value["path"]).replace("Arrival/Trade", "Buildings/Market")
		# Removed stationary request authors now direct players to the board.
		if path.get_file().begins_with("Resident_"):
			path = path.get_base_dir() + "/structures/questboard"
		return hex.get_node_or_null(NodePath(path)) if hex != null else null
	if value.has("$hub"): return Manager.instance.hub.stockpile
	if value.has("$resource"): return load(value["$resource"])
	if value.has("$inventory"):
		var group := ContentGroup.new()
		restore_inventory(group, value["$inventory"])
		return group
	if value.has("$rng"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(value["$rng"][0])
		rng.state = int(value["$rng"][1])
		return rng
	if value.has("$object"):
		var object: Object
		if value["$object"].ends_with("spot_progress.gd"):
			object = SpotProgress.new(Vector3i.ZERO)
		elif value["$object"].ends_with("hub_operation.gd"):
			object = HubOperation.new("", null)
		else:
			object = load(value["$object"]).new()
		apply_fields(object, value["fields"])
		return object
	return null

func fields(object: Object, names: Array = []) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	for property in object.get_property_list():
		var key: String = property.name
		if not names.is_empty():
			if not names.has(key): continue
		elif not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		if key in ["script", "instances", "is_cached", "is_queued"]: continue
		if int(property.type) in [TYPE_SIGNAL, TYPE_CALLABLE]: continue
		result[key] = encode(object.get(key))
	return result

func apply_fields(object: Object, data: Dictionary[String, Variant]) -> void:
	for key in data:
		if not key in object: continue
		var current: Variant = object.get(key)
		var saved: Variant = data[key]
		if saved is Dictionary and saved.has("$timer"): continue
		if saved is Dictionary and saved.has("$state"):
			if current is StateMachine:
				current._current_state = saved["$state"]
				current._current_state_index = current.states.find(saved["$state"])
			continue
		if current is ContentGroup and saved is Dictionary and saved.has("$inventory"):
			restore_inventory(current, saved["$inventory"])
			continue
		var decoded: Variant = decode(saved)
		if current is Array and decoded is Array:
			current.assign(decoded)
		elif current is Dictionary and decoded is Dictionary:
			current.assign(decoded)
		else:
			object.set(key, decoded)

func inventory(group: ContentGroup) -> Dictionary[String, Variant]:
	var slots: Array = []
	for slot: ContentSlotResource in group.data:
		slots.append(TypedData.string_map({"item": encode(slot.get_content()), "count": slot.count, "max": slot.maxcount, "unlocked": slot.is_unlocked, "clear_on_empty": slot.clear_on_empty}))
	return {"stack": group.stack_size, "slots": slots}

func restore_inventory(group: ContentGroup, data: Dictionary[String, Variant]) -> void:
	group.data.clear()
	group.stack_size = int(data["stack"])
	for slot in data["slots"]:
		group.add_slot(ContentSlotResource.new(int(slot["count"]), decode(slot["item"]), int(slot["max"]), bool(slot["unlocked"]), bool(slot.get("clear_on_empty", true))))
	group.changed.emit()
