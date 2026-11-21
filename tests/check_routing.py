"""Routing state-machine checks, with an asynchronous transfer simulator, Lua 5.1."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "tests/eso_mock.lua").read_text())
for name in ("Compatibility", "Activity", "SnapshotFilters", "Snapshots", "Equipment", "Routing", "Help", "RoutingUI", "SmartRouting", "Crafting", "GearRouting", "CraftingUI", "Layout", "GoldRouting", "GoldUI", "TransferTools", "RecipeGather", "ConfigCodec", "ToolsUI", "RoutingInsights", "DeliveryUI", "ProtectionUI", "RecipeGatherUI", "AdvancedFilters"):
    lua.execute((root / f"GridBags/{name}.lua").read_text())
g = lua.execute((root / "GridBags/GridBags.lua").read_text() + "\nreturn G")
lua.globals().G = g
lua.execute("G:Initialize()")
lua.execute((root / "tests/routing.lua").read_text())
lua.execute((root / "tests/smart_routing.lua").read_text())
