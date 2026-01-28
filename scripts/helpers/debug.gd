extends Node

var show_log: bool = true;

func message(s: String) -> void:
	if show_log:
		print("MESSAGE: %s" % [s]);
		
func warn(s: String) -> void:
	if show_log:
		push_warning(s);
		print_rich("[color=yellow]WARNING: %s[/color]" % s)
		
func err(s: String) -> void:
	if show_log:
		printerr(s);
