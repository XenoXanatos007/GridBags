local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local R,Q,U,M,F,S,T=GridBagsRouting,GridBagsRecipeGather,GridBagsRecipeGatherUI,GridBagsSmartRouting,GridBagsCrafting,GridBagsSnapshots,GridBagsTransferTools
-- ESO publishes named top-level controls as globals, unlike the basic mock.
local create=WINDOW_MANAGER.CreateTopLevelWindow
WINDOW_MANAGER.CreateTopLevelWindow=function(self,name)local control=create(self,name);_G[name]=control;return control end
U:Initialize()
check(GridBagsRecipeGather==Q and type(GridBagsRecipeGather.Keep)=='function','named recipe window cannot overwrite recipe module global')
check(GridBagsRecipeGatherWindow==U.window,'recipe window has a separate global identity')
WINDOW_MANAGER.CreateTopLevelWindow=create
ITEMTYPE_FURNISHING_MATERIAL=801;SPECIALIZED_ITEMTYPE_FURNISHING_MATERIAL_ALCHEMY=802
ITEMTYPE_REAGENT=803;ITEMTYPE_STYLE_MATERIAL=804;ITEMTYPE_ARMOR_TRAIT=805
GetItemLinkItemType=function(link)if link=='resin'then return ITEMTYPE_FURNISHING_MATERIAL,802 elseif link=='style'then return 804 elseif link=='trait'then return 805 else return 803 end end
local ids={resin=101,style=102,trait=103,flower=104}
GetItemLinkItemId=function(link)return ids[link]end
GetItemLink=function(bag,slot)return bags[bag][slot]and bags[bag][slot].name or ''end
GetBagSize=function(bag)return bag==BAG_SUBSCRIBER_BANK and 0 or 8 end;GetBagUseableSize=GetBagSize
local skillTier,known,quality,requirements,ingredients,virtual,shift=3,true,0,{{4,2},{1,1}},{{'resin',4},{'style',1},{'trait',2}},0,false
M.CaptureProfessions=function()local t={};for c=1,7 do t[c]={tier=skillTier,rank=30,passivePoints=3,rarity=3}end;return t end
GetRecipeInfo=function(list,index)return known,'A learned furnishing',#ingredients,0,quality,0,4,(shift and index==1)and 999 or 900 end
GetNumRecipeLists=function()return 1 end;GetRecipeListInfo=function()return 'Recipes',2 end
GetNumRecipeTradeskillRequirements=function()return #requirements end
GetRecipeTradeskillRequirement=function(_,_,i)return unpack(requirements[i])end
GetRecipeIngredientItemLink=function(_,_,i)return ingredients[i][1]end
GetRecipeIngredientItemInfo=function(_,_,i)return ingredients[i][1],'icon',ingredients[i][2]end
NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL=9001;GetNonCombatBonus=function()return 3 end
Q.CraftBagCount=function(_,i)return i.id==101 and virtual or 0 end
local calls=0;CallSecureProtected=function()calls=calls+1;return true end
local function stock(link,n,uid)return {link=link,name=link,displayName=link,stack=n,uid=uid or link,maxStack=200,bound=false}end
local function reset()
    U:Close();R:Close();R.character=characterId;R.pending=nil;R.current=nil
    R.data={plans={},rules={},protections={},profiles={}};G.saved.routing[GetWorldName()]=R.data
    G.saved.enabled=true;G.saved.transfersPaused=false;G.sceneName='inventory';bankOpen=false;GridBagsGold.pending=nil
    bags={[BAG_BACKPACK]={},[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={},[BAG_WORN]={}}
    skillTier=3;known=true;quality=0;virtual=0;shift=false;calls=0
    S.records={A={name='A',items={stock('resin',20),stock('style',10),stock('trait',10)},updatedAt=timestamp,professions=M:CaptureProfessions()}}
    G.saved.bankSnapshots[GetWorldName()]={items={stock('resin',3,'bankresin')},updatedAt=timestamp}
end
reset();known=false;check(not Q:Read(1,1,1),'unknown recipe refused');known=true
skillTier=1;check(not Q:Read(1,1,1),'multi profession skill shortfall refused');skillTier=3
quality=4;check(not Q:Read(1,1,1),'quality passive shortfall refused');quality=0
check(not Q:Read(1,1,0)and not Q:Read(1,1,1.5)and not Q:Read(1,1,1001),'batch validation')
local draft=assert(Q:Preview(1,1,2))
check(draft.rows[1].needed==8 and draft.rows[2].needed==2 and draft.rows[3].needed==4,'exact recipe units include style and trait')
check(#draft.proposals==4 and draft.proposals[1].source==R.BANK and draft.proposals[1].qty==3 and draft.proposals[2].qty==5,'bank first, finite remaining units from character')
check(calls==0 and #R.data.plans==0 and not R.data.gatherRequests,'preview has no transfer or persistence side effects')
draft.proposals[2].include=false
local request=assert(Q:Commit(draft))
check(#request.plans==3 and #R.data.plans==3 and calls==0,'confirmation respects excluded source and does not move items')
check(Q:Keep(characterId,'resin')==8 and R:KeepFloor(characterId,'style')==2,'target ingredients held for requested batches')
check(not Q:Preview(1,1,2),'active request prevents duplicate gathering')
for _,p in ipairs(R.data.plans)do check(p.mode=='advance'and p.approved and Q:Eligible(p),'named deliveries approved and known recipe checked')end
known=false;check(not Q:Eligible(R.data.plans[1]),'recipient must still know recipe');known=true
shift=true;local resolved=Q:Resolve(request.recipe);check(resolved and resolved.index==2,'recipe identity survives catalogue index changes');shift=false
Q:CloseRequest(request.id);check(Q:Keep(characterId,'resin')==0 and Q:Eligible(R.data.plans[1]),'release hold preserves approved named deliveries')
reset();virtual=2;bags[BAG_BACKPACK][0]={id=1,name='resin',qty=1,quality=2}
draft=assert(Q:Preview(1,1,1));check(draft.rows[1].have==3 and draft.rows[1].planned==1,'backpack and craft bag count as usable supplies')
reset();R:SetProtection(R.BANK,'resin',true,0);R:SetProtection('A','resin',false,19)
draft=assert(Q:Preview(1,1,1));check(draft.rows[1].planned==1 and draft.rows[1].missing==3,'source block and keep respected')
reset();S.records.A.items[1].locked=true;G.saved.bankSnapshots[GetWorldName()].updatedAt=timestamp-8*86400
draft=assert(Q:Preview(1,1,1));check(draft.rows[1].missing==4 and #draft.notices==1,'locked stock and stale bank excluded')
reset();S.records.A.updatedAt=timestamp-8*86400
draft=assert(Q:Preview(1,1,1));check(draft.rows[1].planned==3 and draft.rows[1].missing==1 and #draft.notices==1,'stale character excluded')
reset();local incoming=assert(R:Add({source='A',dest=characterId,link='resin',uid='resin',qty=2,mode='ask'}))
draft=assert(Q:Preview(1,1,1));check(draft.rows[1].incoming==2 and draft.rows[1].planned==2,'existing deliveries deducted without duplication')
incoming.state='review';draft=assert(Q:Preview(1,1,1));check(draft.rows[1].held==2 and draft.rows[1].planned==2,'review quantities are shown and not replaced')
reset();draft=assert(Q:Preview(1,1,1));R:SetProtection(R.BANK,'resin',true,0)
check(not Q:Commit(draft)and #R.data.plans==0,'changed protections reject stale confirmation atomically')
reset();draft=assert(Q:Preview(1,1,1));local add=R.Add;local attempts=0
R.Add=function(self,spec)attempts=attempts+1;if attempts==2 then return nil,'simulated failure'end;return add(self,spec)end
check(not Q:Commit(draft)and #R.data.plans==0 and not next(R.data.gatherRequests or {})and not R.data.nextId,'failed addition rolls back whole batch and IDs');R.Add=add
reset();request=assert(Q:Commit(assert(Q:Preview(1,1,1))));local plan=R.data.plans[1]
R.character='A';check(Q:Eligible(plan),'offline recipient approved recipe proof valid')
timestamp=timestamp+8*86400;check(not Q:Eligible(plan),'stale recipe proof holds delivery');timestamp=timestamp-8*86400
S.records[characterId]={updatedAt=timestamp+1,professions=nil};check(not Q:Eligible(plan),'newer missing skills fail closed')
S.records[characterId].professions=M:CaptureProfessions();check(Q:Eligible(plan),'newer sufficient skills accepted')
S.records[characterId].professions[1].tier=0;check(not Q:Eligible(plan),'newer insufficient secondary profession held')
reset();R.data.profiles.A={crafts={[4]={crafter=true}}}
check(F:FurnishingProfession('resin')==4 and F:AutomaticFurnitureRoute('flower',characterId,R.BANK),'furniture profession separated from ordinary materials')
check(F:AutomaticFurnitureRoute('resin',characterId,'A'),'farmer can supply matching crafter')
check(not F:AutomaticFurnitureRoute('resin','A',R.BANK)and not F:AutomaticFurnitureRoute('resin','A',characterId),'assigned crafter retains own furniture materials')
check(not F:AutomaticFurnitureRoute('resin',characterId,R.BANK)and not F:AutomaticFurnitureRoute('resin',R.BANK,characterId),'no automatic generic bank or noncrafter diversion')
local p=assert(R:Add({source='A',dest=characterId,link='resin',uid='resin',qty=1,mode='standing'}));local op={allocations={{plan=p.id,qty=1}},phase='source'}
check(not R:Allowed(op),'standing rule cannot authorize furniture exception');R:Approve(p.id)
check(R:Allowed(op)and p.recipeConsent,'manual named furniture exception allowed')
reset();R.data.profiles.A={crafts={[4]={crafter=true}}};request=assert(Q:Commit(assert(Q:Preview(1,1,1))))
local sourcePlan;for _,value in ipairs(R.data.plans)do if value.source=='A'and value.link=='resin'then sourcePlan=value end end
check(sourcePlan and sourcePlan.recipeConsent and R:Allowed({phase='source',allocations={{plan=sourcePlan.id,qty=1}}}),'explicit selected recipe can pull furniture material from its keeper')
reset();R.data.profiles.A={crafts={[4]={crafter=true}}}
local rule=assert(R:AddRule({material=true,craft=4,scope='all',source=characterId,dest='A',link='@materials',qty=200,maxStack=1,mode='standing'}))
R:GenerateRules({{link='resin',name='resin',qty=10,uid='farm',maxStack=200}}, {})
check(#R.data.plans==1 and R:Allowed({phase='source',allocations={{plan=R.data.plans[1].id,qty=10}}}),'ordinary rule supplies native furniture crafter automatically')
reset();R.data.profiles[characterId]={crafts={[4]={crafter=true}}}
rule=assert(R:AddRule({material=true,craft=0,scope='all',source=characterId,dest=R.BANK,link='@materials',qty=200,maxStack=1,mode='standing'}))
R:GenerateRules({{link='resin',name='resin',qty=10,uid='owned',maxStack=200}}, {})
check(#R.data.plans==0 and rule.reasonCode=='FURNITURE_KEEPER','blanket gatherer rule leaves furniture with its crafter')
reset();G.saved.bankSnapshots[GetWorldName()].items={stock('resin',4),stock('style',1),stock('trait',2)}
request=assert(Q:Commit(assert(Q:Preview(1,1,1))))
bags[BAG_BANK][0]={id=301,name='resin',qty=4,quality=2};bags[BAG_BANK][1]={id=302,name='style',qty=1,quality=2};bags[BAG_BANK][2]={id=303,name='trait',qty=2,quality=2}
bankOpen=true;G.sceneName='bank'
local movements={};CallSecureProtected=function(name,from,slot,to,target,qty)check(name=='RequestMoveItem','only secure inventory movement requested');movements[#movements+1]={from,slot,to,target,qty};return true end
R:Open();check(R.pending and #movements==1,'confirmed bank ingredients execute using existing route checks')
while R.pending do
    local move=movements[#movements];local from,slot,to,target,qty=unpack(move);local old=bags[from][slot]
    bags[to][target]={id=old.id+100,name=old.name,qty=qty,quality=2};old.qty=old.qty-qty;if old.qty==0 then bags[from][slot]=nil end
    R:Observe();R:Tick()
end
check(#movements==3 and #R.data.plans==3,'exactly one physical operation per required ingredient stack')
for _,plan in ipairs(R.data.plans)do check(plan.state=='done','gather pickup verified')end
check(Q:Keep(characterId,'resin')==4 and R:RuleAvailable({source=characterId,maxPerStack=200},R:Scan(characterId),R:Scan(characterId)[1])==0,'delivered recipe supplies stay reserved from ordinary exports')
Q:CloseRequest(request.id);check(R:KeepFloor(characterId,'resin')==0,'release after crafting restores normal routing')
reset();U:Show(1,1,1);check(U.draft and GridBagsRoutingUI.editingSession,'review window pauses planned transfers')
U.rows[1].button:GetHandler('OnClicked')();check(U.mode=='transfers'and U.ingredientFilter==101,'ingredient sources button filters the source list')
U.rows[1].button:GetHandler('OnClicked')();check(U.draft.proposals[1].include==false,'source can be unchecked')
U.batches:SetText('2');U:Confirm();check(not U.draft and #R.data.plans==0,'changed batch edit forces fresh preview')
U:Close();check(not GridBagsRoutingUI.editingSession,'close releases transfer pause')
local hooks={};SecurePostHook=function(object,name,fn)hooks[name]=fn end
PROVISIONER={control=WINDOW_MANAGER:CreateTopLevelWindow('ProvisionerMock'),GetSelectedRecipeListIndex=function()return 1 end,GetSelectedRecipeIndex=function()return 1 end,GetMultiCraftNumIterations=function()return 2 end,RefreshRecipeDetails=function()end}
local craftStart=function()error('must not craft')end
CraftStoreFixedAndImprovedLongClassName={CookShowRecipe=function()end,CookStart=craftStart}
U:AttachNative();check(U.nativeButton and hooks.RefreshRecipeDetails and hooks.CookShowRecipe,'native selection and CraftStore row hooks attached')
U.nativeButton:GetHandler('OnClicked')();check(U.draft.recipe.batches==2,'native button uses exact selected recipe and batch count');U:Close()
local row=WINDOW_MANAGER:CreateControl('CSRecipeMock',GuiRoot)
hooks.CookShowRecipe(row,1,2);row.gridBagsGatherButton:GetHandler('OnClicked')(row.gridBagsGatherButton)
check(U.index==2 and CraftStoreFixedAndImprovedLongClassName.CookStart==craftStart and calls==0,'CraftStore button uses own row without touching crafting handler');U:Close()
print('PASS: '..checks..' recipe gather and furniture retention checks (Lua 5.1 mock).')
