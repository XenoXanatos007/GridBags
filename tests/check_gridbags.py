"""Run with workspace-local lupa: PYTHONPATH=.tools python tests/check_gridbags.py."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "tests/eso_mock.lua").read_text())
for name in ("Compatibility", "Activity", "SnapshotFilters", "Snapshots", "Equipment", "Routing", "Help", "RoutingUI", "SmartRouting", "Crafting", "GearRouting", "CraftingUI", "Layout", "GoldRouting", "GoldUI", "TransferTools", "RecipeGather", "ConfigCodec", "ToolsUI", "RoutingInsights", "DeliveryUI", "ProtectionUI", "RecipeGatherUI", "AdvancedFilters"):
    lua.execute((root / f"GridBags/{name}.lua").read_text())
addon = lua.execute((root / "GridBags/GridBags.lua").read_text() + "\nreturn G")
lua.globals().G = addon
lua.execute((root / "tests/scenarios.lua").read_text())
lua.execute((root / "tests/compatibility_snapshots.lua").read_text())
lua.execute((root / "tests/scroll_bank.lua").read_text())
lua.execute((root / "tests/search_return.lua").read_text())
lua.execute((root / "tests/advanced_filters.lua").read_text())
lua.execute((root / "tests/snapshot_filters.lua").read_text())
lua.execute((root / "tests/equipment.lua").read_text())
