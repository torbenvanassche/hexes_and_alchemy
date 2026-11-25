extends DraggableControl

const VIEWPORT_PADDING := Vector2(32.0, 32.0)
const MINIMUM_FIT := Vector2(300.0, 120.0)

func _get_content_fit_size() -> Vector2:
	var content_size := super._get_content_fit_size()
	var available_size := (get_viewport_rect().size - VIEWPORT_PADDING).max(MINIMUM_FIT)
	return content_size.min(available_size)
