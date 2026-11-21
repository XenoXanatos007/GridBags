"""Replay a local SavedVariables data file through mocked UI contracts, read-only."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument("saved_variables", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "tests/eso_mock.lua").read_text())
for name in ("Compatibility", "Activity", "SnapshotFilters", "Snapshots", "Equipment", "Routing", "Help", "RoutingUI", "SmartRouting", "Crafting", "GearRouting", "CraftingUI", "Layout", "GoldRouting", "GoldUI", "TransferTools", "RecipeGather", "ConfigCodec", "ToolsUI", "RoutingInsights", "DeliveryUI", "ProtectionUI", "RecipeGatherUI", "AdvancedFilters"):
    lua.execute((root / f"GridBags/{name}.lua").read_text())
g = lua.execute((root / "GridBags/GridBags.lua").read_text() + "\nreturn G")
lua.globals().G = g
lua.execute('G:Initialize(); G.sceneName="inventory"')
data = lua.eval("""function(source)
    local env = {}; local f = assert(loadstring(source)); setfenv(f, env); f()
    return env.GridBagsSavedVariables
end""")(args.saved_variables.read_text(encoding="utf-8-sig"))
s = lua.globals().GridBagsSnapshots
count = 0

def verify(key, record):
    global count
    s.Select(s, g, key)
    ui = g.backpack.savedFilterUI
    assert not ui.control.IsControlHidden(ui.control), record["name"]
    assert not ui.category.IsControlHidden(ui.category), record["name"]
    assert bool(ui.category.enabled) == bool(record["afFilters"]), record["name"]
    assert g.backpack.filters[1].IsHidden(g.backpack.filters[1]) == bool(record["afFilters"])
    print(f"PASS: {record['name']}: visible snapshot area; detailed filters {'enabled' if record['afFilters'] else 'refresh required'}")
    count += 1

for profile in data.values():
    for account in profile.values():
        for settings in account.values():
            if not hasattr(settings, "items"):
                continue
            for world, records in (settings["snapshots"] or lua.table()).items():
                s.world = world
                for key, record in records.items():
                    s.records[key] = record
                    verify(key, record)
            for world, record in (settings["bankSnapshots"] or lua.table()).items():
                s.world = world
                g.saved.bankSnapshots[world] = record
                verify("@account-bank", record)
print(f"PASS: {count} real saved views replayed with mock controls; game rendering remains unverified.")
