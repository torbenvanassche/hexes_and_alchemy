class_name StateMachine extends Node

var states: Array = [];
var _current_state: String;
var update_bindings: Dictionary[String, Callable];
var frozen: bool = false;

func set_state(state_name: String) -> bool:
	if _current_state != state_name && !frozen:
		if states.has(state_name):
			state_exited.emit(_current_state);
			_current_state = state_name;
			state_entered.emit(state_name);
			return true;
		else:
			on_state_not_found(state_name)
	return false;

signal state_entered(state: String);
signal state_exited(state: String);

func freeze() -> void:
	frozen = true;

func unfreeze() -> void:
	frozen = false;

func bind_update(state: String, f: Callable) -> void:
	update_bindings[state] = f;
	
func update() -> void:
	if update_bindings.has(_current_state):
		update_bindings[_current_state].call();

func on_state_not_found(state_name: String) -> void:
	Debug.warn("State %s is not found in the available states!" % state_name)

func _init(_states: Array = []) -> void:
	states = _states;
	
func get_states() -> Array:
	return states;
	
func get_current_state() -> String:
	return _current_state;
