local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local F, S, A = GridBagsSnapshotFilters, GridBagsSnapshots, GridBagsAdvancedFilters
local ALL, WEAPONS, ARMOR = 300, 301, 302
local function NativeData(_, bag, slot)
    local item = bags[bag][slot]
    return {bagId = bag, slotIndex = slot, itemType = item.kind, weaponType = item.weapon,
        armorType = item.weight, isJunk = item.junk, filterData = {item.filter}, stackCount = 1}
end
SHARED_INVENTORY.GenerateSingleSlotData = NativeData
local calls, pluginCalls = 0, 0
local all = function() calls = calls + 1; return true end
local oneHand = function(data) calls = calls + 1; return bags[data.bagId][data.slotIndex].weapon == "one-hand" end
local axe = function(data) calls = calls + 1; return bags[data.bagId][data.slotIndex].subtype == "axe" end
local heavy = function(data) calls = calls + 1; return data.armorType == "heavy" end
local broken = function() calls = calls + 1; error("classification unavailable") end
local start = function() error("start callbacks must not execute") end
CRAFTING_TYPE_INVALID = 0
AdvancedFilters = {
    strings = {Weapons = "Weapons", Armor = "Armor", OneHand = "One-handed", Axe = "Axe", Heavy = "Heavy"},
    filterTypeNames = {[ALL] = "All", [WEAPONS] = "Weapons", [ARMOR] = "Armor"},
    subfilterCallbacks = {
        Weapons = {All = {filterCallback = all}, OneHand = {filterCallback = oneHand,
            filterStartCallback = start, dropdownCallbacks = {{name = "Axe", filterCallback = axe, filterStartCallback = start}}},
            addonDropdownCallbacks = {{name = "Plugin", filterCallback = function() pluginCalls = pluginCalls + 1 end}}},
        Armor = {All = {filterCallback = all}, Heavy = {filterCallback = heavy}, Broken = {filterCallback = broken}},
        All = {All = {filterCallback = all}},
    }, subfilterGroups = {[INVENTORY_BACKPACK] = {[0] = {}}},
}
for _, descriptor in ipairs({{ALL,"All",{"All"}}, {WEAPONS,"Weapons",{"All","OneHand"}}, {ARMOR,"Armor",{"All","Heavy","Broken"}}}) do
    local buttons = {}
    for _, name in ipairs(descriptor[3]) do
        buttons[#buttons + 1] = {name = name, groupName = descriptor[2], filterCallback = AdvancedFilters.subfilterCallbacks[descriptor[2]][name].filterCallback}
    end
    AdvancedFilters.subfilterGroups[INVENTORY_BACKPACK][0][descriptor[1]] = {subfilterButtons = buttons}
end
ZO_ItemFilterUtils = {IsSlotFilterDataInItemTypeDisplayCategory = function(data, category)
    return category == ALL or (category == WEAPONS and data.itemType == "weapon") or (category == ARMOR and data.itemType == "armor")
end}
bags[BAG_BACKPACK] = {
    [0] = {name = "Axe", id = 500, quality = 3, kind = "weapon", weapon = "one-hand", subtype = "axe", filter = ITEMFILTERTYPE_WEAPONS},
    [1] = {name = "Sword", id = 501, quality = 2, kind = "weapon", weapon = "one-hand", subtype = "sword", filter = ITEMFILTERTYPE_WEAPONS},
    [2] = {name = "Heavy helmet", id = 502, quality = 1, kind = "armor", weight = "heavy", filter = ITEMFILTERTYPE_ARMOR},
}
worldName = "NA Megaserver"; S:Initialize(G); S.ready = true; S:Capture()
local record = S.records[S.characterId]
check(record.afFilters and #record.afFilters.categories == 3, "live capture persists AF category catalog")
check(record.items[1].afMatches["c:301:s:OneHand:d:1:Axe"], "saved detail predicate matches axe")
check(not record.items[2].afMatches["c:301:s:OneHand:d:1:Axe"], "saved detail excludes sword")
check(record.items[3].afMatches["c:302:s:Heavy"], "saved armor weight classification")
check(pluginCalls == 0, "plugin registry callbacks never run during capture")
check(record.items[3].afUnknown["c:302:s:Broken"] and record.afFilterErrors == 1, "failed classifications recorded as unavailable")
local before = calls; S:Capture()
check(calls == before, "unchanged items reuse bounded classification cache")
timestamp = timestamp + 5; S:Capture()
check(calls > before, "classification cache expires")
record = S.records[S.characterId]
local function DataOnly(value, seen)
    if type(value) == "function" or type(value) == "userdata" then return false end
    if type(value) ~= "table" then return true end
    seen = seen or {}; if seen[value] then return true end; seen[value] = true
    for key, child in pairs(value) do if not DataOnly(key, seen) or not DataOnly(child, seen) then return false end end
    return true
end
check(DataOnly(record), "snapshot persists data only, no executable callbacks or controls")
check(record.items[1].bagId == nil and record.items[1].slotIndex == nil, "classifications add no live bag bindings")
S.records["classified-character"] = record
G.saved.enabled = true; G.saved.externalFilters = true; G.saved.embeddedFilters = true
G.sceneName = "inventory"; bankOpen = false; PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
S:Select(G, "classified-character")
check(A.host:IsHidden() and not G.backpack.savedFilterUI.control:IsControlHidden(), "classified snapshot has its own visible filter UI")
check(A.currentBar == nil and next(A.mounted) == nil, "snapshot does not borrow live filter widgets")
check(G.filtersButton.enabled, "snapshot filter toggle is available")
check(not G.backpack.savedFilterUI.category:IsControlHidden() and G.backpack.savedFilterUI.category.enabled,
    "category button visible through its full parent chain")
check(G.backpack.filters[1]:IsHidden(), "classified snapshots replace the old basic filter row")
G.saved.embeddedFilters = false; G.saved.externalFilters = false; G:Refresh()
check(not G.backpack.savedFilterUI.control:IsControlHidden(), "snapshot controls independent of live filter visibility preferences")
A:Restore()
check(not G.backpack.savedFilterUI.control:IsControlHidden(), "restoring live toolbar cannot hide snapshot controls")
G.saved.embeddedFilters = true; G.saved.externalFilters = true; G:Refresh()
menuEntries = {}
G.backpack.savedFilterUI.category:GetHandler("OnClicked")(G.backpack.savedFilterUI.category)
check(#menuEntries == 4, "category button opens saved category choices")
menuEntries[3].callback()
check(G.backpack.snapshotSelection.category == "c:301", "category menu selects saved Weapons ID")
menuEntries = {}
G.backpack.savedFilterUI.subfilter:GetHandler("OnClicked")(G.backpack.savedFilterUI.subfilter)
menuEntries[3].callback()
check(G.backpack.snapshotSelection.subfilter == "c:301:s:OneHand", "type menu selects saved One-handed ID")
menuEntries = {}
G.backpack.savedFilterUI.detail:GetHandler("OnClicked")(G.backpack.savedFilterUI.detail)
menuEntries[2].callback()
check(G.backpack.snapshotSelection.detail == "c:301:s:OneHand:d:1:Axe", "detail menu selects saved Axe ID")
G.backpack.snapshotSelection = {category = "c:301", subfilter = "c:301:s:OneHand", detail = "c:301:s:OneHand:d:1:Axe"}
local oldGetItemId, oldGetItemLink, oldData = GetItemId, GetItemLink, SHARED_INVENTORY.GenerateSingleSlotData
GetItemId = function() error("offline filter read current bag") end
GetItemLink = function() error("offline filter read current bag link") end
SHARED_INVENTORY.GenerateSingleSlotData = function() error("offline filter generated current slot data") end
before = calls
G:Refresh()
local items = G:ReadItems(G.backpack, {BAG_BACKPACK})
check(#items == 1 and items[1].name == "axe", "offline filters evaluate saved category/type/detail intersection")
check(calls == before and pluginCalls == 0, "offline filtering executes no AF or plugin callback")
G.backpack.query = "sword"; G:Refresh()
check(G.backpack.cells[1]:IsHidden(), "snapshot name search intersects AF classifications")
G.backpack.query = ""; G.backpack.snapshotSelection = {category = "c:302", subfilter = "c:302:s:Broken"}; G:Refresh()
check(G.backpack.cells[1]:IsHidden(), "unavailable classification never silently admits items")
G.backpack.snapshotSelection = {category = "removed-definition"}; G:Refresh()
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 3, "stale filter selection resets against saved schema")
GetItemId, GetItemLink, SHARED_INVENTORY.GenerateSingleSlotData = oldGetItemId, oldGetItemLink, oldData
G.backpack.snapshotSelection = nil
F:Menu(G, G.backpack.savedFilterUI.category, "category")
check(#menuEntries > 0, "snapshot category menu populated without live slot callbacks")
S:Select(G, S.characterId)
check(G.backpack.snapshotSelection == nil, "returning to current character clears snapshot-only filtering")
bags[BAG_BANK][0].kind = "weapon"; bags[BAG_BANK][0].weapon = "one-hand"; bags[BAG_BANK][0].subtype = "axe"
bankOpen = true; S:CaptureBank(); bankOpen = false
check(G.saved.bankSnapshots[S.world].afFilters ~= nil, "account bank captures the same AF catalog")
S:Select(G, "@account-bank")
check(not G.backpack.savedFilterUI.control:IsControlHidden() and G.backpack.cells[1].readOnly, "account-bank snapshot has read-only captured filtering")
G.backpack.snapshotSelection = {category = "c:301", subfilter = "c:301:s:OneHand"}
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 1, "saved bank filters use its own captured classifications")
S.records["legacy-character"] = {name = "Legacy", used = 0, capacity = 80, updatedAt = timestamp, items = {}}
S:Select(G, "legacy-character")
check(A.host:IsHidden() and not G.backpack.savedFilterUI.control:IsControlHidden()
    and not G.backpack.savedFilterUI.category.enabled, "legacy snapshot shows explicit refresh-required filter area")
check(G.hintLabel.text:find("fresh capture", 1, true), "legacy snapshot explains required refresh")
check(not G.backpack.filters[1]:IsHidden() and G.backpack.savedFilterUI.title.text:find("Refresh required", 1, true),
    "older snapshots keep basic filters alongside explicit disabled new controls")
print(string.format("PASS: %d saved Advanced Filters checks (Lua 5.1, mocked live-capture contracts).", checks))
