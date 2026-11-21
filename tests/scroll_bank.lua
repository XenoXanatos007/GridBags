local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local S = GridBagsSnapshots
worldName = "NA Megaserver"; S:Initialize(G)
G.saved.enabled = true; G.saved.externalFilters = false
G.saved.columns = 8; G.saved.size = 48; G.saved.sort = "name"
PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
G.sceneName = "inventory"; G.selectedCharacter = S.characterId
G.backpack.query = ""; G.backpack.filter = nil; G.backpack.scrollRow = 0
G:Refresh()
check(G.backpack.maxScrollRow == 2 and not G.backpack.scrollbar:IsHidden(), "overflow has visible scrollbar")
G.backpack.cells[1].handlers.OnMouseWheel(nil, -1)
check(G.backpack.scrollRow == 1, "wheel works down over an item")
G.backpack.cells[1].handlers.OnMouseWheel(nil, 1)
check(G.backpack.scrollRow == 0, "wheel works up over an item")
G.backpack.scrollbar:SetValue(2)
check(G.backpack.scrollRow == 2 and G.backpack.rangeLabel.text == "17-65 of 65", "thumb scrolls to final visible rows")
G:Wheel(G.backpack, 0)
check(G.backpack.scrollRow == 2, "zero wheel delta does not scroll")
G.backpack.query = "does not exist"; G:Refresh()
check(G.backpack.scrollRow == 0 and G.backpack.scrollbar:IsHidden(), "empty search resets scroll and hides scrollbar")
G.backpack.query = ""; G:Refresh()
check(ZO_PlayerInventory:IsHidden() and ZO_PlayerBank:IsHidden(), "native panels hidden behind grid")
G.nativeFiltersMode = true; G:Refresh()
check(not ZO_PlayerInventory:IsHidden() and G.root:IsHidden(), "native filters reveals actual standard inventory")
G.nativeFiltersMode = false; G:Refresh()
check(ZO_PlayerInventory:IsHidden() and not G.root:IsHidden(), "return hides native duplicate")
G.saved.enabled = false; G:Refresh()
check(not ZO_PlayerInventory:IsHidden(), "standard view restores native inventory")
G.saved.enabled = true

bankOpen = false
S:CaptureBank()
check(G.saved.bankSnapshots[S.world] == nil, "closed bank never creates a fabricated record")
bankOpen = true
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_OPEN_BANK]()
check(EVENT_MANAGER.updates.GridBagsBankCapture ~= nil, "bank open schedules observation")
EVENT_MANAGER.updates.GridBagsBankCapture()
local record = G.saved.bankSnapshots[S.world]
check(record.used == 2 and #record.items == 2 and record.name == "Account bank", "snapshot includes both personal and subscriber bank")
bankOpen = false
bags[BAG_BANK][0].name = "Unavailable cached bank data"
S:CaptureBank()
check(G.saved.bankSnapshots[S.world] == record, "closed-bank calls preserve last actual observation")
S:Select(G, "@account-bank")
check(G.backpack.cells[1].readOnly and G.backpack.titleLabel.text == "Account bank (snapshot)", "account bank selected away from banker")
G.backpack.query = "subscriber"; G:Refresh()
check(not G.backpack.cells[1]:IsHidden() and G.backpack.cells[2]:IsHidden(), "saved bank searchable by item name")
local before = actions
G.backpack.cells[1].handlers.OnMouseDoubleClick(G.backpack.cells[1], MOUSE_BUTTON_INDEX_LEFT)
check(actions == before, "saved bank actions blocked")
check(G.backpack.cells[1].bagId == nil, "saved bank has no live binding")
bankOpen = true; G.sceneName = "bank"; G:Refresh()
check(G.selectedCharacter == S.characterId and not G.backpack.cells[1].readOnly, "banker replaces snapshot selection with live bags")
check(G.bank.cells[1].handlers.OnDragStart == mockNativeHandlers.OnDragStart, "bank drag handler remains inherited")
check(G.bank.cells[1].handlers.OnMouseDoubleClick == mockNativeHandlers.OnMouseDoubleClick, "bank primary handler remains inherited")
bankOpen = false; G.sceneName = nil; G:Refresh()
check(G.root:IsHidden() and ZO_PlayerInventory:IsHidden() and ZO_PlayerBank:IsHidden(), "leaving scene hides all inventory panels")
print(string.format("PASS: %d scrolling/bank regression checks (Lua 5.1, mocked ESO interfaces).", checks))
