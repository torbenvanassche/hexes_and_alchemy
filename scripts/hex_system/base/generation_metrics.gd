class_name GenerationMetrics
extends RefCounted
## Opt-in CPU measurements. Stages ending in "_elapsed" include asynchronous waits.

class Sample extends RefCounted:
	var calls := 0
	var total_usec := 0
	var maximum_usec := 0

var enabled := false
var samples: Dictionary[String, Sample] = {}

func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

func end(stage: String, started: int) -> void:
	if not enabled: return
	record(stage, Time.get_ticks_usec() - started)

func record(stage: String, elapsed: int) -> void:
	if not enabled: return
	if not samples.has(stage): samples[stage] = Sample.new()
	var sample := samples[stage]
	sample.calls += 1
	sample.total_usec += elapsed
	sample.maximum_usec = maxi(sample.maximum_usec, elapsed)

func report() -> String:
	var lines: PackedStringArray = []
	for stage: String in samples:
		var sample := samples[stage]
		lines.append("%s: calls=%d total=%.2fms max=%.2fms" % [stage, sample.calls, sample.total_usec / 1000.0, sample.maximum_usec / 1000.0])
	return "\n".join(lines)
