# Community and exploration progression

`RegionalProgression` owns village requests, incidents and exploration unlocks. It observes completed guild operations. `SettlementCampaign` owns the unified opening chapter: blacksmith, any two village improvements, then a trade partnership. Trading and optional exploration remain available alongside the suggested order.

Quest board → Village requests offers three villager-authored projects from
the start. Opening the blacksmith is an explicit completion requirement; related
guild work can be arranged earlier. The separate **Guild commissions** tab
contains player-posted work, its posting/scouting controls and ongoing jobs.
Authorship headings, named requesters and tab counts keep the two roles distinct.
Village requests use compact horizontal table rows, stacked vertically beneath
aligned request, requester and status columns. A vertical scrollbar gutter stays
reserved as the list grows. Request details use the same 56px item slots as mine commissions,
checkbox objectives and shared icon counters for coins, prestige and reputation.
`CommunityProjectDefinition.benefits` supplies compact, typed permanent-effect
badges; recipe rewards use item slots explicitly marked as recipe unlocks.

| Project / resident | Fieldwork | Permanent benefit |
| --- | --- | --- |
| Water / Mara Fen | Complete a water-source commission | Water work 20% faster; one extra filled bucket per draw |
| Food / Tamsin Reed | Complete a farm harvest or collection | One extra grain per harvest; Quartermaster kit recipe |
| Workshop / Bram Holt | Complete mine work | Repair commissions 20% faster; supply crafting 15% faster; Reinforced tools recipe |

Each project requires successful related fieldwork, materials, coins and prestige.
Permanent projects cannot be instantly funded. Water fieldwork authorizes a well
blueprint for coins/prestige; the foundation collects construction supplies once.
Its persistent benefit and rewards activate only when the well is finished.
Food and workshop hand in their materials at completion. Local incidents retain
their separate option to hire local help. Authors are represented by named notices, with no
stationary quest-giver NPCs or separate dialogue window. Local incidents are
also posted by the relevant resident. Completed requests are hidden from the open
list; use **Completed requests** to review them. The well is a player-placed world structure; other projects add small props.
Journal → Village retains settlement upgrades; it has no duplicate project controls.

Open the blacksmith, complete any two projects and establish a trade partnership to
finish **A thriving foothold**. The game continues. Ruin expeditions are optional. Cataloguing a ruin once also
unlocks the Surveyor's kit. All three unlocked recipes create functional equipment
using the existing equip/quest-modifier system, rather than cosmetic collectibles.

## Authoring and tuning

- `resources/regional/catalog.tres`: explicit typed catalog of discoveries,
  community projects, incidents and additional commission sets.
- `discoveries/*.tres`: weighted initial conditions and short descriptions per
  site type. Intact/opportunity states are more common than broken states. The
  required starting forest/mine are restricted to usable variants. World seed and
  tile coordinate make rolls repeatable. Sites roll once when revealed.
- `projects/*.tres`: residents, fieldwork choices, costs, benefits text, recipe
  unlocks, immediate supplies and project prop. Work/crafting multipliers, bonus
  loot, objective/exploration keys and improvement transforms are configured here.
  Managers apply these typed settings without branching on project IDs.
- `resources/quest_profiles/regional_*.tres`: new commission approaches, costs,
  duration, outcome loot, service fees and standing rewards. Existing profiles
  have also been balanced and gained explicit consequence text.
- `incidents/*.tres`: eligible source states, temporary problem state, repair
  commissions, local-worker cost and completion reward.
- `RegionalProgression.incident_interval`: simulation seconds between requests
  (default 180). Time pauses with the game. Requests only begin after one completed
  project and three returned commissions. One active request at a time, no
  deadline or escalating penalty. Each authored request occurs once per chapter.
  Active commission targets and supported/protected sources are excluded.
- Project `improvement_position` / `improvement_scale`: completed props in the plaza.
  No request-author NPCs or interaction triggers spawn.

## Choices with lasting effects

- **Selective cutting** is slower and costs supplies/seeds; leaves the forest
  healthy. Heavy felling yields more timber and depletes the grove. Offcuts can be
  recovered once per regrowth cycle; they cannot be harvested repeatedly.
- **Mine supports** last three extractions and reduce collapse chance by 75%.
  Proper repairs restore the vein and supports. Quick shoring uses cheaper raw
  timber but adds eight percentage points of collapse risk on the next extraction.
  Deep extraction rolls base-vein loot twice with greater collapse/exhaustion
  risk. Depth loot still rolls once, as shown in the reward preview.
- **Protect spring** prevents tainting for three draws. Careful drawing costs
  more and takes longer but yields more water while leaving it fresh.
- **Careful harvest** trades one work supply and extra time for 5–8 grain and
  seeds. Rushed harvesting returns sooner with a smaller crop.
- **Catalogue ruins** is a one-time alternative to consuming the site through
  salvage. It leaves the ruin secured and awards knowledge/equipment access.

Maintenance/catalogue commissions can pay small local service fees. Fees,
incident bonuses and unlocks use the shared operation completion path and are
guarded against duplicate claims.

## Persistence and validation

New snapshots store typed project/incident records, unlocks, chapter state,
cooldown and the discovery/support counters on each site. Old checkpoint states
are preserved rather than rerolled. Unexplored sites in new saves retain their
unresolved status and can still roll on later discovery. Improvement props are
rebuilt from project state. Older tracked-resident references now lead to the
settlement quest board.

Run `tests/regional_progression_test.tscn` for discovery determinism, objective
effects, real commission posting, costs, duplicate-claim protection, project
benefits, recipe locks, incidents, save/load and UI bounds at 720p and 540p. Add
`-- --capture` with a renderer to save UI previews in `.godot/validation`.
