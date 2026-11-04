# Development checkpoints

In the editor, open **Pause → Checkpoints → Development checkpoints**. Each option
loads a complete save through the normal checkpoint loader. Personal saves stay
separate in `user://saves`; saving after loading a fixture creates a personal branch.
The bundled files are never overwritten by in-game saving. Development options are
hidden in release builds.

All four fixtures share world seed **20261102**:

| Checkpoint | State |
| --- | --- |
| Fresh arrival | Level 1, five starting guild members, 100 coins, opening objectives untouched. |
| Forge foundation | Blueprint bought and legally placed; one timber paid for and delivered. One timber and five iron ore remain. |
| Blacksmith open | Building finished, settlement upgraded to level 2, workshop objective complete. 250 coins, 12 timber, 10 iron ore, and six extra travel rations for testing. The timber commission objective remains available. |
| Neighbouring village | Extends the blacksmith checkpoint, reveals the walking route and village, and places the player at its entrance. |

No fixture contains active commissions. The later checkpoints intentionally add
working capital and supplies; they are testing scenarios, not balance benchmarks.

## Regeneration

Run the dedicated scene in a separate Godot process with:

```text
godot --headless --path . res://development/generate_checkpoints.tscn -- --generate-development-checkpoints
```

This rebuilds the four JSON files in `development/checkpoints` using the current
world generation and construction/upgrade APIs. It does not write personal saves.
Use this after changes to the save schema, content paths, building scene paths,
or world generation. Check the resulting file changes before retaining them.
The world seed is fixed; generated people and recruitment pools can vary.

Verify with:

```text
godot --headless --path . res://tests/development_checkpoints_test.tscn
```

Run tests with an isolated user-data directory: they create named test saves.
The test loads every fixture, checks progression and preservation of personal
saves, returns from later progress to arrival, and exercises submenu navigation
and loading. With graphics enabled, append `-- --capture` for a screenshot.

Editor runs read the JSON files directly. For exported debug builds, include
`development/checkpoints/*.json` in the export's non-resource file filter if
needed. Exclude the `development` directory from release exports.
