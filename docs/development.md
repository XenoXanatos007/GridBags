# Development and validation

Runtime files are in `GridBags/`; install that folder as an ESO addon. Python and Lupa are test dependencies only, never game dependencies.

Use Python 3.12 or newer and install `lupa`. The tests explicitly use its Lua 5.1 runtime:

```sh
python -m pip install lupa
python tests/check_gridbags.py
python tests/check_routing.py
python tests/check_planner.py
python tests/check_gold_layout.py
python tests/check_transfer_tools.py
python tests/check_crafting.py
python tests/check_insights.py
python tests/check_any_protection.py
python tests/check_gear_routing.py
python tests/check_cross_recipe.py
python tests/check_recipe_gather.py
```

The first beta has 905 passing mocked behavior checks. Additional optional checks require local files:

```sh
python tests/check_installed_integrations.py /path/to/AddOns
python tests/check_saved_snapshot_ui.py /path/to/SavedVariables/GridBags.lua
python tests/check_saved_arrivals.py /path/to/SavedVariables/GridBags.lua
```

These read local data without editing it. Never commit that data or test output containing private inventories. Mock replay is not actual game execution. Keep source validation, package verification, installation and game acceptance separate.

Runtime conventions: preserve native item action handlers; physical planned moves use the documented secure RequestMoveItem gateway and must verify observed counts. A request return is not proof of success. Preserve uncertain holds, per-source protections, finite approvals and bank reservations. Never use a saved snapshot as authorization for a physical transfer or unique-item completion. Treat item IDs, unique instance IDs and stack quantities as distinct evidence.

Do not silently migrate or discard a player's rules, approvals, reservations, snapshots or held outcomes. Settings and SavedVariables remain local to the player's account/world.

## Credits

GridBags by XenoXanatos. Thanks to beta testers and the authors of Advanced Filters, LibFilters, LibAddonMenu, LibCustomMenu, Research Assistant, Character Knowledge, CraftStore and BankManagerRevived for the optional APIs and integration surfaces. ESOUI's public API documentation and native UI sources informed compatibility research. Third-party addons and libraries are not bundled or relicensed by this project. ESO and its artwork belong to their respective owners.
