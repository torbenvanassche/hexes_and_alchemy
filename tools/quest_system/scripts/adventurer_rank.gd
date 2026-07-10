class_name AdventurerRank
extends RefCounted

enum Rank {
	F,
	E,
	D,
	C,
	B,
	A,
	S,
}

static func clamp_rank(rank: int) -> Rank:
	return clampi(rank, 0, Rank.keys().size() - 1) as Rank

static func get_next(rank: Rank) -> Rank:
	return clamp_rank(int(rank) + 1)

static func is_at_least(rank: Rank, minimum: Rank) -> bool:
	return int(rank) >= int(minimum)

static func get_key(rank: Rank) -> String:
	return Rank.keys()[int(clamp_rank(rank))]

static func get_translation_key(rank: Rank) -> String:
	return "ADVENTURER_RANK_%s" % get_key(rank)

static func get_display_name(rank: Rank) -> String:
	var translation_key := get_translation_key(rank)
	var translated := String(TranslationServer.translate(translation_key))
	return get_key(rank) if translated == translation_key else translated

static func get_speed_multiplier(rank: Rank, bonus_per_rank: float) -> float:
	return 1.0 + maxf(0.0, bonus_per_rank) * float(int(rank))
