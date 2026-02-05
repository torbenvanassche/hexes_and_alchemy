class_name ContextMenuItem
extends Node

var id: String;
var function: Callable;
var submenu: ContextMenu;
var enabled: bool;
var idx: int = -1;

func _init(i: String, f: Callable, _submenu: ContextMenu = null, _enabled: bool = true) -> void:
	id = i;
	function = f;
	enabled = _enabled;
	submenu = _submenu;
