# Extending the game

The runtime remains organized around existing services. Keep gameplay decisions
in managers/resources and presentation in controls; do not make a new feature
depend on a specific journal tab or a particular window being open.

## Ownership and persistence

| Area | Owner | Extension point |
| --- | --- | --- |
| Scene/item discovery | `GameContentCatalog`, `DataManager` | Explicit resources in `resources/catalogs/default_game_content.tres` |
| World generation | `HexGrid`, `MainGrid`, `StarterLayoutPlan`, `GenerationBudget` | Versioned terrain constraints, budgeted searches and finite world/pacing settings; see `WORLD_GENERATION.md` |
| NPC work | `QuestManager`, `QuestPostingService`, `OperationManager` | Quest profiles, supplies, outcomes, role requirements |
| World sites | `QuestObjective` subclasses | State-specific behaviours and occupation rules |
| Deliveries | `DeliveryQuest`, `DeliveryDefinition`, `DeliveryOutcome` | Reusable lifecycle; carrier movement stays separate |
| Settlement requests | `RegionalProgression`, `RegionalCatalog` | Typed project/discovery/incident resources |
| Blueprint placement | `WorldPlacement`, `StructurePlacementPreview` | Context-menu placement, shared drag preview, cancellation without consuming inventory |
| Crafting | `CraftingManager`, `CraftingJob`, `ItemInfo` | Per-item recipes/durations, one reserved job |
| Saves | `GameSnapshot`, `SaveCodec` | Explicit persisted fields and typed receiving properties |

Do not pay rewards in UI handlers. Managers own once-only completion guards,
inventory reservation/refunds and persistent unlocks. Closing a window must not
stop crafting, delivery movement or an assigned commission.

Budgeted generation helpers are coroutines: propagate `await` through their
callers and checkpoint inside loops. Use `HexAStar.rebuild_budgeted` during
startup or paused restoration; its graph is incomplete until the await finishes.
Keep new world-generation settings in `GameSnapshot.WORLD_SETTINGS`. Existing
saves without `generation_version` use version 1; new worlds use version 2.

## Add a community project

1. Create a `CommunityProjectDefinition` resource with a stable unique ID.
2. Set its author, objective/exploration translation keys, site kind, accepted
   commission keys, material/coin/prestige costs and completion rewards.
3. Configure permanent work modifiers with `duration_site_kinds` and/or
   `duration_behaviours`. Configure extra loot through `bonus_quest_keys` and
   `bonus_items`. Configure crafting through `crafting_item_ids` and its multiplier.
   Matching duration effects use the strongest benefit rather than multiplying
   overlapping discounts; matching item bonuses add together.
4. Set a recipe unlock if needed, plus the visual, position and scale of the
   completed improvement. Add compact `CommunityBenefit` UI entries describing
   the same effects. Keep these captions synchronized with the configured values.
5. Append the resource to `resources/regional/catalog.tres`. Register new item
   resources with the game-content catalog. Existing saves initialize missing
   project states; never rename shipped IDs without a migration.

These settings no longer require branches in the crafting manager, project UI,
reward calculations or improvement presentation. New *types* of effects still
need a deliberate gameplay implementation and corresponding persistence/tests.

## Add a commission or delivery

- Prefer a `QuestProfile` for a new approach to an existing site behaviour. Define
  required role, supplies, states, duration, outcomes and standing/service rewards.
- Add site behaviour code only for a genuinely new action. Use the shared posting
  service so failed posting refunds money and reserved supplies atomically.
- A delivery is a `DeliveryDefinition` plus its outcome, not a horse-specific
  quest. Movement and presentation belong to a carrier/controller.
- Static content uses resources; save state uses typed state records. Flexible
  `Dictionary[String, Variant]` is for serialization/metadata boundaries.

## UI conventions

- Service windows inherit `tools/custom_window/base_window.tscn`. Use its content,
  header-actions and footer extension points. Pause/settings remain full-screen
  overlays. Inherit frame/theme settings instead of copying nine-patch overrides.
- `themes/game_theme.tres` and `GameUI` own the visual language. Use existing
  heading/muted/tab/action variations and shared separators.
- `ItemPreview.create` builds readonly item slots for mine commissions, request
  contributions/rewards and crafting. Default commission slots are 56px; crafting
  can supply its own size and slot scene. Keep normal inventory slots interactive.
- `RewardStatUI` renders icon/value/caption groups. `set_amount` formats quantities;
  `set_text_value` supports percentage/duration effects without a separate widget.
- Request tables share column widths between header and rows. Reserve scrollbar
  gutters; put actions outside scrolling bodies. A status tooltip must repeat
  the full status, not inherit unrelated reward text from its parent.
- Do not reconstruct a window on every frame. Subscribe to relevant signals,
  coalesce expensive refreshes and disconnect when controls leave the tree.
- A held `SceneInfo` can queue itself directly; optional windows do not require a
  second lookup by ID. Gameplay still uses the explicit catalog for named lookups.

## Validation

`window_review_test` checks service windows and overlays at 1280×720 and 960×540,
including headers, bounds and fixed actions. `quest_board_test` covers table
columns, overflow, status tooltips and request actions. Add `-- --capture` with a
renderer to inspect actual screenshots under `.godot/validation`.

Run the relevant gameplay tests after changing shared components: typed-data,
regional progression, crafting, transport, trade campaign, settlement placement
and village boundary. See each subsystem's README for its own invariants. Tests
should isolate APPDATA/LOCALAPPDATA to avoid modifying a player's saves.

For a constructed improvement, set the project blueprint and construction resource.
Use a CommunityBuildable with foundation and finished Interaction steps. The
foundation recipe must match the project materials. Blueprint authorization charges
coins/prestige; delivery charges materials; finish_construction grants benefits once.
Completed legacy water requests keep their benefits and receive a placement permit
once, without another reward or payment.

ItemInfo.usage_key documents practical uses. CraftingGuidance marks current request
and shipment demand and opens recipe previews; crafting still takes place at the
blacksmith. Toast supports formatted text, item icons and grouped reward summaries.
