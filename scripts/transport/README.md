# Packhorse shipments

Discover a neighbouring village and map a connected route between the stables.
No visit or market interaction is needed to send a delivery. The market handles
buying and selling. Manage all delivery
requests directly from **Journal → Trade**. This dedicated tab shows cargo,
payment, trading relationships, and journey status with dispatch/recall controls.
Village contains construction and settlement upgrades; Commissions contains guild
work orders. Shipment management stays available regardless of campaign stage.
Dispatch consumes guild stores and the packhorse departs from the home stable;
the player can arrange it remotely and never needs to revisit the destination to
send goods there. **Locate village** uses the existing tracking arrow.

The first request is deliberately small: **3 raw wood and 1 iron ore**, paying
24 coins, 2 reputation, 1 prestige, and 1 local influence on delivery. After the
horse returns, **Prepare equipment delivery** asks for one field kit and two
processed wood. Craft these at the blacksmith; the field kit requires two work
supplies. This delivery pays 48 coins and 3 reputation, plus the normal prestige
and influence. The blacksmith must be open before dispatching this request.

Deliver both requests to the same village to become trade partners. Its market
unlocks six grain and replenishes its existing stock; extra goods crates appear
beside the stall. Further optional deliveries replenish stocks up to their normal
limits. The old timber/iron and rations/timber requests then alternate. Buying,
reopening the market, returning home, and loading a checkpoint do not refill stock.
There are no deadlines, automatic repeat orders, or random losses in this version.

The guild begins with one packhorse. It carries up to eight load units (one per
item), consumes goods from the shared stores once at dispatch, follows a mapped
walking route, delivers, waits three seconds to unload at the destination stable,
and returns home. It cannot be dispatched twice or used
for another destination while travelling. Payment happens once on delivery;
the horse becomes available again when it returns. A recalled outbound horse
brings its cargo home without payment. Blocked journeys stop safely and offer
resume/recall; no cargo is discarded when a route is unavailable.

The KayKit horse uses the matching saddle and sack meshes, at 80% of its original
scale. Sacks appear only while cargo is loaded. The idle/returned horse remains
at its home stable rather than disappearing. Both settlements use the existing
KayKit blue stable mesh, placed in the cleared exterior ring beside an entrance.
The plot and its front approach persist with the settlement and stay reserved
against expansion. The loading bay is reached through that front approach.

Static meshes use `CarrierMotion` for restrained distance-driven bobbing and
body sway, with smooth heading changes. The model, saddle and cargo share one
presentation offset; the ground position and delivery timing stay unchanged.
Motion settles at a stop and pauses with the simulation. Carrier scenes may opt
into these presentation methods without changing route or shipment data.

Merchant routes exclude settlement interiors, so the horse unloads at the village
stable and does not pass through gates or visit the central market. Shopping
still uses the market. Movement respects existing navigable hex
connections, bridges, and terrain surface heights. It is graph-guided movement,
not a physics vehicle. The journey pauses with the game. Shipments can be saved
while travelling, unloading, returning, recalled, or blocked; cargo, rewards, village contacts,
and delivery influence persist. Older saves with no transport data start with a
fresh transport state. Active guild commissions now also resume through CommissionSaveState.
Legacy in-flight routes are replanned to stables. Horses saved inside a settlement
resume from its stable with their cargo, phase, and payment state preserved.

## Upgrade and roads foundation

`TransportCarrier` resources hold model, speed, and capacity. The first carrier is
`resources/shipments/packhorse.tres`; a horse pulling a cart can later supply a new
carrier definition and larger contracts. No cart upgrade purchase UI is included.

Travel speed respects each hex's existing `movement_cost`, and routing already
uses that cost. Future roads can lower it to make an established route faster.
This change does **not** add road construction, placement tools, road meshes,
construction costs, or automatic road connections. The road art is available in
the KayKit hexagon pack when that feature is implemented.

`TransportManager` owns path validation, carrier movement, unloading time, village
relationships and notices. `ShipmentQuest` extends the reusable `DeliveryQuest`;
QuestManager and OperationManager share registration, lifecycle, cargo refunds,
outcomes and history with other quests. The delivery outcome consumes reserved
cargo and pays once at arrival; returning closes the operation. Deliveries do not
recruit guild members, occupy commission slots or appear on the quest board.
Their controls remain in Trade. Shipment request resources own cargo and payout
balance. `VillageTrade` supplies
the village market interaction. `components/trade_page.tscn` supplies the journal
page and uses the shared theme; `transport_ui.tscn` remains a window wrapper for
standalone previews. `TransportManager.open_window` opens the journal's Trade tab.
Save capture/restore stores the transport fields alongside the
existing settlement state; load restores visuals after navigation is rebuilt.
Requests have stable IDs stored with the loaded cargo. Legacy saves retain their
original two-request cycle (including in-flight rations deliveries) and gain no
partnership until an actual crafted-equipment delivery is recorded. Completion
proof and the one-time unlock flag live in each village's saved transport record.

## Authoring other deliveries

Create a `DeliveryDefinition` resource to set cargo, payment, reputation, prestige,
an optional journal completion task, and whether completion requires a return.
`ShipmentRequest` inherits this resource with trade defaults (one prestige and a
required return). These definitions contain no horse, route, speed, or animation.
Active quests snapshot the definition so later resource edits cannot change an
agreed cargo requirement or payment.

For a new delivery controller:

```gdscript
var quest := DeliveryQuest.new(recipient_hex)
quest.configure_delivery(definition)
if quest.reserve_cargo(source_inventory):
    if Manager.instance.quests.add_quest(quest):
        quest.set_state(Quest.QuestState.EN_ROUTE)
    else:
        Manager.instance.quests.release_quest_supplies(quest)
```

The controller defines and validates arrival, then sets `IN_PROGRESS` and calls
`resolve_delivery()`. This checks the reserved cargo, applies the outcome once,
and emits `delivered` for additional recipient behavior. Without a required return,
the quest completes immediately. Otherwise the controller sets `RETURNING` and
calls `finish_return()` after its own return condition is met. Cancel through
`QuestManager.cancel_quest()` to refund undelivered cargo to its source.

The horse controller implements those boundaries using stable arrival and a
saved unloading countdown. A different controller can use player interaction or
another transport method without changing `DeliveryQuest`. Both generic delivery
quests and shipment quests restore as their original types, with cargo, outcome
guards and history intact. Legacy journeys without quests acquire a shipment
quest from their existing manifest without another withdrawal or payout.

`ShipmentJourney` and `VillageTradeRecord` provide typed runtime state, including
`Dictionary[ItemInfo, int]` cargo and `Dictionary[String, int]` delivery counts.
Legacy dictionary records are converted at the save boundary; new gameplay code
reads named fields rather than dictionary keys. `DeliveryQuest.required_cargo`
is also a typed field, separate from the extensible quest context.

The campaign follows forge construction, village discovery, the first shipment,
crafted equipment, and partnership. Village shows the forge project followed by
the next optional settlement upgrade. Trade shows cargo requirements and loaded
goods, while campaign navigation opens the appropriate journal tab.

## Testing

Use **Pause → Checkpoints → Neighbouring village** and open **Journal → Trade**
to dispatch immediately, from any location.
The bundled checkpoint has enough supplies for the first request.

`res://tests/transport_test.tscn` covers discovery, remote first dispatch, UI, missing goods, unreachable
routes, capacity, duplicate dispatch, movement, pause, blockage/resume, delivery,
repeat requests, recall, and mid-journey save/load without duplicate cargo or pay.
Run with isolated user data because the test writes named checkpoint files.
Append `-- --capture` with graphics enabled for UI previews.

`res://tests/trade_campaign_test.tscn` exercises the opening/first partnership,
real crafting, local delivery proof, the market unlock, sold-out stock, optional
restocking, checkpoint resets, and legacy request migration. **Pause → Checkpoints
→ Trade partnership** opens the completed chapter directly.
