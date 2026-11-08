class_name CraftingGuidance
extends RefCounted

static func needed_by(item: ItemInfo) -> PackedStringArray:
	var names := PackedStringArray()
	if not is_instance_valid(Manager.instance): return names
	var regional := Manager.instance.regional
	for definition: CommunityProjectDefinition in regional.catalog.projects:
		if not regional.project_complete(definition.id) and regional.remaining_materials(definition.id).get(item, 0) > 0: names.append(definition.get_title())
	for coord: Vector3i in Manager.instance.transport.villages:
		var request := Manager.instance.transport.get_request(coord)
		if request != null and Manager.instance.transport.get_record(coord).phase == "available" and request.cargo.has(item): names.append(TranslationServer.translate(request.title_key))
	return names

static func view_recipe(item: ItemInfo) -> void:
	if item == null or not item.has_recipe(): return
	if Manager.instance.active_settlement.get_service(&"Blacksmith") == null: return
	var info := DataManager.instance.get_scene_by_name("crafting_ui")
	info.queue(func(loaded: SceneInfo) -> void:
		var instance := SceneManager.add(loaded, false)
		var ui := (instance.node as DraggableControl).content as CraftingUI
		ui.preview_only = true
		ui.inventory = Manager.instance.hub.stockpile
		instance.on_enter.emit()
		var index := ui.recipes.find(item)
		if index >= 0:
			ui.recipe_list.select(index)
			ui._select_recipe(index)
	)
