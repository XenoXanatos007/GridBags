local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
local F,R,M,S,U,C,T=GridBagsCrafting,GridBagsRouting,GridBagsSmartRouting,GridBagsSnapshots,GridBagsCraftingUI,GridBagsConfig,GridBagsTransferTools
local function clone(value)return T:Clone(value)end
local skills={}
for craft=1,7 do skills[craft]={rank=20,tier=2,passivePoints=4,at=timestamp} end
M.CaptureProfessions=function()return clone(skills)end
NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL=90
local rarity=2
GetNonCombatBonus=function()return rarity end
ITEMTYPE_INGREDIENT=3001;ITEMTYPE_BLACKSMITHING_MATERIAL=3002;ITEMTYPE_REAGENT=3003
ITEMTYPE_ENCHANTING_RUNE_ESSENCE=3004;ITEMTYPE_STYLE_MATERIAL=3005
ITEMTYPE_JEWELRY_TRAIT=3006;ITEMTYPE_POISON_BASE=3007
SPECIALIZED_ITEMTYPE_FURNISHING_MATERIAL_ALCHEMY=3104
GetItemLinkItemId=function(link)return link:match('^[^:]+')end
GetItemLinkItemType=function(link)
    if link:find('ore',1,true)then return ITEMTYPE_BLACKSMITHING_MATERIAL end
    if link=='reagent'then return ITEMTYPE_REAGENT end
    if link=='essence'then return ITEMTYPE_ENCHANTING_RUNE_ESSENCE end
    if link=='style'then return ITEMTYPE_STYLE_MATERIAL end
    if link=='jeweltrait'then return ITEMTYPE_JEWELRY_TRAIT end
    if link=='furnish'then return 999,SPECIALIZED_ITEMTYPE_FURNISHING_MATERIAL_ALCHEMY end
    if link=='poisonbase'then return ITEMTYPE_POISON_BASE end
    return ITEMTYPE_INGREDIENT
end
GetItemLinkRequiredCraftingSkillRank=function(link)return link=='highore'and 5 or 2 end
local recipes={
    {known=true,craft=5,level=2,quality=2,ingredients={'apple:recipe','flour'},requirements={{5,2}}},
    {known=false,craft=5,level=1,quality=1,ingredients={'berry'},requirements={{5,1}}},
    {known=true,craft=5,level=5,quality=2,ingredients={'hightier'},requirements={{5,5}}},
    {known=true,craft=6,level=0,quality=0,ingredients={'resin','style'},requirements={{6,2},{1,3}}},
}
GetNumRecipeLists=function()return 1 end
GetRecipeListInfo=function()return 'Recipes',#recipes end
GetRecipeInfo=function(_,index)local r=recipes[index];return r.known,'recipe',#r.ingredients,r.level,r.quality,0,r.craft end
GetNumRecipeTradeskillRequirements=function(_,index)return #recipes[index].requirements end
GetRecipeTradeskillRequirement=function(_,index,n)return unpack(recipes[index].requirements[n])end
GetRecipeIngredientItemLink=function(_,index,n)return recipes[index].ingredients[n]end
local captured=F:CaptureRecipes(true)
check(captured.complete and captured.usable[5].apple and captured.usable[5].flour,'learned skill-qualified recipe ingredients captured by item ID')
check(not captured.usable[5].berry and captured.related[5].berry,'unknown recipe contributes relation but never learned-recipe eligibility')
check(not captured.usable[5].hightier,'known recipe above material passive tier excluded')
check(not captured.usable[6].resin,'furnishing checks every required profession')
check(captured.known[5]==2 and captured.ready[5]==1,'overview separates known from skill-qualified recipe counts')
rarity=1;check(not F:CaptureRecipes(true).usable[5].apple,'recipe quality passive enforced');rarity=2
skills[1].tier=3;check(F:CaptureRecipes(true).usable[6].resin,'multicraft furnishing becomes eligible only after secondary skill qualifies')
skills[1].tier=2;captured=F:CaptureRecipes(true)
local ingredientAPI=GetRecipeIngredientItemLink
GetRecipeIngredientItemLink=function()error('not ready')end
check(not F:CaptureRecipes(true).complete,'partial native recipe scan cannot be used as complete evidence')
GetRecipeIngredientItemLink=ingredientAPI;captured=F:CaptureRecipes(true)
local function reset()
    R:Close();R.pending=nil;R.current=nil;R.character=characterId
    R.data={plans={},rules={},profiles={},protections={}};G.saved.routing[GetWorldName()]=R.data
    S.records={}
    for _,id in ipairs({characterId,'A','B'})do S.records[id]={name=id,updatedAt=timestamp,items={},professions=clone(skills),craftingRecipes=clone(captured)}end
    bankOpen=true;G.sceneName='bank';G.saved.transfersPaused=false
end
reset()
check(F:Qualifies('apple:bag','A',5,'known')==true,'saved recipe ingredients match different item-link variants')
check(F:Qualifies('berry','A',5,'known')==false,'known absent recipe is definite ineligibility')
S.records.A.craftingRecipes=nil
check(F:Qualifies('apple','A',5,'known')==nil,'old snapshots hold until recipe capture exists')
S.records.A.craftingRecipes=clone(captured);S.records.A.craftingRecipes.at=timestamp-8*86400
check(F:Qualifies('apple','A',5,'known')==nil,'new inventory scan cannot refresh an old recipe scan')
reset();S.records.A.updatedAt=timestamp-8*86400
check(F:Qualifies('ore','A',1,'usable')==nil,'stale profession data held')
check(F:Qualifies('ore','A',1,'all')==true,'explicit storage scope does not pretend to require crafting skills')
reset()
check(F:Qualifies('ore','A',1,'usable')==true and F:Qualifies('highore','A',1,'usable')==false,'base material tier supported with definite high-tier rejection')
check(F:Qualifies('reagent','A',4,'usable')==true and F:Qualifies('essence','A',3,'usable')==true,'tier-free reagents and essence runes supported')
check(F:Qualifies('style','A',1,'usable')==false,'shared material cannot enter a profession usable-material rule')
check(F:Related('style',8)and not F:Related('style',1)and not F:Related('style',6),'style materials have an independent category even when used by furnishing recipes')
check(F:Related('jeweltrait',9)and not F:Related('jeweltrait',7),'jewelry traits use the shared trait category')
check(F:Related('furnish',4)and not F:Related('furnish',1),'furnishing specialized type preserves second native return')
check(not F:Related('resin',6),'recipe catalog cannot broaden ordinary profession ownership')
ITEMTYPE_ENCHANTING_RUNE_ASPECT=3008
local previousType=GetItemLinkItemType
GetItemLinkItemType=function(link)if link=='aspect'then return ITEMTYPE_ENCHANTING_RUNE_ASPECT end;return previousType(link)end
S.records.A.professions[3].rarity=1
check(F:Qualifies('aspect','A',3,'usable')==false,'aspect rune uses quality passive instead of potency tier')
S.records.A.professions[3].rarity=3
check(F:Qualifies('aspect','A',3,'usable')==true,'aspect quality becomes usable with sufficient passive')

local function item(link,qty,uid)return {link=link,name=link,qty=qty or 100,uid=uid or link,maxStack=200,bag=BAG_BACKPACK,slot=0}end
local function rule(scope,dest,craft,source,qty,mode)
    return assert(R:AddRule({material=true,craft=craft or 5,scope=scope,source=source or characterId,dest=dest or 'A',
        link='@materials',name='Materials '..scope,qty=qty or 200,maxStack=1,mode=mode or 'ask'}))
end
local function generate(items,bank)R:GenerateRules(items or {},bank or {})end
reset();rule('all','B');rule('known','A');generate({item('apple'),item('berry',50)})
check(#R.data.plans==2 and R.data.plans[1].dest=='A'and R.data.plans[1].link=='apple','specific known-recipe scope outranks earlier blanket storage rule')
check(R.data.plans[2].dest=='B'and R.data.plans[2].link=='berry','definite noncraftable ingredients fall back to explicit storage recipient')
check(not R.data.plans[1].approved and R.data.plans[1].mode=='ask','blanket matching does not grant approval')
local count=#R.data.plans;generate({item('apple'),item('berry',50)})
check(#R.data.plans==count,'unsettled blanket batches do not duplicate')
reset();rule('all','B');rule('known','A');S.records.A.craftingRecipes=nil;generate({item('apple')})
check(#R.data.plans==0,'unknown recipe evidence holds against lower-priority storage fallback')
reset();rule('all','B');rule('known','A',5,nil,20);generate({item('apple')})
check(#R.data.plans==2 and R.data.plans[1].remaining==20 and R.data.plans[2].remaining==80,'overlapping capped rules share only unallocated units')
R.data.visit={queue={},touched={},index=1,id=1};R:BuildQueue({item('apple')},{})
check(#R.data.visit.queue==1 and R.data.visit.queue[1].qty==100,'split blanket recipients coalesce into one physical source-stack operation')
reset();rule('known','A');R:SetProtection(characterId,'apple',false,60);generate({item('apple')})
check(#R.data.plans==1 and R.data.plans[1].qty==40,'blanket rules honor exact source keep floors')
reset();rule('known','A');R:SetProtection(characterId,'apple',true,0);generate({item('apple')})
check(#R.data.plans==0,'never-export protection overrides blanket rules')
reset();rule('known','A');R:SetProtection(characterId,'apple',false,40)
local uncertain=assert(R:Add({source=characterId,dest='B',link='apple',uid='old-stack',qty=30,maxStack=200,mode='ask'}))
uncertain.state='review';uncertain.reserve=true;generate({item('apple',100,'new-stack')})
check(#R.data.plans==2 and R.data.plans[2].qty==30,'uncertain source outcomes retain allocation against keep floors on other stacks')
reset();rule('known','A');local locked=item('apple');locked.blocked=true;generate({locked})
check(#R.data.plans==0,'locked stock never becomes a blanket proposal')
reset();rule('known','A',5,R.BANK)
assert(R:Add({source=R.BANK,dest='B',link='apple',uid='other',qty=30,maxStack=200,mode='ask'}))
generate({}, {item('apple')})
check(#R.data.plans==2 and R.data.plans[2].qty==70,'bank reservations cannot be borrowed by blanket rules')
reset();rule('known','A',5,'B');generate({item('apple')})
check(#R.data.plans==0,'offline source snapshot does not trigger physical-source batch generation')
reset();R.data.profiles.A={crafter=true,priority=1};R.data.profiles.B={crafter=true,priority=2}
check(F:Best(5)=='A','profession assessment uses general role defaults')
R.data.profiles.A.crafts={[5]={crafter=false,priority=1}}
check(F:Best(5)=='B'and F:Best(1)=='A','per-profession role overrides do not change other profession defaults')
R.data.profiles.A.crafts[5].crafter=true;R.data.profiles.B.priority=1
check(not F:Best(5),'equal rank/passive/priority leads held instead of choosing arbitrary character')
R.data.profiles.B.priority=2;S.records.B.updatedAt=timestamp-8*86400
check(not F:Best(5),'stale designated competitor prevents false best-crafter selection')
reset();R.data.profiles.A={crafter=true,priority=1};R.data.profiles.B={crafter=true,priority=2}
rule('known','@best-crafter');generate({item('apple')});local pinned=R.data.plans[1]
check(pinned and pinned.dest=='A','dynamic profession lead resolves to a concrete named delivery')
R.data.profiles.A.priority=3;generate({item('apple')})
check(#R.data.plans==1 and pinned.dest=='A','changing priorities never retargets existing approved or pending delivery')
pinned.state='done';generate({item('apple')})
check(#R.data.plans==2 and R.data.plans[2].dest=='B','next settled batch reassesses dynamic profession target')
S.records.B.craftingRecipes.usable[5].apple=nil
check(not M:Eligible(R.data.plans[2]),'execution rechecks known-recipe qualification after planning')
reset();R.data.profiles[characterId]={crafter=true};rule('all','B');rule('usable','@best-crafter',1)
generate({item('ore')});check(#R.data.plans==0,'current lead retains its own usable materials against storage fallback')
reset();rule('all','B',1);rule('usable','A',1);generate({item('highore')})
check(#R.data.plans==1 and R.data.plans[1].dest=='B','unusable tier goes only to explicitly configured storage fallback')
reset();rule('known','A',5,R.BANK);S.records.A.craftingRecipes=nil
assert(R:AddRule({source=R.BANK,dest='B',link='apple',name='apple',qty=200,maxStack=200,mode='ask',overflow=true,overflowStacks=0}))
generate({}, {item('apple')});check(#R.data.plans==0,'unknown qualified evidence also protects against exact overflow')
check(not R:BuildRule({material=true,craft=9,scope='all'}),'invalid profession rejected')
check(not R:BuildRule({material=true,craft=1,scope='unknown'}),'invalid material scope rejected')
check(not R:Add({source=characterId,dest='@best-crafter',link='ore',uid='ore',qty=1,mode='ask'}),'execution ledger refuses unresolved dynamic destinations')
check(not R:BuildRule({material=true,craft=1,scope='usable',source=characterId,dest=R.BANK}),'qualification scope requires a character destination')

reset();local saved=rule('known','@best-crafter',5,nil,100,'standing')
R.data.profiles.A={crafter=true,priority=10,crafts={[5]={crafter=true,learner=true,researcher=false,priority=2}}}
local config=T:CaptureConfig();local decoded=assert(C:Decode(assert(C:Encode(config))))
check(decoded.characters['@best-crafter']==nil and decoded.rules[1].material,'export retains rule definition without inventing a character for dynamic selector')
local prepared=assert(C:Prepare(decoded,C:Mappings(decoded)))
check(prepared.rules[1].craft==5 and prepared.rules[1].scope=='known'and prepared.rules[1].mode=='ask'and not prepared.rules[1].enabled,'material rule import preserves qualification but revokes automation')
check(prepared.roles.A.crafts[5].priority==2 and prepared.roles.A.crafts[5].learner,'profession roles survive validated configuration import')
decoded.roles.A.crafts[9]={crafter=true};check(not C:Prepare(decoded,C:Mappings(decoded)),'malformed imported profession role rejected')
U:Show();check(not U.window:IsHidden()and U.rows[5].label:GetText():find('tier',1,true),'craft overview shows current skill details')
U:Edit(saved);check(GridBagsRoutingUI.editingSession and not U.editor:IsHidden(),'editing blanket rules pauses transfer decisions')
U.editing.dest='A';U.quantity:SetText('50');U:Save()
check(R:Rule(saved.id).maxPerStack==50 and R:Rule(saved.id).dest=='A','existing blanket rule can be edited in place')
check(not GridBagsRoutingUI.editingSession and U.editor:IsHidden(),'saved editor releases focus and transfer pause')
U:Edit();U.quantity:SetText('0');U:Save()
check(not U.editor:IsHidden()and U.message:GetText()~='','invalid rule remains reviewable in editor')
U:Close();check(not GridBagsRoutingUI.editingSession,'cancel releases editor pause')
S.ready=true;F.recipeCache=nil;S:Capture()
check(S.records[characterId].craftingRecipes.complete,'inventory snapshot includes independent crafting recipe observation')
reset()
local clearing=rule('all',R.BANK,0)
generate({item('ore'),item('reagent',20,'fungus'),item('apple',30,'food')})
check(#R.data.plans==3,'one named-source clearing rule collects materials across professions')
check(R.data.plans[1].dest==R.BANK and not R.data.plans[1].approved,'clearing is an ordinary bank deposit with explicit approval')
reset();clearing=rule('all','A',0);clearing.sourceUnassigned=true
R.data.profiles[characterId]={crafts={[1]={crafter=true},[4]={crafter=false}}}
generate({item('ore'),item('reagent',20,'fungus'),item('style',10,'style')})
check(#R.data.plans==1 and R.data.plans[1].link=='reagent'and R.data.plans[1].dest=='A','source non-crafter filter retains assigned profession and shared materials')
check(clearing.reasonCode=='SOURCE_IS_CRAFTER'and clearing.reason:find('retained',1,true),'source profession exclusions report an explicit reason for retained materials')
check(not R:BuildRule({material=true,craft=0,scope='known',source=characterId,dest='A'}),'all-profession clearing cannot silently imply one crafting eligibility check')
reset();R.data.profiles.A={crafter=true,priority=1};R.data.profiles.B={crafter=true,priority=2}
local candidates,supported=F:RecipientSuggestions('reagent',characterId)
check(supported and #candidates==2 and candidates[1].id=='A'and candidates[1].lead and candidates[1].scope=='usable','White Cap type reagents offer ranked qualified alchemy recipients')
candidates=F:RecipientSuggestions('apple',characterId)
check(candidates[1].scope=='known'and candidates[1].craft==5,'ingredient suggestions retain learned-recipe qualification')
S.records.A.craftingRecipes=nil;S.records.B.craftingRecipes=nil
candidates=F:RecipientSuggestions('apple',characterId)
check(#candidates==0,'missing recipe evidence cannot become a smart ingredient recipient')
reset();R.data.profiles.A={crafter=true,priority=1}
GridBagsRoutingUI.editing={source=characterId,dest=R.BANK,link='reagent',mode='ask',qty=10}
menuEntries={};GridBagsRoutingUI:Suggestions({})
local suggested
for _,entry in ipairs(menuEntries)do if entry.name:find('Lead Alchemy',1,true)then suggested=entry end end
check(suggested~=nil,'individual planner exposes broader reagent suggestion')
suggested.callback()
check(GridBagsRoutingUI.editing.dest=='A'and GridBagsRoutingUI.editing.smart.kind=='materials','individual suggestion pins a named recipient and execution qualification')
local spec=GridBagsRoutingUI.editing
local one=assert(R:Add({source=characterId,dest='A',link='reagent',uid='fungus',qty=10,mode='ask',smart=spec.smart}))
check(M:Eligible(one),'individual reagent route passes the shared execution check')
S.records.A.updatedAt=timestamp-8*86400
check(not M:Eligible(one),'preselected individual recipient still requires fresh profession data')
reset();clearing=rule('all',R.BANK,0);clearing.sourceUnassigned=true
local cfg=T:CaptureConfig();local imported=assert(C:Prepare(cfg,C:Mappings(cfg)))
check(imported.rules[1].craft==0 and imported.rules[1].sourceUnassigned and imported.rules[1].mode=='ask','gatherer clearing condition survives conservative configuration import')
local exact=assert(R:AddRule({source=characterId,dest='A',link='apple',name='apple',qty=10,maxStack=200,mode='ask',smart={kind='materials',craft=5,scope='known'}}))
cfg=T:CaptureConfig();imported=assert(C:Prepare(cfg,C:Mappings(cfg)))
check(imported.rules[2].smart.scope=='known','specific ingredient rules retain smart qualification in import')
print('PASS: '..checks..' profession, recipe eligibility, material routing, overlap, editor and config checks (Lua 5.1 mock).')
