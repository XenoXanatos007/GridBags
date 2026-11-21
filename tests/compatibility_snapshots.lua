local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local S, C = GridBagsSnapshots, GridBagsCompatibility
G.saved.enabled = true
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_SHOWING)
check(next(S.records) == nil, "no premature capture before player activation")
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_PLAYER_ACTIVATED]()
check(S.records[characterId].used == 65 and #S.records[characterId].items == 65, "login captures all occupied slots")
check(S.records[characterId].capacity == 120, "snapshot records capacity")
local record = S.records[characterId]
check(record.items[1].link ~= nil and record.items[1].filters[1] == ITEMFILTERTYPE_WEAPONS, "snapshot persists link and filter types")
local other = { name = "Other Character", used = 1, capacity = 80, updatedAt = timestamp - 3600,
    items = { { name = "saved axe", displayName = "Saved Axe", link = "remote-link", icon = "axe.dds", stack = 12,
        quality = 3, junk = true, filters = { ITEMFILTERTYPE_WEAPONS }, order = 2 } } }
S.records["other-character"] = other
S:Select(G, "other-character")
local cell = G.backpack.cells[1]
check(cell.readOnly and cell.bagId == nil and cell.slotIndex == nil and cell.slotType == nil, "snapshot cell has no live bag binding")
check(cell.stackCount == 12 and G.backpack.count.text:find("1 / 80", 1, true), "snapshot capacity and stacks render from saved data")
check(G.backpack.sourceLabel.text:find("READ ONLY", 1, true) and G.backpack.sourceLabel.text:find("60 min", 1, true), "snapshot age and read-only label")
local actionsBefore = actions
cell.handlers.OnClicked(cell, 2)
cell.handlers.OnMouseDoubleClick(cell, MOUSE_BUTTON_INDEX_LEFT)
cell.handlers.OnDragStart(cell, MOUSE_BUTTON_INDEX_LEFT)
cell.handlers.OnReceiveDrag(cell, MOUSE_BUTTON_INDEX_LEFT)
check(actions == actionsBefore, "all snapshot item action paths blocked")
cell.handlers.OnMouseEnter(cell)
check(ItemTooltip.lastLink == "remote-link", "snapshot tooltip uses saved link")
check(cell.row:GetNamedChild("Research"):IsHidden() and cell.row:GetNamedChild("CSMark"):IsHidden(), "live research and craft marks excluded from snapshots")
G.backpack.filter = "junk"; G:Refresh()
check(not G.backpack.cells[1]:IsHidden(), "snapshot junk filter uses saved metadata")
G.backpack.query = "SAVED"; G.backpack.query = zo_strlower(G.backpack.query); G:Refresh()
check(not G.backpack.cells[1]:IsHidden(), "snapshot search uses saved names")
check(other.items[1].bag == nil and other.items[1].snapshot == nil, "render never annotates saved record")
G.backpack.query = "does-not-exist"; G:Refresh(); S:Capture()
check(#S.records[characterId].items == 65, "snapshot capture unaffected by current search/filter")
S:Select(G, characterId)
bags[BAG_BACKPACK][0].name = "Fresh live axe"
G.saved.sort = "name"; G:Refresh()
local foundLive = false
for _, item in ipairs(G:ReadItems(G.backpack, {BAG_BACKPACK})) do
    if item.slot == 0 and item.name == "fresh live axe" and not item.snapshot then foundLive = true end
end
check(foundLive, "current character always uses live APIs despite cached record")
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil, BAG_BANK)
check(not S.pending, "bank changes do not queue backpack snapshot")
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil, BAG_BACKPACK)
check(S.pending and EVENT_MANAGER.updates.GridBagsSnapshotUpdate ~= nil, "bag change queues snapshot")
local firstUpdate = EVENT_MANAGER.updates.GridBagsSnapshotUpdate
S:QueueCapture()
check(EVENT_MANAGER.updates.GridBagsSnapshotUpdate == firstUpdate, "continuous changes do not starve snapshot timer")
timestamp = timestamp + 2; firstUpdate()
check(not S.pending and S.records[characterId].updatedAt == timestamp, "delayed capture updates saved record")
bags[BAG_BACKPACK][0].name = "Logout axe"
S:QueueCapture()
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_PLAYER_DEACTIVATED]()
check(S.records[characterId].items[1].name == "logout axe", "logout captures latest inventory")
check(not S.ready and not S.pending and not EVENT_MANAGER.updates.GridBagsSnapshotUpdate, "logout clears timer and readiness")
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_PLAYER_ACTIVATED]()
S:Select(G, "other-character")
bankOpen = true; SCENE_MANAGER:GetScene("bank").callback(nil, SCENE_SHOWING)
check(G.selectedCharacter == characterId and not G.backpack.cells[1].readOnly, "bank returns backpack to live current character")
check(not G.backpack.characterButton.enabled, "bank disables remote selection")
S:Select(G, "other-character")
check(G.selectedCharacter == characterId, "programmatic bank selection also stays live")
bankOpen = false; SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_SHOWING)

-- Match installed LibFilters API: callbacks take native slot data; bank contexts differ.
local filters = {}
LibFilters3 = { GetFilterTypeCallbacks = function(_, context) return filters[context] end }
SHARED_INVENTORY = { GenerateSingleSlotData = function(_, bag, slot)
    return { bagId = bag, slotIndex = slot, stackCount = 1, name = GetItemName(bag, slot) }
end }
local seenContext
filters[LF_INVENTORY] = { AdvancedFilters = function(data)
    seenContext = "inventory"; return data.bagId == BAG_BACKPACK and data.slotIndex == 0
end }
G:Refresh()
local items = G:ReadItems(G.backpack, { BAG_BACKPACK })
check(#items == 1 and items[1].slot == 0 and seenContext == "inventory", "Advanced Filters-shaped slot callbacks restrict grid")
filters[LF_BANK_DEPOSIT] = { Deposit = function(data) return data.slotIndex == 2 end }
filters[LF_BANK_WITHDRAW] = { Withdraw = function(data) return data.bagId == BAG_SUBSCRIBER_BANK end }
bankOpen = true; G.sceneName = "bank"
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 1 and G:ReadItems(G.backpack, {BAG_BACKPACK})[1].slot == 2, "deposit context distinct from inventory")
local bankItems = G:ReadItems(G.bank, { BAG_BANK, BAG_SUBSCRIBER_BANK })
check(#bankItems == 1 and bankItems[1].bag == BAG_SUBSCRIBER_BANK, "withdraw context covers subscriber bag")
filters[LF_BANK_DEPOSIT] = nil; filters[LF_FILTER_ALL] = { All = function() return false end }
LibFilters3.useFilterAllFallback = true
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 0, "LibFilters fallback honored")
LibFilters3.useFilterAllFallback = false
filters[LF_BANK_DEPOSIT] = { Broken = function() error("broken addon filter") end }
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 0 and G.backpack.filterError, "external filter errors withhold results")
G.saved.externalFilters = false
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 65, "external filter bridge can be disabled")
G.saved.externalFilters = true
bankOpen = false; G.sceneName = "inventory"
filters[LF_INVENTORY] = nil

-- Exercise decorators through the native setup callback, as RA and CraftStore install them.
local decorated = 0
local nativeSource = {bagId = BAG_BACKPACK, slotIndex = 0, stackCount = 1}
SHARED_INVENTORY.GenerateSingleSlotData = function(_, bag, slot)
    nativeSource.bagId = bag; nativeSource.slotIndex = slot; return nativeSource
end
INVENTORY_BACKPACK = 1; INVENTORY_BANK = 3
PLAYER_INVENTORY = { inventories = { [1] = { listView = { dataTypes = { [1] = {
    setupCallback = function(row, data)
        assert(row.dataEntry.data == data and row.isGrid, "decorator receives native row shape")
        row:GetNamedChild("Research"):SetHidden(false)
        row:GetNamedChild("CSMark"):SetHidden(false)
        data.slotControl = row
        decorated = decorated + 1
    end } } } }, [3] = {} } }
G:Refresh()
check(decorated > 0, "native row decorators invoked")
check(nativeSource.slotControl == nil, "decorating grid leaves native shared slot data intact")
check(not G.backpack.cells[1].row:GetNamedChild("Research"):IsHidden(), "Research Assistant-shaped mark preserved")
check(not G.backpack.cells[1].row:GetNamedChild("CSMark"):IsHidden(), "CraftStore-shaped mark preserved")
PLAYER_INVENTORY.selectedTabType = 6; G:QueueRefresh()
check(G.root:IsHidden(), "craft bag tab hides backpack grid")
PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK; G:QueueRefresh(); G:Refresh()
check(not G.root:IsHidden(), "backpack tab restores grid")
S:Select(G, "other-character")
check(G.backpack.cells[1].row:GetNamedChild("Research"):IsHidden(), "live decorator cleaned when reused for snapshot")
check(G.filtersButton.enabled and not G.backpack.savedFilterUI.control:IsHidden(), "snapshot filter area remains available without live callbacks")
S:Select(G, characterId)

-- UI escape path for the native Advanced Filters controls, without moving its widgets.
G.nativeFiltersMode = true; G:Refresh()
check(G.root:IsHidden() and not G.returnToGrid:IsHidden(), "native filters remain accessible")
G.nativeFiltersMode = false; G:Refresh()
check(not G.root:IsHidden() and G.returnToGrid:IsHidden(), "return to grid")
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_HIDDEN)
check(G.root:IsHidden() and G.returnToGrid:IsHidden(), "both windows close with scene")

local hooks = {}
function SecurePostHook(target, method, callback)
    hooks[method] = callback
end
PLAYER_INVENTORY.UpdateList = function() end
LibFilters3.RegisterFilter = function() end
LibFilters3.UnregisterFilter = function() end
LibFilters3.RequestUpdate = function() end
LibFilters3.SetFilterAllState = function() end
LibAddonMenu2 = {
    RegisterAddonPanel = function(self, id, data) self.panel = data end,
    RegisterOptionControls = function(self, id, data) self.options = data end,
}
C:Initialize(G)
check(hooks.UpdateList and hooks.RegisterFilter and hooks.UnregisterFilter and hooks.RequestUpdate and hooks.SetFilterAllState, "filter/list updates register refresh hooks")
check(LibAddonMenu2.panel.name == "GridBags" and #LibAddonMenu2.options >= 4, "optional addon settings registered")
LibAddonMenu2.options[2].setFunc(false)
check(not G.saved.externalFilters, "settings toggle updates compatibility bridge")
G.saved.externalFilters = true

-- Native category and subcategory selection also applies to the grid.
PLAYER_INVENTORY.inventories[1].currentFilter = 77
PLAYER_INVENTORY.inventories[1].subFilter = 88
ZO_ItemFilterUtils = {
    IsSlotFilterDataInItemTypeDisplayCategory = function(data, category)
        return category == 77 and data.slotIndex < 3
    end,
    IsSlotInItemTypeDisplayCategoryAndSubcategory = function(data, category, subcategory)
        return subcategory == 88 and data.slotIndex == 2
    end,
}
G.sceneName = "inventory"
local nativeItems = G:ReadItems(G.backpack, {BAG_BACKPACK})
check(#nativeItems == 1 and nativeItems[1].slot == 2, "native category and subcategory intersect")
S:Capture()
check(#S.records[characterId].items == 65, "native filter does not trim saved inventory")

worldName = "EU Megaserver"; S:Initialize(G)
check(next(S.records) == nil, "snapshot records isolated by megaserver")
check(G.saved.snapshots["NA Megaserver"]["other-character"] == other, "other world records preserved")
print(string.format("PASS: %d compatibility/snapshot checks (Lua 5.1, mocked ESO interfaces).", checks))
