# GridBags 0.15.3 — Beta 1

First public beta for PC keyboard/mouse. The addon manifest remains 0.15.3 (AddOnVersion 25, API 101051); the prerelease tag is `v0.15.3-beta.1`.

Download **GridBags-0.15.3-beta.1.zip** from the release assets and extract its `GridBags` folder into your ESO `live/AddOns` folder. Do not install the GitHub Source code archive as an addon.

Includes inventory/bank grids, searchable snapshots, optional filter/knowledge/decorator integrations, explicit item and gold planning, profession routing, known-recipe ingredient gathering and exact unique-item delivery reconciliation. See the README and beta testing checklist for details and limits.

No required libraries; optional integrations need separate installation. Disable GridList, GridPadInventory and BankManagerRevived during initial testing. New installations have no automatic transfer rules or plans enabled. Character snapshots and routing are restricted to the player's own account/world.

905 mocked behavior checks passed. Additional installed-addon contract checks and actual saved-data replays passed. In-game development tests confirmed main grid/bank interactions, routing, ingredient gathering and reconciliation; wider beta testing is still required.

The ZIP includes only the addon and its MIT license/install note. It includes no player SavedVariables, inventories, logs, credentials, third-party libraries, test tooling or unrelated project files.

Report bugs through Issues, using reproduction steps and redacted diagnostics. Inspect uncertain transfers before cancelling or replanning; cancellation never reverses completed moves.
