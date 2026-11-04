# Packhorse shipments

Explore the neighbouring village and interact at its central market. This establishes
contact and opens the normal market. Choose **Shipments** to see delivery requests. The same window is available from the
journal's Village page, so dispatching does not require another walk back to the
village. **Locate village** uses the existing tracking arrow.

The first request is deliberately small: **3 raw wood and 1 iron ore**, paying
24 coins, 2 reputation, 1 prestige, and 1 local influence on delivery. The next
request asks for 2 travel rations and 2 raw wood and pays 36 coins. These two
request resources rotate when the player chooses **Next request** after return.
There are no deadlines, automatic repeat orders, or random losses in this version.

The guild begins with one packhorse. It carries up to eight load units (one per
item), consumes goods from the shared stores once at dispatch, follows a mapped
walking route, delivers, and returns home. It cannot be dispatched twice or used
for another destination while travelling. Payment happens once on delivery;
the horse becomes available again when it returns. A recalled outbound horse
brings its cargo home without payment. Blocked journeys stop safely and offer
resume/recall; no cargo is discarded when a route is unavailable.

The KayKit horse model uses the project's existing palette with simple panniers.
Movement uses the same navigable hex connections, wall/gate restrictions, bridges,
and terrain surface heights as other walking units. It is graph-guided movement,
not a physics vehicle. The journey pauses with the game. Shipments can be saved
while travelling, returning, recalled, or blocked; cargo, rewards, village contacts,
and delivery influence persist. Older saves with no transport data start with a
fresh transport state. Active commissions still follow the existing save limit.

## Upgrade and roads foundation

`TransportCarrier` resources hold model, speed, and capacity. The first carrier is
`resources/shipments/packhorse.tres`; a horse pulling a cart can later supply a new
carrier definition and larger contracts. No cart upgrade purchase UI is included.

Travel speed respects each hex's existing `movement_cost`, and routing already
uses that cost. Future roads can lower it to make an established route faster.
This change does **not** add road construction, placement tools, road meshes,
construction costs, or automatic road connections. The road art is available in
the KayKit hexagon pack when that feature is implemented.

`TransportManager` owns transactions, path validation, journey state, and notices.
Shipment request resources own cargo and payout balance. `VillageTrade` supplies
the village market interaction. `transport_ui.tscn` uses the shared draggable
window and theme. Save capture/restore stores the transport fields alongside the
existing settlement state; load restores visuals after navigation is rebuilt.

## Testing

Use **Pause → Checkpoints → Neighbouring village**, walk to the central market and interact,
then dispatch. The bundled checkpoint has enough supplies for the first request.

`res://tests/transport_test.tscn` covers contact, UI, missing goods, unreachable
routes, capacity, duplicate dispatch, movement, pause, blockage/resume, delivery,
repeat requests, recall, and mid-journey save/load without duplicate cargo or pay.
Run with isolated user data because the test writes named checkpoint files.
Append `-- --capture` with graphics enabled for UI previews.
