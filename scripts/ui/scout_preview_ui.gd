class_name ScoutPreviewUI extends PanelContainer

@onready var _route: ScoutRoutePreview = %Route
@onready var _metrics: HBoxContainer = %Metrics
@onready var _availability: Label = %Availability

var _offer: QuestOfferPreview

func set_offer(offer: QuestOfferPreview, distance: int) -> void:
	_offer = offer
	%Distance.text = tr("QUEST_DETAIL_SCOUT_DISTANCE") % distance
	_route.set_route(offer.scout_route)
	_route.visible = not offer.scout_route.is_empty()
	%Legend.visible = _route.visible
	%Trip.text = tr("SCOUT_PREVIEW_TIME") % offer.scout_round_trip_seconds
	%TripDetail.text = "SCOUT_PREVIEW_TRAVEL_ONLY"
	tooltip_text = tr("QUEST_DESC_SCOUT")

func update_survey(clock: TimeOfDay, depart_at_dawn: bool) -> void:
	var survey := _offer.get_scout_survey(clock, depart_at_dawn)
	_metrics.visible = survey != null
	if survey == null:
		if depart_at_dawn:
			_availability.text = tr("SCOUT_PREVIEW_WAIT_DAWN") % (clock.get_day_number() + 1)
		else:
			_availability.text = tr("SCOUT_PREVIEW_WAIT")
		return
	%Survey.text = "%02d:%02d" % [floori(float(survey.minute) / 60.0), survey.minute % 60]
	%SurveyDetail.text = tr("HUD_TIME_DAY") % survey.day
	%Coverage.text = tr("SCOUT_PREVIEW_RADIUS") % survey.radius
	%Coverage.theme_type_variation = &"StatusTravelLabel" if survey.night else &"SectionTitle"
	%CoverageDetail.text = "SCOUT_PREVIEW_NIGHT" if survey.night else "SCOUT_PREVIEW_DAYLIGHT"
	_availability.text = tr("SCOUT_PREVIEW_SCOUT") % _offer.scout_name
