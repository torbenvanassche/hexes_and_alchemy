class_name ProjectProgress
extends RefCounted

static func stages(definition: CommunityProjectDefinition, state: CommunityProjectState, regional: RegionalProgression) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"text": TranslationServer.translate("PROJECT_STAGE_SERVICE"), "done": regional.is_unlocked()})
	rows.append({"text": TranslationServer.translate(definition.objective_key), "done": state.fieldwork_done or state.completed})
	if definition.construction != null:
		rows.append({"text": TranslationServer.translate("PROJECT_STAGE_AUTHORIZE"), "done": state.blueprint_issued})
		rows.append({"text": TranslationServer.translate("PROJECT_STAGE_PLACE"), "done": state.completed or regional.get_project_buildable(definition.id) != null})
	rows.append({"text": TranslationServer.translate("PROJECT_STAGE_BUILD" if definition.construction != null else "PROJECT_STAGE_CONTRIBUTE"), "done": state.completed})
	rows.append({"text": TranslationServer.translate("PROJECT_STAGE_ACTIVE"), "done": state.completed})
	return rows
