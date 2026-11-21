local methods = getmetatable(GuiRoot).__index
function methods:SetTexture(value) self.texture = value end
function methods:SetColor(...) self.color = {...} end
function methods:ClearIcons() end
local create = WINDOW_MANAGER.CreateControl
function WINDOW_MANAGER:CreateControl(name, parent, kind)
    local control = create(self, name, parent, kind)
    if name and parent and parent.name and name:sub(1, #parent.name) == parent.name then
        parent.children[name:sub(#parent.name + 1)] = control
    end
    return control
end
function GetControl(control, child) return control:GetNamedChild(child) end
function SecurePostHook(target, name, callback)
    local original = target[name]
    target[name] = function(...)
        original(...)
        callback(...)
    end
end
ZO_PostHook = SecurePostHook
libResearch_Reason_INTRICATE = 'intricate'; libResearch_Reason_ORNATE = 'ornate'
libResearch_Reason_WRONG_ITEMTYPE = 'wrong'; libResearch_Reason_TRAITLESS = 'traitless'
ITEM_TRAIT_TYPE_ARMOR_INTRICATE = 40; ITEM_TRAIT_TYPE_WEAPON_INTRICATE = 41; ITEM_TRAIT_TYPE_JEWELRY_INTRICATE = 42
ITEM_TRAIT_TYPE_ARMOR_ORNATE = 43; ITEM_TRAIT_TYPE_WEAPON_ORNATE = 44; ITEM_TRAIT_TYPE_JEWELRY_ORNATE = 45
ITEMTYPE_WEAPON = 1; ITEMTYPE_RECIPE = 2; ITEMTYPE_RACIAL_STYLE_MOTIF = 3; ITEMTYPE_INGREDIENT = 4
INVENTORY_BACKPACK = 1; INVENTORY_BANK = 3
raCase, tracked, itemCase = 'researchable', true, 'gear'
RAFixture = {settings = {CONST_OFF_VALUE=0}, scanner={}}
local settings, scanner = RAFixture.settings, RAFixture.scanner
function settings:GetHideVanillaUIResearchableTexture() return false end
function settings:GetTextureSize() return 16 end
function settings:GetTexturePath() return 'research' end
function settings:GetTextureOffset() return 0 end
function settings:GetIntricateColor() return {0,1,1,1} end
function settings:GetOrnateColor() return {1,1,0,1} end
function settings:GetCanResearchColor() return {0,1,0,1} end
function settings:GetDuplicateUnresearchedColor() return {1,0.5,0,1} end
function settings:GetAlreadyResearchedColor() return {0.5,0.5,0.5,1} end
function settings:GetAlwaysShowResearchIcon() return false end
function settings:GetAlwaysShowResearchIconExcludeNonTracked() return true end
function settings:IsMultiCharSkillOff() return not tracked end
function settings:GetPreferenceValueForTrait() return 100 end
function settings:GetTrackedCharForSkill() return 'Fixture crafter' end
function settings:ShowTooltips() return false end
function settings:ShowResearched() return true end
function settings:ShowUntrackedIntricate() return true end
function settings:ShowUntrackedOrnate() return true end
function scanner:CheckIsItemResearchable()
    return 1, raCase == 'researchable' or raCase == 'duplicate',
        raCase == 'intricate' and libResearch_Reason_INTRICATE or (raCase == 'wrong' and libResearch_Reason_WRONG_ITEMTYPE or nil)
end
function scanner:GetItemCraftingSkill() return 1 end
function scanner:GetResearchLineIndex() return 1 end
function scanner:IsItemProtectedAgainstResearch() return false end
function scanner:CreateItemPreferenceValue() return raCase == 'duplicate' and 200 or 50 end
CSFixture = {Account={options={showsymbols=true, markitems=true}}}
function CSFixture.GetTrait() if itemCase == 'gear' then return 1,1,1 end end
function CSFixture.IsItemNeeded() return 'needed' end
function CSFixture.IsRecipeNeeded() return 'needed' end
function GetItemTrait() return itemCase == 'intricate' and ITEM_TRAIT_TYPE_WEAPON_INTRICATE or 0 end
function GetItemLinkItemType() return itemCase == 'recipe' and ITEMTYPE_RECIPE or ITEMTYPE_WEAPON, 0 end
function GetItemUniqueId(bag, slot) return bag * 1000 + slot end
bags[BAG_BACKPACK][0] = {name='Test gear',id=101,quality=2,filter=ITEMFILTERTYPE_WEAPONS}
bags[BAG_BANK][0] = {name='Bank gear',id=102,quality=2,filter=ITEMFILTERTYPE_WEAPONS}
function GetItemInfo() return 'gear.dds',1,0,true,false,0,0,2,2 end
local function List()
    return {dataTypes={[1]={setupCallback=function(row, data)
        local c = row:GetNamedChild('Button')
        ZO_Inventory_BindSlot(c, data.inventory.slotType, data.slotIndex, data.bagId)
        ZO_Inventory_SetupSlot(c, data.stackCount)
    end}}}
end
for _, name in ipairs({'ZO_PlayerInventoryList','ZO_PlayerBankBackpack','ZO_GuildBankBackpack','ZO_HouseBankBackpack',
    'ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack','ZO_SmithingTopLevelImprovementPanelInventoryBackpack',
    'ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack','ZO_LootAlphaContainerList'}) do _G[name]=List() end
PLAYER_INVENTORY = {selectedTabType=1, inventories={
    [1]={listView=ZO_PlayerInventoryList,slotType=SLOT_TYPE_ITEM},
    [3]={listView=ZO_PlayerBankBackpack,slotType=SLOT_TYPE_BANK_ITEM},
}}
SHARED_INVENTORY = {GenerateSingleSlotData=function(_, bag, slot)
    return {bagId=bag,slotIndex=slot,stackCount=1,name='Test gear',iconFile='gear.dds',displayQuality=2}
end}
G:Initialize()
G.sceneName='bank'; bankOpen=true; G.saved.externalFilters=false
local checks = 0
local function check(value, message) assert(value, message); checks=checks+1 end
local cells = {}
for _, panel in ipairs({G.backpack,G.bank}) do
    local cell=G:CreateCell(panel,99,false)
    cell.row.children.Research=nil; cell.row.children.CSMark=nil
    cell.row.children.Bg=WINDOW_MANAGER:CreateControl(cell.row.name..'Bg',cell.row,CT_CONTROL)
    cell.row:SetDimensions(48,48)
    cells[panel.key]=cell
end
function CheckInstalledRows()
    for _, panel in ipairs({G.backpack,G.bank}) do
        local cell=cells[panel.key]
        local item={bag=panel.key=='Backpack' and BAG_BACKPACK or BAG_BANK,slot=0}
        GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(cell.row:GetNamedChild('Research') and not cell.row:GetNamedChild('Research'):IsHidden(), panel.key..': actual RA creates research marker')
        check(cell.row.dataEntry.data.researchAssistant=='researchable',panel.key..': actual RA annotates copied slot data')
        check(cell.row:GetNamedChild('CSMark') and not cell.row:GetNamedChild('CSMark'):IsHidden(),panel.key..': actual CS creates needed-item mark')
        check(cell:GetHandler('OnDragStart')==mockNativeHandlers.OnDragStart,panel.key..': native drag handler unchanged')
        raCase='duplicate'; GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(cell.row.dataEntry.data.researchAssistant=='duplicate',panel.key..': actual RA duplicate marker path')
        tracked=false; GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(cell.row:GetNamedChild('Research'):IsHidden(),panel.key..': RA tracking Off hides marker')
        tracked=true; raCase='intricate'; itemCase='intricate'
        GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(not cell.row:GetNamedChild('Research'):IsHidden(),panel.key..': RA intricate path')
        check(not cell.row:GetNamedChild('CSMark'):IsHidden(),panel.key..': CS intricate symbols enabled')
        CSFixture.Account.options.showsymbols=false
        GridBagsCompatibility:HideDecorations(cell); GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(cell.row:GetNamedChild('CSMark'):IsHidden(),panel.key..': CS symbol setting suppresses intricate mark')
        itemCase='recipe'; raCase='wrong'
        GridBagsCompatibility:HideDecorations(cell); GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(not cell.row:GetNamedChild('CSMark'):IsHidden() and cell.row:GetNamedChild('Research'):IsHidden(),
            panel.key..': needed recipe gets CS mark without RA equipment mark')
        CSFixture.Account.options.markitems=false
        GridBagsCompatibility:HideDecorations(cell); GridBagsCompatibility:SetupRow(G,panel,cell,item)
        check(cell.row:GetNamedChild('CSMark'):IsHidden(),panel.key..': CS item-marking setting respected')
        CSFixture.Account.options.markitems=true
        CSFixture.Account.options.showsymbols=true; itemCase='gear'; raCase='researchable'
    end
    check(not GridBagsCompatibility.warnings or not GridBagsCompatibility.warnings.row,'no native row decorator error')
    print('PASS: '..checks..' actual RA/CraftStore entry-point contract checks')
end

CKFixture = {vars={tooltips={enabled=true}}, observed={}}
function CKFixture.AddTooltipExtension(control,link,source)
    CKFixture.observed[#CKFixture.observed+1]={control=control,link=link,source=source}
end
for _, name in ipairs({'SetLink','SetBagItem','SetTradeItem','SetBuybackItem','SetStoreItem','SetAttachedMailItem','SetLootItem',
    'SetReward','SetQuestReward','SetTradingHouseItem','SetTradingHouseListing','SetPlacedFurniture'}) do
    ItemTooltip[name]=function() end
end
PopupTooltip={SetLink=function() end}
CSFixture.tooltipObserved={}
function CSFixture.TooltipShow(control,link,uid) CSFixture.tooltipObserved[#CSFixture.tooltipObserved+1]={link=link,uid=uid} end
function CheckInstalledTooltips()
    local before=checks
    for _, bag in ipairs({BAG_BACKPACK,BAG_BANK}) do
        ItemTooltip:SetBagItem(bag,0)
        local ck=CKFixture.observed[#CKFixture.observed]
        local cs=CSFixture.tooltipObserved[#CSFixture.tooltipObserved]
        check(ck.link==GetItemLink(bag,0) and ck.source.bagId==bag and ck.source.slotIndex==0,'actual CK bag hook preserves bag/index')
        check(cs.link==GetItemLink(bag,0) and cs.uid==Id64ToString(GetItemUniqueId(bag,0)),'actual CS bag tooltip wrapper receives correct item')
    end
    ItemTooltip:SetLink('saved-item-link')
    check(CKFixture.observed[#CKFixture.observed].link=='saved-item-link' and CKFixture.observed[#CKFixture.observed].source==nil,'actual CK saved-link hook has no fabricated bag source')
    CKFixture.vars.tooltips.enabled=false
    local count=#CKFixture.observed; ItemTooltip:SetBagItem(BAG_BACKPACK,0)
    check(#CKFixture.observed==count,'actual CK tooltip setting respected')
    CKFixture.vars.tooltips.enabled=true
    print('PASS: '..(checks-before)..' actual CK/CraftStore tooltip registration checks')
end

BMRFixture={db={customItemRules={}},CustomRules={}}
local rules=BMRFixture.CustomRules
function rules.GetCustomRuleItemIdFromSlot(bag,slot) return GetItemId(bag,slot) end
function rules.AddCustomItemRuleFromSlot(bag,slot) BMRFixture.lastAction={'add',bag,slot} end
function rules.RemoveCustomItemRuleFromSlot(bag,slot) BMRFixture.lastAction={'remove',bag,slot} end
function ZO_Inventory_GetBagAndIndex(cell) return cell.bagId,cell.slotIndex end
function ZO_InventorySlot_GetType(cell) return cell.slotType end
LibCustomMenu={CATEGORY_LATE=99,RegisterContextMenu=function(self,callback) self.actualCallback=callback end}
function CheckInstalledBMR()
    local before=checks
    local ok=rules.RegisterCustomItemContextMenuActions()
    check(ok and BMRFixture.customItemActionsRegistered,'actual BMR context registration succeeds')
    for _, key in ipairs({'Backpack','Bank'}) do
        local cell=cells[key]
        local actions={AddCustomSlotAction=function(self,name,callback) self.name=name; self.callback=callback end}
        LibCustomMenu.actualCallback(cell,actions)
        check(actions.callback~=nil,key..': actual BMR action accepts grid slot')
        actions.callback()
        check(BMRFixture.lastAction[1]=='add' and BMRFixture.lastAction[2]==cell.bagId,key..': actual BMR callback carries correct bag')
        BMRFixture.db.customItemRules[tostring(GetItemId(cell.bagId,0))]=true
        actions.callback=nil; LibCustomMenu.actualCallback(cell,actions); actions.callback()
        check(BMRFixture.lastAction[1]=='remove',key..': actual BMR existing-rule action selected')
        BMRFixture.db.customItemRules={}
    end
    local saved=G:CreateCell(G.backpack,100,true); saved.bagId=nil; saved.slotIndex=nil
    local actions={AddCustomSlotAction=function(self) self.added=true end}
    LibCustomMenu.actualCallback(saved,actions)
    check(not actions.added,'actual BMR menu excludes unbound saved snapshot')
    print('PASS: '..(checks-before)..' actual BMR context-menu contract checks')
end

function CheckGridUpdateAfterTransfer()
    local before=checks
    G:Refresh()
    bags[BAG_BANK][0]=nil; bags[BAG_BACKPACK][1]={name='Moved gear',id=102,quality=2,filter=ITEMFILTERTYPE_WEAPONS}
    EVENT_MANAGER.events.GridBags[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil,BAG_BANK,0)
    EVENT_MANAGER.events.GridBags[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil,BAG_BACKPACK,1)
    EVENT_MANAGER.updates.GridBagsRefresh()
    check(G.backpack.count.text:find('2 /',1,true) and G.bank.count.text:find('0 /',1,true),'grid responds to transfer event sequence')
    check(G.bank.cells[1]:IsHidden(),'withdrawn bank item is no longer rendered')
    print('PASS: '..(checks-before)..' transfer-event refresh checks (transfer itself simulated)')
end
