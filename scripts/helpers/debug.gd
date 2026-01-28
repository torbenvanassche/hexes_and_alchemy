extends Node

var show_log: bool = true;

func message(s: String) -> void:
	if show_log:
		print("MESSAGE: %s" % [s]);
		
func warn(s: String) -> void:
	if show_log:
		push_warning(s);
		print("WARNING: %s" % [s]);
		
func err(s: String) -> void:
	if show_log:
		printerr(s);
		print("ERROR: %s" % [s]);
