local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local A, S, WM = GridBagsAdvancedFilters, GridBagsSnapshots, WINDOW_MANAGER
CRAFTING_TYPE_INVALID = 0
local ALL, WEAPONS = 100, 101
SI_BANK_DEPOSIT = 200; SI_BANK_WITHDRAW = 201
ZO_PlayerBankMenuBar = WM:CreateControl("NativeBankMode", ZO_PlayerBank, CT_CONTROL)
local function widget(name, parent, x)
    local c = WM:CreateControl(name, parent, CT_CONTROL)
    c:SetDimensions(565, 40)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 4, 999)
    return c
end
local inventoryTabs = widget("InventoryCategories", ZO_PlayerInventory, 7)
local bankTabs = widget("BankCategories", ZO_PlayerBank, 8)
local bars = {}
for _, kind in ipairs({INVENTORY_BACKPACK, INVENTORY_BANK}) do
    local parent = kind == INVENTORY_BACKPACK and ZO_PlayerInventory or ZO_PlayerBank
    bars[kind] = {}
    for _, category in ipairs({ALL, WEAPONS}) do
        bars[kind][category] = {control = widget("AF" .. kind .. "Category" .. category, parent, 9)}
    end
end
AdvancedFilters = { subfilterGroups = {
    [INVENTORY_BACKPACK] = {[CRAFTING_TYPE_INVALID] = bars[INVENTORY_BACKPACK], currentSubfilterBar = bars[INVENTORY_BACKPACK][ALL]},
    [INVENTORY_BANK] = {[CRAFTING_TYPE_INVALID] = bars[INVENTORY_BANK], currentSubfilterBar = bars[INVENTORY_BANK][ALL]},
} }
for _, kind in ipairs({INVENTORY_BACKPACK, INVENTORY_BANK}) do
    local inventory = PLAYER_INVENTORY.inventories[kind]
    inventory.currentFilter = ALL; inventory.subFilter = nil
    inventory.filterBar = kind == INVENTORY_BACKPACK and inventoryTabs or bankTabs
    inventory.tabFilters = {{inventoryType = kind, filterType = ALL}, {inventoryType = kind, filterType = WEAPONS}}
end
function PLAYER_INVENTORY:ChangeFilter(tab)
    self.inventories[tab.inventoryType].currentFilter = tab.filterType
    AdvancedFilters.subfilterGroups[tab.inventoryType].currentSubfilterBar = bars[tab.inventoryType][tab.filterType]
    AdvancedFilters.currentInventoryType = tab.inventoryType
end
local selectedDescriptor
function ZO_MenuBar_SelectDescriptor(_, descriptor)
    selectedDescriptor = descriptor
    PLAYER_INVENTORY.selectedTabType = descriptor == SI_BANK_DEPOSIT and INVENTORY_BACKPACK or INVENTORY_BANK
end
-- Preserve engine filter behavior independently of the earlier fixture's categories.
ZO_ItemFilterUtils = nil
G.saved.enabled = true; G.saved.externalFilters = true; G.saved.embeddedFilters = true
G.sceneName = "inventory"; bankOpen = false; G.selectedCharacter = S.characterId
PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
G:Refresh()
check(not A.host:IsHidden() and not G.root:IsHidden(), "embedded controls show without leaving grid")
check(inventoryTabs:GetParent() == A.host, "native category bar docked into grid")
check(bars[INVENTORY_BACKPACK][ALL].control:GetParent() == A.host, "actual AF subfilters and dropdown docked")
check(ZO_PlayerInventory:IsHidden(), "native list remains hidden")
check(G.backpack.filters[1]:IsHidden(), "duplicate grid categories hidden in embedded mode")
check(A.bankButton:IsHidden(), "bank context absent away from banker")
check(inventoryTabs:GetScale() < 1, "native bar fits narrow grid")
PLAYER_INVENTORY:ChangeFilter({inventoryType = INVENTORY_BACKPACK, filterType = WEAPONS})
G:Refresh()
check(A.currentBar == bars[INVENTORY_BACKPACK][WEAPONS], "category change mounts corresponding AF bar")
local liveFilterButton = WM:CreateControlFromVirtual("InstalledAFButton", A.currentBar.control, "ZO_DefaultButton")
local callback = function()
    LibFilters3.GetFilterTypeCallbacks = function(_, context)
        if context == LF_INVENTORY then return { AdvancedFilters = function(data) return data.slotIndex == 0 end } end
    end
    G:QueueRefresh()
end
liveFilterButton:SetHandler("OnClicked", callback)
G:Refresh()
check(liveFilterButton:GetHandler("OnClicked") == callback, "docking retains installed filter callbacks")
liveFilterButton:GetHandler("OnClicked")(liveFilterButton)
G:Refresh()
check(#G:ReadItems(G.backpack, {BAG_BACKPACK}) == 1, "embedded filter callback restricts live grid results")
check(bars[INVENTORY_BACKPACK][ALL].control:GetParent() == ZO_PlayerInventory, "previous category restored to owner")
check(bars[INVENTORY_BACKPACK][ALL].control:IsHidden(), "inactive category remains hidden")
G.saved.enabled = false; G:Refresh()
check(inventoryTabs:GetParent() == ZO_PlayerInventory and inventoryTabs:GetScale() == 1, "standard view restores category parent and scale")
local valid, point, relative, relativePoint, x, y, constraints = inventoryTabs:GetAnchor(0)
check(valid and relative == ZO_PlayerInventory and x == 7 and y == 4 and constraints == 999, "standard view restores exact anchors and constraints")
check(inventoryTabs:GetWidth() == 565 and inventoryTabs:GetHeight() == 40, "standard view restores dimensions")
check(next(A.mounted) == nil and A.host:IsHidden(), "standard view releases all borrowed widgets")
G.saved.enabled = true; bankOpen = true; G.sceneName = "bank"; G.afInventoryType = nil
PLAYER_INVENTORY.selectedTabType = INVENTORY_BANK; G:Refresh()
check(not A.bankButton:IsHidden() and A.currentBar == bars[INVENTORY_BANK][ALL], "bank initially uses withdrawal controls")
A.backpackButton.handlers.OnClicked(A.backpackButton)
G:Refresh()
check(selectedDescriptor == SI_BANK_DEPOSIT and A.currentBar == bars[INVENTORY_BACKPACK][WEAPONS], "backpack context uses native deposit selection")
check(AdvancedFilters.currentInventoryType == INVENTORY_BACKPACK, "native selection updates AF context")
A.bankButton.handlers.OnClicked(A.bankButton); G:Refresh()
check(selectedDescriptor == SI_BANK_WITHDRAW and A.currentBar == bars[INVENTORY_BANK][ALL], "bank context uses native withdrawal selection")
BANK_FRAGMENT = {IsShowing = function() return true end}
INVENTORY_FRAGMENT = {IsShowing = function() return false end}
G.afInventoryType = INVENTORY_BACKPACK; PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
check(A:GetContext(G) == INVENTORY_BANK, "actual withdrawal fragment overrides legacy tab and cached context")
BANK_FRAGMENT.IsShowing = function() return false end
INVENTORY_FRAGMENT.IsShowing = function() return true end
check(A:GetContext(G) == INVENTORY_BACKPACK, "actual deposit fragment selects backpack context")
BANK_FRAGMENT = nil; INVENTORY_FRAGMENT = nil
bankOpen = false; G.sceneName = "inventory"; PLAYER_INVENTORY.selectedTabType = INVENTORY_BACKPACK
G.selectedCharacter = "other-character"; G:Refresh()
check(A.host:IsHidden() and next(A.mounted) == nil, "snapshots release live filter widgets")
check(not G.backpack.filters[1]:IsHidden(), "snapshots retain saved-data category filters")
G.selectedCharacter = S.characterId; G.saved.embeddedFilters = false; G:Refresh()
check(A.host:IsHidden() and next(A.mounted) == nil, "filter toggle releases borrowed controls")
G.saved.embeddedFilters = true; G:Refresh()
check(not A.host:IsHidden(), "filter toggle restores embedded controls")
G.sceneName = nil; G:Refresh()
check(A.host:IsHidden() and next(A.mounted) == nil and inventoryTabs:GetParent() == ZO_PlayerInventory, "scene exit restores all controls")
AdvancedFilters = nil
check(not A:IsAvailable(), "missing addon handled without dependency failure")
print(string.format("PASS: %d embedded Advanced Filters checks (Lua 5.1, mocked widget contracts).", checks))
