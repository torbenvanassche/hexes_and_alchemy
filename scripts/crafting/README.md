# Timed crafting

Each `ItemInfo` resource exposes `crafting_duration`, in seconds. It defaults to
1.0 for every item, including existing recipes and equipment. Change it on the
item resource in the inspector to tune individual recipes. Running jobs snapshot
their duration and ingredients, so edits do not change work already started.

`CraftingManager` owns one active `CraftingJob`, separate from the blacksmith
window. Materials are reserved once on start; one output item is added when the
timer finishes. The craft button's background fills from left to right beneath
its progress percentage.
Recipe selection stays on the active item until completion. A completion toast
uses the item's icon and the journal receives its existing `craft_<item id>` task.

Work continues when the window closes, pauses with the game and resumes from its
saved elapsed time after loading. Older saves start with no active craft. If the
output inventory fills while working, the ingredients are returned instead of
losing them. There is no automatic repeat or crafting queue.

Run `res://tests/crafting_test.tscn` with isolated user data. It checks timing,
progress, duplicate clicks, recipe selection, closing/reopening, pause, active and
completed saves, notifications and material refunds. With graphics enabled,
`-- --capture` saves progress/completion previews in `.godot/validation`.
