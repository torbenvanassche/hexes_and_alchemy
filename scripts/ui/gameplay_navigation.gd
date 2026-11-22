class_name GameplayNavigation
extends Node

func _ready() -> void:
	Manager.instance.regional.commission_requested.connect(open_commission)
	Manager.instance.regional.request_requested.connect(open_request)

func open_commission(site: QuestObjective, preferred: Array[String], scouting := false) -> void:
	if not scouting and not is_instance_valid(site): return
	var info := DataManager.instance.get_scene_by_name("quest_creation_ui")
	info.queue(func(loaded: SceneInfo) -> void:
		if not scouting and not is_instance_valid(site): return
		var window := SceneManager.add(loaded, false)
		var ui := (window.node as DraggableControl).content as QuestCreationUI
		if scouting: ui.setup_scouting_request()
		else: ui.force_data(site)
		window.on_enter.emit()
		if is_instance_valid(site):
			var selection := ""
			for key: String in preferred:
				if not site.get_filtered_quest_types().has(key): continue
				if selection.is_empty(): selection = key
				if site.has_required_supplies(key, Manager.instance.hub.stockpile) and _has_available_provider(site.get_profile(key)):
					selection = key
					break
			if not selection.is_empty(): ui.select_commission_type(selection)
	)

func open_request(id: String) -> void:
	var info := DataManager.instance.get_scene_by_name("quest_list_ui")
	info.queue(func(loaded: SceneInfo) -> void:
		var window := SceneManager.add(loaded, false)
		window.on_enter.emit()
		var board := (window.node as DraggableControl).content as QuestListUI
		board.show_request(id)
	)

func _has_available_provider(profile: QuestProfile) -> bool:
	if profile == null: return false
	for faction: FactionState in Manager.instance.hub.factions.values():
		if faction.get_available_member_count_for_role(profile.get_required_role()) > 0: return true
	return false

