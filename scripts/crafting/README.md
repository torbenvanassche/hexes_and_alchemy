# Workshop orders

The blacksmith accepts batches of 1–99 items and up to eight orders including the active order. Choose a quantity, then craft or add it to the queue. Other recipes remain selectable while work runs.

Each order snapshots the recipe and per-item duration. All ingredients are reserved once when queued. Items finish individually; cancelling an active or queued order returns ingredients for unfinished items and keeps completed output. If stores fill, unfinished ingredients return safely. Cancellation buttons are available beside each order.

Crafting continues while its window is closed, pauses with the simulation and restores both the active batch and queued orders from saves. Version-one saves with one active item still load. CraftingManager owns reservations, refunds and progress; CraftingUI renders selection and order controls. Progress changes have a separate signal and hidden windows do not redraw it.

Tune item recipes and crafting_duration on ItemInfo resources. Project duration modifiers remain data driven. Use the development checkpoints and the blacksmith for manual inspection; there is no bundled automated test suite.
