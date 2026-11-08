# Opening-chapter playtest

Start a new world or use Fresh arrival. Later checkpoints intentionally skip parts
of the opening and include extra resources/money. Existing checkpoint files have
not been regenerated.

## Intended journey

1. Acquire the forge blueprint, commission or buy materials, and open the forge.
   Opening it grants 20 coins once to help fund the next choices.
2. Choose any two village requests at the quest board. Complete fieldwork and
   contribute materials, or pay for the whole project. The third request can wait.
3. Discover the neighbouring village and arrange the two introductory shipments
   from the journal Trade page. These can be pursued earlier if preferred.
4. Two improvements plus the blacksmith and a trade partnership finish A thriving
   foothold. The journal keeps a visible conclusion; a one-time grant of 40 coins
   and 2 prestige supports continued play. The world stays open.

Ruin expeditions are optional. They retain their own rewards and recipe unlocks.
Settlement upgrades, additional requests, incidents and repeat deliveries remain
available after the chapter.

## First balance pass

| Area | Current baseline |
| --- | --- |
| Starting treasury / forge blueprint | 100 / 30 coins |
| Forge material requirement | 2 timber, 5 iron |
| Safe forest forage | 2–3 timber, optional seeds, 2-coin service fee |
| Basic mine extraction | 3–5 iron, 6 seconds of work, 4-coin service fee |
| Mine prospecting | 4 seconds, 3-coin service fee |
| Crop planting / watering / harvest | 4 / 3 / 6 seconds of work |
| Village contributions | Water/food 15 coins; workshop 20; each costs 1 prestige plus materials/fieldwork |
| Fully funded village requests | Water/food 45 coins; workshop 55, plus 1 prestige |
| Healthy recovery | 2 seconds plus 25% of job work time before risk/injury modifiers |
| Crop watering / standing-crop windows | 180 / 300 seconds |

Travel adds to the work times. Posted pay is a player-selected expense and stays
reserved until completion/cancellation. Service fees are separate rewards for
successful work, not refunds of that offered pay. Danger, support and advanced
approach trade-offs still apply. These are starting values for human playtesting,
not a claim that the full economy is balanced.

Chapter targets/grants live in resources/campaign/opening_chapter.tres. Job
profiles, loot tables and regional project resources own their own tuning. The
base crop windows live on FarmTile; recovery uses default_adventurer_recovery.tres.

## Saving during work

Save/load while a commission is waiting, travelling, working, returning, and
complete with auto-collect disabled. The party and reserved supplies/payment
should remain intact. Working jobs retain remaining time; travel routes are
recalculated from saved positions. Already rolled loot/outcomes/fates are retained.
Check simultaneous scouting/resource jobs too. Cancelling should refund once;
collecting should pay once. Saves still wait for world streaming to finish.

## Useful observations

- Where the next useful action is unclear, especially after opening the forge.
- Waiting periods with nothing appealing to explore, arrange or build.
- Whether fieldwork and funding feel like meaningful alternatives.
- Items or money that become scarce or accumulate without a use.
- Whether improvements and the chapter ending feel rewarding.

## Automated validation

opening_chapter_test covers ordering, optional expeditions, the two-project target,
legacy checkpoints and once-only grants across reloads. commission_save_test
covers five active phases, concurrent jobs/scouting, remaining work, saved fates,
reservation/refund conservation and duplicate reward claims. Existing trade,
regional progression, quest-board, crafting and loading checks cover integration.
