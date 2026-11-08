class_name WorldGenerationProgress
extends RefCounted
## Weighted phases are monotonic; per-tile work supplies measured fractions.
var value := 0.0
var stage_key := "LOADING_PREPARING"
var error := ""

func report(fraction: float, stage: String) -> void:
	value = maxf(value, clampf(fraction, 0.0, 1.0))
	stage_key = stage

func fail(message: String) -> void:
	error = message
