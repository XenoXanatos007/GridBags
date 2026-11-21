-- Strict method inventory: unknown control calls fail rather than silently succeeding.
local methods = {}
for _, name in ipairs({ "SetFont", "SetAnchor", "SetAnchorFill", "SetCenterColor", "SetEdgeColor",
    "SetEdgeTexture", "SetDrawLayer", "SetMouseEnabled", "SetMaxInputChars", "ClearAnchors",
    "SetDrawTier", "SetDrawLevel", "LoseFocus", "SetAlpha", "SetMaxLineCount", "SetWrapMode", "SetOrientation", "SetValueStep", "SetThumbTexture" }) do
    methods[name] = function() end
end
function methods:SetDimensions(w, h) self.width = w; self.height = h end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:SetScale(v) self.scale = v end
function methods:GetScale() return self.scale or 1 end
function methods:SetParent(parent) self.parent = parent end
function methods:GetParent() return self.parent end
function methods:ClearAnchors() self.anchors = {} end
function methods:SetAnchor(...) self.anchors = self.anchors or {}; self.anchors[#self.anchors + 1] = {...} end
function methods:GetNumAnchors() return #(self.anchors or {}) end
function methods:GetAnchor(index)
    local anchor = (self.anchors or {})[index + 1]
    if not anchor then return false end
    return true, unpack(anchor, 1, 6)
end
function methods:SetHidden(v) self.hidden = v end
function methods:IsHidden() return self.hidden or false end
function methods:IsControlHidden()
    if self:IsHidden() then return true end
    return self.parent and self.parent:IsControlHidden() or false
end
function methods:SetText(v) self.text = v end
function methods:GetText() return self.text or "" end
function methods:SetHandler(k, v) self.handlers[k] = v end
function methods:GetHandler(k) return self.handlers[k] end
function methods:SetEnabled(v) self.enabled = v end
function methods:SetMouseEnabled(v) self.mouseEnabled = v end
function methods:SetKeyboardEnabled(v) self.keyboardEnabled = v end
function methods:SetEditEnabled(v) self.editEnabled = v end
function methods:TakeFocus()
    if mockFocusedEdit then mockFocusedEdit.focused = false end
    mockFocusedEdit = self
    self.focused = true
end
function methods:LoseFocus()
    self.focused = false
    if mockFocusedEdit == self then mockFocusedEdit = nil end
end
function methods:SetMinMax(lo, hi) self.minimum = lo; self.maximum = hi end
function methods:SetValue(v)
    self.value = v
    if self.handlers.OnValueChanged then self.handlers.OnValueChanged(self, v) end
end
function methods:GetName() return self.name end
function methods:GetNamedChild(name) return self.children and self.children[name] end
local nativeHandlers = {
    OnMouseDoubleClick = function(c, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then ZO_InventorySlot_DoPrimaryAction(c) end
    end,
    OnClicked = function(c, button) ZO_InventorySlot_OnSlotClicked(c, button) end,
    OnDragStart = function(c) ZO_InventorySlot_OnDragStart(c) end,
    OnReceiveDrag = function(c) ZO_InventorySlot_OnReceiveDrag(c) end,
    OnMouseEnter = function(c) ZO_InventorySlot_OnMouseEnter(c) end,
    OnMouseExit = function(c) ZO_InventorySlot_OnMouseExit(c) end,
}
mockNativeHandlers = nativeHandlers
local function control(name, template)
    local c = setmetatable({ name = name, template = template, handlers = {}, children = {} }, { __index = methods })
    if template == "ZO_DefaultEditForBackdrop" then
        c.handlers.OnMouseDown = function(edit, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then edit:TakeFocus() end
        end
    end
    if template == "ZO_PlayerInventorySlot" then
        c.children.Button = control((name or "") .. "Button")
        for key, handler in pairs(nativeHandlers) do c.children.Button.handlers[key] = handler end
        for _, key in ipairs({ "Name", "SellPrice", "SellPriceText", "Status", "TraitInfo", "SellInformation", "ItemCondition", "Research", "CSMark" }) do
            c.children[key] = control((name or "") .. key)
        end
    end
    return c
end
WINDOW_MANAGER = { CreateControl = function(_, name, parent) local c = control(name); c.parent = parent; return c end,
    CreateControlFromVirtual = function(_, name, parent, template) local c = control(name, template); c.parent = parent; return c end,
    CreateTopLevelWindow = function(_, name) return control(name) end,
    GetMouseOverControl = function() return nil end }
GuiRoot = control("GuiRoot")
ZO_PlayerInventory = control("NativeInventory")
ZO_PlayerBank = control("NativeBank"); ZO_PlayerBank:SetHidden(true)
ZO_PlayerBankMenu = control("NativeBankMenu"); ZO_PlayerBankMenu:SetHidden(true)
ItemTooltip = { GetOwner = function() return nil end, SetLink = function(self, link) self.lastLink = link end,
    AddLine = function(self, text) self.lastLine = text end }
function InitializeTooltip(tip) tip.hidden = false end
function ClearTooltip(tip) tip.hidden = true; tip.lastLink = nil; tip.lines = {} end
function ClearMenu() if ZO_Menu then ZO_Menu:SetHidden(true) end end
menuEntries = {}
function AddMenuItem(name, callback) menuEntries[#menuEntries + 1] = {name = name, callback = callback} end
function ShowMenu() end
ZO_Menu = control("Menu"); ZO_Menu:SetHidden(true)
EVENT_MANAGER = { updates = {}, events = {} }
function EVENT_MANAGER:RegisterForEvent(namespace, event, fn)
    self.events[namespace] = self.events[namespace] or {}; self.events[namespace][event] = fn
end
function EVENT_MANAGER:UnregisterForEvent(namespace, event)
    if self.events[namespace] then self.events[namespace][event] = nil end
end
function EVENT_MANAGER:RegisterForUpdate(name, _, fn) self.updates[name] = fn end
function EVENT_MANAGER:UnregisterForUpdate(name) self.updates[name] = nil end
SCENE_MANAGER = { scenes = {} }
function SCENE_MANAGER:GetScene(name)
    if not self.scenes[name] then
        self.scenes[name] = { RegisterCallback = function(scene, _, fn) scene.callback = fn end }
    end
    return self.scenes[name]
end
ZO_SavedVars = { NewAccountWide = function(_, _, _, _, defaults)
    local copy = {}; for k, v in pairs(defaults) do copy[k] = v end; return copy
end }
SLASH_COMMANDS = {}
local constants = { "CT_LABEL", "CT_BACKDROP", "CT_CONTROL", "CT_EDITBOX", "TOPLEFT", "BOTTOMRIGHT",
    "TOPRIGHT", "RIGHT", "CENTER", "BOTTOMLEFT", "DL_BACKGROUND", "DL_OVERLAY", "DT_MEDIUM",
    "ITEMFILTERTYPE_WEAPONS", "ITEMFILTERTYPE_ARMOR", "ITEMFILTERTYPE_CONSUMABLE", "ITEMFILTERTYPE_CRAFTING",
    "SI_TOOLTIP_ITEM_NAME", "INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS", "EVENT_ADD_ON_LOADED",
    "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", "EVENT_INVENTORY_FULL_UPDATE", "EVENT_CLOSE_BANK",
    "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED", "SCENE_SHOWING", "SCENE_SHOWN", "SCENE_HIDING", "SCENE_HIDDEN",
    "EVENT_PLAYER_ACTIVATED", "EVENT_PLAYER_DEACTIVATED", "SI_UNIT_NAME", "LF_INVENTORY", "LF_BANK_DEPOSIT", "LF_BANK_WITHDRAW", "LF_FILTER_ALL", "TEXT_WRAP_MODE_ELLIPSIS", "CT_SLIDER", "ORIENTATION_VERTICAL", "EVENT_OPEN_BANK" }
for i, name in ipairs(constants) do _G[name] = i end
BAG_WORN = 4; BAG_BACKPACK = 1; BAG_BANK = 2; BAG_SUBSCRIBER_BANK = 3
SLOT_TYPE_ITEM = 1; SLOT_TYPE_BANK_ITEM = 2; MOUSE_BUTTON_INDEX_LEFT = 1
bankOpen = false; gamepad = false; bankingBag = BAG_BANK
function IsBankOpen() return bankOpen end
function IsInGamepadPreferredMode() return gamepad end
function GetBankingBag() return bankingBag end
characterId = "character-one"; worldName = "NA Megaserver"; timestamp = 100000
function GetCurrentCharacterId() return characterId end
function GetWorldName() return worldName end
function GetTimeStamp() return timestamp end
function GetDateStringFromTimestamp(t) return tostring(t) end
function GetUnitName() return "Current Character" end
function zo_clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
zo_strlower = string.lower
function zo_strformat(_, s) return s end
function Id64ToString(id) return tostring(id) end
function d() end
bags = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
function GetBagSize() return 120 end
GetBagUseableSize = GetBagSize
function GetNumBagUsedSlots(bag) local n = 0; for _ in pairs(bags[bag]) do n = n + 1 end; return n end
function GetItemId(bag, slot) return bags[bag][slot] and 100 or 0 end
function GetItemName(bag, slot) return bags[bag][slot].name end
function GetItemLink(bag, slot) return "item-link-" .. tostring(bags[bag][slot].id) end
function GetItemUniqueId(bag, slot) return bags[bag][slot] and bags[bag][slot].id or 0 end
function GetSlotStackSize(bag, slot) return bags[bag][slot] and (bags[bag][slot].qty or 1) or 0, 200 end
function IsItemBound() return false end
function GetFrameTimeSeconds() return timestamp end
CURT_MONEY=1001; CURRENCY_LOCATION_CHARACTER=1002; CURRENCY_LOCATION_BANK=1003
EVENT_MONEY_UPDATE=1004; EVENT_BANKED_MONEY_UPDATE=1005
EVENT_LUA_ERROR=1006
mockCharacterGold=5000; mockBankGold=25000
function GetCurrencyAmount(_, location) return location==CURRENCY_LOCATION_BANK and mockBankGold or mockCharacterGold end
function GetItemInfo(bag, slot)
    local i = bags[bag][slot]; return "icon.dds", i.qty or 1, 0, true, false, 0, 0, i.quality, i.quality
end
function GetItemFilterTypeInfo(bag, slot) return bags[bag][slot].filter end
function IsItemJunk(bag, slot) return bags[bag][slot].junk or false end
function IsItemStolen() return false end
function IsItemPlayerLocked() return false end
function GetInterfaceColor() return 1, 1, 1 end
function ZO_Inventory_BindSlot(c, kind, slot, bag) c.slotType = kind; c.slotIndex = slot; c.bagId = bag end
function ZO_Inventory_SetupSlot(c, stack) c.stackCount = stack; c:SetHidden(false) end
ZO_ItemSlot_SetupSlot = ZO_Inventory_SetupSlot
actions = 0
function ZO_InventorySlot_DoPrimaryAction() actions = actions + 1 end
function ZO_InventorySlot_OnSlotClicked() actions = actions + 1 end
function ZO_InventorySlot_OnDragStart() actions = actions + 1 end
function ZO_InventorySlot_OnReceiveDrag() actions = actions + 1 end
function ZO_InventorySlot_OnMouseEnter() end
function ZO_InventorySlot_OnMouseExit() end

-- Equipment presentation services; native action handlers remain untouched.
SI_EQUIPSLOT = 900; EQUIP_SLOT_NONE = -1
EQUIP_SLOT_HEAD = 0; EQUIP_SLOT_MAIN_HAND = 4; EQUIP_SLOT_OFF_HAND = 5
EQUIP_SLOT_BACKUP_MAIN = 20; EQUIP_SLOT_BACKUP_OFF = 21
EQUIP_SLOT_POISON = 14; EQUIP_SLOT_BACKUP_POISON = 15
EQUIP_SLOT_RING1 = 10; EQUIP_SLOT_RING2 = 11
DT_HIGH = 4
function GetString(_, slot) return "Slot " .. slot end
function GetItemLinkComparisonEquipSlots() return EQUIP_SLOT_HEAD, EQUIP_SLOT_NONE end
function ZO_PostHook(target, name, callback)
    local original = target[name]
    target[name] = function(...) original(...); callback(...) end
end
function ItemTooltip:HideComparativeTooltips() self.comparisonsHidden = true end
function methods:SetLink(link) self.lastLink = link end
function methods:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = text end

function methods:SetClampedToScreen(v) self.clamped = v end
function methods:SetMovable(v) self.movable = v end
function methods:SetMultiLine(v) self.multiLine = v end
function methods:SelectAll() self.allSelected = true end
function methods:GetLeft() return self.mockLeft or 0 end
function methods:GetTop() return self.mockTop or 0 end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrResizing()
    self.moving = false
    if self.handlers.OnMoveStop then self.handlers.OnMoveStop(self) end
end
