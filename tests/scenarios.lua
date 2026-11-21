G:Initialize()
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
for slot = 0, 64 do
    bags[BAG_BACKPACK][slot] = { name = string.format("Item %02d", slot), id = slot + 1,
        quality = slot % 5, filter = ITEMFILTERTYPE_WEAPONS }
end
bags[BAG_BACKPACK][0].name = "Axe [Iron]"
bags[BAG_BANK][0] = { name = "Bank item", id = 1000, quality = 2, filter = ITEMFILTERTYPE_ARMOR }
bags[BAG_SUBSCRIBER_BANK][0] = { name = "Subscriber item", id = 2000, quality = 3, filter = ITEMFILTERTYPE_CRAFTING }
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_SHOWING)
check(not G.root:IsHidden(), "inventory grid opens")
check(G.bank.control:IsHidden(), "bank hidden away from banker")
check(G.backpack.maxScrollRow == 2, "65 stacks need two extra rows")
G:Wheel(G.backpack, -1)
check(G.backpack.scrollRow == 1, "wheel down advances one row")
G:Wheel(G.backpack, 1)
check(G.backpack.scrollRow == 0, "wheel up returns one row")
G:ScrollRows(G.backpack, 100)
check(G.backpack.scrollRow == 2 and not G.backpack.cells[49]:IsHidden(), "scroll clamps to final rows")
check(G.backpack.cells[50]:IsHidden(), "unused final row cell hidden")
G.backpack.query = "[iron]"; G:Refresh()
check(G.backpack.maxScrollRow == 0 and G.backpack.scrollRow == 0, "search clamps scrolling")
check(G.backpack.cells[1].slotIndex == 0, "literal case-insensitive search")
G.backpack.filter = ITEMFILTERTYPE_ARMOR; G:Refresh()
check(G.backpack.cells[1]:IsHidden(), "category and search combine")
G.backpack.query = ""; G.backpack.filter = nil; G:Refresh()
local cell = G.backpack.cells[1]
cell.handlers.OnMouseDoubleClick(cell, MOUSE_BUTTON_INDEX_LEFT)
check(actions == 1, "current item action delegates")
bags[BAG_BACKPACK][cell.slotIndex].id = 9999
EVENT_MANAGER.events.GridBags[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil, cell.bagId, cell.slotIndex)
check(not cell.mouseEnabled, "changed slot disabled pending rebind")
check(cell.handlers.OnMouseDoubleClick == mockNativeHandlers.OnMouseDoubleClick and cell.handlers.OnDragStart == mockNativeHandlers.OnDragStart, "live action handlers remain inherited")
bankOpen = true
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_HIDING)
SCENE_MANAGER:GetScene("bank").callback(nil, SCENE_SHOWING)
check(not G.bank.control:IsHidden(), "bank has two panels")
check(G.bank.count.text:find("2 / 240", 1, true), "subscriber bag included")
local bankCell = G.bank.cells[1]
check(bankCell.slotType == SLOT_TYPE_BANK_ITEM, "bank slot has native bank type")
bankOpen = false
G:Refresh(); check(G.root:IsHidden(), "bank close hides grid")
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_SHOWING)
gamepad = true; G:Refresh(); check(G.root:IsHidden(), "controller mode hidden")
gamepad = false; G:Refresh()
SLASH_COMMANDS["/gridbags"]("columns 12"); check(#G.backpack.cells == 84, "larger column count creates cells")
SLASH_COMMANDS["/gridbags"]("columns 6"); check(G.backpack.cells[43]:IsHidden(), "shrinking columns hides excess cells")
SLASH_COMMANDS["/gridbags"]("size 100"); check(G.saved.size == 64, "size upper bound")
SLASH_COMMANDS["/gridbags"]("sort quality")
check(G.backpack.cells[1].slotIndex % 5 == 4, "quality descending")
ZO_Menu:SetHidden(false)
local previous = G.backpack.cells[1].itemIdentity
bags[BAG_BACKPACK][G.backpack.cells[1].slotIndex].id = 30000
G:Refresh(); check(G.backpack.cells[1].itemIdentity == previous, "menu defers cell rebinding")
ZO_Menu:SetHidden(true); G:Refresh()
check(G.backpack.cells[1].itemIdentity == "30000", "cell refresh after menu close")
SLASH_COMMANDS["/gridbags"](""); check(G.root:IsHidden(), "toggle restores native view")
SCENE_MANAGER:GetScene("inventory").callback(nil, SCENE_HIDDEN)
check(G.sceneName == nil, "scene exit clears scene")
print(string.format("PASS: %d behavioral checks (Lua 5.1, mocked ESO interfaces).", checks))
