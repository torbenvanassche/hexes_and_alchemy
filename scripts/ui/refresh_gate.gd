class_name RefreshGate
extends RefCounted

## Coalesce signals; hidden cached windows retain dirty state until shown.
var _view: Control
var _refresh: Callable
var _dirty := true
var _queued := false

func _init(view: Control, callback: Callable) -> void:
	_view = view
	_refresh = callback
	_view.visibility_changed.connect(request)

func request() -> void:
	_dirty = true
	if _queued or not is_instance_valid(_view) or not _view.is_visible_in_tree(): return
	_queued = true
	_flush.call_deferred()

func _flush() -> void:
	_queued = false
	if not _dirty or not is_instance_valid(_view) or not _view.is_inside_tree() or not _view.is_visible_in_tree(): return
	_dirty = false
	_refresh.call()
