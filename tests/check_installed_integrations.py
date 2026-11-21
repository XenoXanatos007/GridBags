"""Exercise installed addon entry points against mocked ESO services, read-only.

The selected function bodies come from the installed files, rather than copies
of their behavior. This does not run an ESO client or qualify actual transfers.
"""
from pathlib import Path
import argparse
import hashlib
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument("addons", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "tests/eso_mock.lua").read_text())
for name in ("Compatibility", "Activity", "SnapshotFilters", "Snapshots", "Equipment", "Routing", "Help", "RoutingUI", "SmartRouting", "Crafting", "GearRouting", "CraftingUI", "Layout", "GoldRouting", "GoldUI", "TransferTools", "RecipeGather", "ConfigCodec", "ToolsUI", "RoutingInsights", "DeliveryUI", "ProtectionUI", "RecipeGatherUI", "AdvancedFilters"):
    lua.execute((root / f"GridBags/{name}.lua").read_text())
addon = lua.execute((root / "GridBags/GridBags.lua").read_text() + "\nreturn G")
lua.globals().G = addon
lua.execute((root / "tests/installed_integrations_fixture.lua").read_text())

def source(relative):
    raw = (args.addons / relative).read_bytes()
    print(f"SOURCE {relative}: SHA256 {hashlib.sha256(raw).hexdigest()[:16]}")
    return raw.decode("utf-8-sig")

def section(text, start, end):
    begin = text.index(start)
    return text[begin:text.index(end, begin + len(start))]

ra = source("ResearchAssistant/ResearchAssistant.lua")
ra_prefix = """
local RASettings, RAScanner = RAFixture.settings, RAFixture.scanner
local ornateTextureSizeMax, intricateTextureSizeMax, protectedTextureSizeMax = 48, 48, 48
local ORNATE_TEXTURE, INTRICATE_TEXTURE, PROTECTED_TEXTURE = 'ornate', 'intricate', 'protected'
local TOOLTIPS = {ornate='ornate', intricate='intricate', protected='protected'}
local LIBRESEARCH_REASON_INTRICATElower, LIBRESEARCH_REASON_ORNATElower = 'intricate', 'ornate'
local LIBRESEARCH_REASON_WRONG_ITEMTYPElower = 'wrong'
local TRACKING_STATE_RESEARCHABLE, TRACKING_STATE_DUPLICATE, TRACKING_STATE_KNOWN = 'researchable', 'duplicate', 'known'
local TRACKING_STATE_UNTRACKED = 'untracked'
local function HandleTooltips(control, callback) control.raTooltip = callback end
"""
lua.execute(ra_prefix
    + section(ra, "local function SetToOrnate", "local function buildItemTraitIconText")
    + section(ra, "local function AddResearchIndicatorToSlot", "local canUpdate = true")
    + section(ra, "\t--inventories hook", "\t--deconstruction hook"))

cs = source("CraftStoreFixedAndImproved/CraftStore.lua")
lua.execute("local CS=CSFixture; local WM=WINDOW_MANAGER; local ITEMMARK={}; local SELF={1,0,1};\n"
    + section(cs, "function CS.SetItemMark", "function CS.SetAllStyles")
    + section(cs, "function CS.UpdateInventory()", "function CS.UpdateGuildStore()")
    + "\nCS.UpdateInventory()")
lua.execute("CheckInstalledRows()")

ck = source("CharacterKnowledge/Tooltip.lua")
lua.execute("local CharacterKnowledge=CKFixture; local AreExternalTooltipsHooked=false;\n"
    + section(ck, "function CharacterKnowledge.HookExternalTooltips", 'LCK.RegisterForCallback("CharacterKnowledgeTooltip"')
    + "\nCharacterKnowledge.HookExternalTooltips()")
# The installed CS bag-tooltip wrapper is isolated from its other unrelated
# crafting/store tooltip hooks; its original body and call order are preserved.
lua.execute("local CS=CSFixture;\n"
    + section(cs, "function CS.TooltipHandler()", "  local tt=ItemTooltip.SetWornItem")
    + "\nend\nCS.TooltipHandler()")
lua.execute("CheckInstalledTooltips()")

bmr = source("BankManagerRevived/BankManagerCustomRules.lua")
start = bmr.index("function C.RegisterCustomItemContextMenuActions()")
# This function is followed by two blank lines and the next top-level declaration.
import re
following = re.search(r"\n(?:local )?function ", bmr[start + 1:])
body = bmr[start:start + 1 + following.start()] if following else bmr[start:]
lua.execute("local C=BMRFixture.CustomRules; local BMR=BMRFixture; local db=BMRFixture.db;\n"
    + "local function CustomRuleDebug() end\n"
    + "local BMR_CUSTOM_RULE_SET_MENU='Set rule'; local BMR_CUSTOM_RULE_REMOVE_MENU='Remove rule';\n"
    + body)
lua.execute("CheckInstalledBMR(); CheckGridUpdateAfterTransfer()")
print("PASS: installed function excerpts exercised with mocked game state; in-game acceptance remains required.")
