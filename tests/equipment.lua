local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local S, E = GridBagsSnapshots, GridBagsEquipment
bankOpen = false; G.sceneName = "inventory"; G.saved.enabled = true
G.saved.externalFilters = false
PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
bags[BAG_WORN] = {
    [EQUIP_SLOT_HEAD] = { name = "Worn Helmet", id = 9001, quality = 3, filter = ITEMFILTERTYPE_ARMOR },
    [EQUIP_SLOT_RING1] = { name = "Worn Ring One", id = 9002, quality = 4, filter = ITEMFILTERTYPE_ARMOR },
    [EQUIP_SLOT_RING2] = { name = "Worn Ring Two", id = 9003, quality = 4, filter = ITEMFILTERTYPE_ARMOR },
    [EQUIP_SLOT_MAIN_HAND] = { name = "Worn Sword", id = 9004, quality = 3, filter = ITEMFILTERTYPE_WEAPONS },
    [EQUIP_SLOT_BACKUP_MAIN] = { name = "Backup Sword", id = 9005, quality = 3, filter = ITEMFILTERTYPE_WEAPONS },
}
S.ready = true; S:Capture()
local record = S.records[S.characterId]
check(record.used == GetNumBagUsedSlots(BAG_BACKPACK), "worn equipment does not count against backpack used slots")
check(#record.items == GetNumBagUsedSlots(BAG_BACKPACK), "transferable backpack array excludes worn gear")
check(#record.equipment.items == 5, "capture includes rings and backup weapons")
check(record.equipment.updatedAt == record.updatedAt, "equipment has capture timestamp")
check(record.equipment.items[1].equipSlot == 0 and record.equipment.items[1].link == "item-link-9001", "slot zero and full links persist")
for _, item in ipairs(record.equipment.items) do
    check(item.bag == nil and item.slotIndex == nil, "saved equipment has no live action binding")
end
S.pending = false
EVENT_MANAGER.events.GridBagsSnapshots[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil, BAG_WORN)
check(S.pending, "equipping or unequipping queues a new character snapshot")
S.records["gear-alt"] = record
S:Select(G, "gear-alt", true)
check(S:GetSelected(G) == record.equipment, "equipment selection reads separate saved equipment record")
check(G.backpack.titleLabel.text:find("equipped", 1, true), "equipment view clearly labelled")
local candidate = G.backpack.cells[1]
check(candidate.readOnly and candidate.bagId == nil, "equipment view uses inert snapshot cells")
local before = actions
candidate.handlers.OnClicked(candidate, 1); candidate.handlers.OnDragStart(candidate, 1)
candidate.handlers.OnMouseDoubleClick(candidate, 1); candidate.handlers.OnReceiveDrag(candidate, 1)
check(actions == before, "worn records cannot equip, unequip, move or receive drag")
G.backpack.query = "helmet"; G:Refresh()
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 1, "equipment snapshot is searchable")
S:Select(G, "gear-alt")
check(not G.equipmentView and S:GetSelected(G) == record, "normal character selection returns to saved bag")
S:Select(G, S.characterId, true)
check(S:GetSelected(G) == nil and not G.equipmentView, "current character inventory always stays live")
S.records["old-gear"] = { name = "Old", items = {}, capacity = 10, used = 0, updatedAt = timestamp }
S:Select(G, "old-gear", true)
check(S:GetSelected(G) == S.records["old-gear"], "older records remain usable without equipment data")

local originalSlots = GetItemLinkComparisonEquipSlots
GetItemLinkComparisonEquipSlots = function(link)
    if link == "ring" then return EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 end
    if link == "weapon" then return EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND end
    if link == "none" then return EQUIP_SLOT_NONE, EQUIP_SLOT_NONE end
    return EQUIP_SLOT_HEAD, EQUIP_SLOT_NONE
end
local matches = E:GetMatches("ring", record.equipment)
check(#matches == 2 and matches[1].item.link ~= matches[2].item.link, "both saved rings compare independently")
matches = E:GetMatches("weapon", record.equipment, true)
check(matches[1].slot == EQUIP_SLOT_BACKUP_MAIN and matches[1].item.link == "item-link-9005", "backup comparison uses saved backup bar")
check(matches[2].slot == EQUIP_SLOT_BACKUP_OFF and not matches[2].item, "empty backup slot is explicit, not silently filled from another bar")
check(E:GetMatches("weapon", record.equipment, false)[1].item.link == "item-link-9004", "main bar remains distinct")
check(#E:GetMatches("none", record.equipment) == 0, "non-equipment candidates get no false comparison")

S:Select(G, S.characterId)
G.compareCharacter = "gear-alt"
local cell = G.backpack.cells[1]
check(cell.handlers.OnClicked == mockNativeHandlers.OnClicked and cell.handlers.OnDragStart == mockNativeHandlers.OnDragStart,
    "comparison leaves live protected action handlers inherited")
ZO_InventorySlot_OnMouseEnter(cell)
check(E.tooltips[1].lastLink == "item-link-9001", "live hover compares saved target gear")
check(ItemTooltip.comparisonsHidden, "saved target replaces misleading current-character comparison")
check(table.concat(E.tooltips[1].lines, " "):find(record.name, 1, true), "saved comparison names target character")
check(table.concat(E.tooltips[1].lines, " "):find("current character", 1, true), "tooltip states item-stat context limitation")
ZO_InventorySlot_OnMouseExit(cell)
check(E.tooltips[1].hidden, "comparison clears on live exit")
S:Select(G, "gear-alt")
G.backpack.cells[1].handlers.OnMouseEnter(G.backpack.cells[1])
check(E.tooltips[1].lastLink == "item-link-9001", "saved bag candidate compares without live bag lookup")
G.backpack.cells[1].handlers.OnMouseExit(G.backpack.cells[1])
check(E.tooltips[1].hidden, "comparison clears on saved exit")
G.compareCharacter = nil
E:Show(G, cell)
check(E.tooltips[1].hidden, "comparison off clears saved tooltips")
bankOpen = true; G.sceneName = "bank"; G:Refresh()
check(S:GetSelected(G) == nil, "banking cannot expose equipped records as a live source")
bankOpen = false; G.sceneName = "inventory"
GetItemLinkComparisonEquipSlots = originalSlots
print("PASS: " .. checks .. " equipped snapshot/comparison checks (Lua 5.1, mocked ESO interfaces).")
