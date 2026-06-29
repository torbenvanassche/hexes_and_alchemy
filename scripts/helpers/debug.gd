extends Node

var show_log: bool = true;
var notify_runtime: bool = true;

func message(s: String) -> void:
	if show_log:
		print("MESSAGE: %s" % [s]);
	
	if notify_runtime:
		Manager.instance.toast.notify(s)
		
func warn(s: String) -> void:
	if show_log:
		push_warning(s);
		print_rich("[color=yellow]WARNING: %s[/color]" % s)
	if notify_runtime:
		Manager.instance.toast.notify(s, Color.YELLOW)
		
func err(s: String) -> void:
	if show_log:
		printerr(s);
	if notify_runtime:
		Manager.instance.toast.notify(s, Color.RED)
