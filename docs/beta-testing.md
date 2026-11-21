# First beta testing

Use the installable ZIP attached to the GitHub prerelease or the approved ESOUI download. Extract its `GridBags` folder directly into your ESO `live/AddOns` folder, beside your other addons. The result must be `AddOns/GridBags/GridBags.txt`, without an extra nested folder. Enable GridBags and reload the UI.

Disable GridList and GridPadInventory while testing. Disable BankManagerRevived before using GridBags planned transfers: GridBags refuses to execute its routes while that automatic mover is loaded. Install optional addons and their dependencies separately; none are bundled.

Start on one character with inexpensive items. New installations have no transfer rules or plans enabled. Your inventories are separate from another player's account; character routing and snapshots only cover your own account/world.

1. Open inventory with your usual key. Test search, filters, scrolling, tooltips, use, drag and Standard view / GridBags view. Confirm Escape and normal closing keys still work after leaving a search field.
2. Open a personal bank. Verify both grids, subscriber-bank contents when applicable, displayed gold and manual deposits/withdrawals.
3. Log into a second character, then return. Its saved backpack/equipment should be searchable and read-only. The current character stays live. Bank snapshots are last observed contents, not remote bank access.
4. Plan one inexpensive stack delivery. Review its source, recipient, quantity and approval. Deposit on the source character's bank visit, then collect on the recipient's visit. Check the log for requested and verified counts. Full inventories, missing stock and uncertain outcomes should explain why they stopped.
5. Assign profession Crafter roles before testing blanket rules. Native profession materials should stay within their profession. Style and trait materials have separate categories. Furniture materials should remain with a matching assigned crafter unless a specific manual/recipe move is confirmed.
6. Select a known, skill-qualified food/drink/furnishing recipe and choose Gather ingredients. Compare required quantities, existing supplies, incoming plans and proposed source stacks. Exclude one source, confirm, and perform the needed bank visits. Unknown recipes must not be eligible. After crafting manually, release the request's ingredient hold under Requests / release.
7. Test deconstruction/research suggestions using refreshed profession/knowledge snapshots. These plan delivery to the recipient's backpack; they do not deconstruct, research or equip anything.
8. If an exact unique gear item reaches its intended recipient outside the queue, its old source/bank delivery records should complete on login or a new bank visit. One arrival entry represents one physical item, even if several old records referred to it. Stackable materials and uncertain-result holds are not cleared this way.

## Reporting problems

Use GitHub Issues and include the GridBags version, keyboard/mouse mode, steps, expected versus actual result, and relevant addon versions. For a Lua error, capture the error and stack trace if possible. GridBags Log > Report generates a redacted troubleshooting report. Inspect screenshots and reports before posting. Do not upload your complete SavedVariables, account names, character inventories or raw client logs publicly.

If a transfer result is uncertain, inspect the actual source, bank and recipient before cancelling or creating a replacement. Repeatedly retrying an uncertain move can confuse the reservation history. Cancelling releases the reservation and never reverses a completed move.

## Current limits

- PC keyboard/mouse interface; controller mode is not the target.
- Transfers require the relevant character and an open personal bank. Offline snapshots only plan moves.
- Housing storage, guild banks and furnishing vault are not routing sources.
- Gather supports the native learned recipe catalogue; it does not assemble arbitrary alchemy, enchanting or equipment crafting selections.
- Recipe holds require manual release after crafting. Missing or old observations can hold suggestions/deliveries.
- Optional addon contracts and automated tests do not guarantee every addon combination. Record conflicts rather than assuming all integrations are certified.
