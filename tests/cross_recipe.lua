local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local R,F,M,S,T,C=GridBagsRouting,GridBagsCrafting,GridBagsSmartRouting,GridBagsSnapshots,GridBagsTransferTools,GridBagsConfig
ITEMTYPE_ENCHANTING_RUNE_ESSENCE=7001;ITEMTYPE_INGREDIENT=7002;ITEMTYPE_STYLE_MATERIAL=7003
GetItemLinkItemType=function(link)return link=='rune'and ITEMTYPE_ENCHANTING_RUNE_ESSENCE or(link=='style'and ITEMTYPE_STYLE_MATERIAL or ITEMTYPE_INGREDIENT)end
GetItemLinkItemId=function(link)return link end
GetItemLink=function(bag,slot)return bags[bag][slot]and bags[bag][slot].name or ''end
GetBagSize=function(bag)return bag==BAG_SUBSCRIBER_BANK and 0 or 6 end;GetBagUseableSize=GetBagSize
M.CaptureProfessions=function()local data={};for craft=1,7 do data[craft]={rank=20,passivePoints=5,tier=2}end;return data end
local learned
F.CaptureRecipes=function()return learned end
local requests={}
CallSecureProtected=function(name,from,slot,to,target,qty)assert(name=='RequestMoveItem');requests[#requests+1]={from,slot,to,target,qty};return true end
local function reset()
    R.pending=nil;R.current=nil;R:Close();GridBagsRoutingUI:Close();GridBagsGoldUI:Close()
    R.character=characterId;R.data={plans={},rules={},protections={},profiles={}};G.saved.routing[GetWorldName()]=R.data
    G.saved.enabled=true;G.saved.transfersPaused=false;G.sceneName='bank';bankOpen=true;BMR=nil
    bags={[BAG_BACKPACK]={},[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={},[BAG_WORN]={}};requests={}
    learned={complete=true,at=timestamp,related={[4]={rune=true,style=true}},usable={[4]={rune=true,style=true},[5]={apple=true}},known={},ready={}}
    S.records={}
    for _,id in ipairs({characterId,'A','B'})do
        S.records[id]={name=id,items={},updatedAt=timestamp,professions=M:CaptureProfessions(),craftingRecipes=learned}
        R.data.profiles[id]={crafter=true}
    end
end
local function item(link,qty,uid)return {name=link,link=link,qty=qty or 10,uid=uid or link,maxStack=200,bag=BAG_BACKPACK,slot=0}end
local function rule(craft,scope,dest,mode)
    return assert(R:AddRule({material=true,craft=craft,scope=scope,source=R.ANY,dest=dest or'A',link='@materials',name='Materials',qty=200,maxStack=1,mode=mode or'standing',units=mode=='limited'and 1000 or nil,moves=mode=='limited'and 100 or nil}))
end
local function apply()
    local from,slot,to,target,qty=unpack(requests[#requests]);local old=bags[from][slot]
    if bags[to][target]then bags[to][target].qty=bags[to][target].qty+qty
    else bags[to][target]={id=2001,name=old.name,qty=qty,quality=2,filter=ITEMFILTERTYPE_CRAFTING}end
    old.qty=old.qty-qty;if old.qty==0 then bags[from][slot]=nil end;R:Observe()
end
reset()
check(F:Related('rune',3)and not F:Related('rune',4),'recipe catalog does not turn enchanting rune into Alchemy material')
check(F:Qualifies('rune','A',4,'all')==false and F:Qualifies('rune','A',4,'usable')==false,'both ordinary scopes reject cross-profession ingredients despite known recipe')
check(F:Qualifies('rune','A',4,'known')==true,'known skill-qualified recipe can explicitly use foreign ingredient')
rule(4,'all');R:GenerateRules({item('rune')},{})
check(#R.data.plans==0,'ordinary Alchemy storage cannot auto-send rune')
reset();rule(4,'usable');R:GenerateRules({item('rune')},{})
check(#R.data.plans==0,'ordinary Alchemy usable rule cannot send rune through recipe fallback')
reset();rule(4,'all');rule(3,'all','B');R:GenerateRules({item('rune')},{})
check(#R.data.plans==1 and R.data.plans[1].dest=='B','ordinary rune route remains with Enchanting')
reset();rule(4,'known');learned.usable[4].rune=nil
rule(3,'all','B');R:GenerateRules({item('rune')},{})
check(#R.data.plans==1 and R.data.plans[1].dest=='B','unknown or unqualified cross recipe neither allocates nor steals native stock')
reset();rule(4,'known');learned.complete=false;rule(3,'all','B');R:GenerateRules({item('rune')},{})
check(#R.data.plans==1 and R.data.plans[1].dest=='B','missing cross-recipe evidence does not block ordinary native material route')
reset();local crossRule=rule(4,'known');R:GenerateRules({item('rune')},{})
local p=R.data.plans[1]
check(p and p.mode=='ask'and p.smart.scope=='known','Standing known-recipe rule stages cross material as Ask')
local op={phase='source',allocations={{plan=p.id,qty=p.qty}}}
check(not R:Allowed(op),'Standing parent cannot authorize cross-profession move')
p.mode='standing';p.approved=true;check(not R:Allowed(op),'legacy or edited standing approval cannot substitute for explicit recipe consent')
R:Approve(p.id);check(R:Allowed(op)and p.recipeConsent,'one-time advance approval explicitly authorizes named cross-recipe quantity')
R:RetireRuleBatch(crossRule.id);check(p.state=='cancelled','rule change still cancels unstarted named route')
reset();crossRule=rule(4,'known',nil,'limited');crossRule.unitsLeft=1000;crossRule.movesLeft=100
R:GenerateRules({item('rune')},{})
p=R.data.plans[1];op={phase='source',allocations={{plan=p.id,qty=p.qty}}}
check(not R:Allowed(op),'Limited allowance does not automatically fund foreign ingredients')
reset();rule(5,'known');R:GenerateRules({item('apple')},{})
p=R.data.plans[1];op={phase='source',allocations={{plan=p.id,qty=p.qty}}}
check(p.mode=='standing'and not R:IsCrossRecipe(p)and R:Allowed(op),'same-profession known ingredients retain configured approval policy')
reset();rule(4,'known');R:GenerateRules({item('style')},{})
check(#R.data.plans==0,'style/trait category separation remains intact under recipe matching')
reset();local entries=F:RecipientSuggestions('rune',characterId)
local explicit
for _,entry in ipairs(entries)do if entry.craft==4 and entry.scope=='known'then explicit=entry end end
check(explicit and explicit.cross,'individual suggestions label verified cross-recipe ingredient explicitly')
learned.usable[4].rune=nil;entries=F:RecipientSuggestions('rune',characterId)
local incorrect=false;for _,entry in ipairs(entries)do if entry.craft==4 then incorrect=true end end
check(not incorrect,'unknown recipe catalog alone never suggests foreign recipient')
reset();local ordinary=rule(4,'all')
p=assert(R:Add({source=characterId,dest='A',link='rune',uid='rune',qty=10,mode='ask',rule=ordinary.id}))
local eligible,_,code=M:Eligible(p)
check(not eligible and code=='CROSS_PROFESSION_MATERIAL','old ordinary cross-profession proposal held with explicit reason')
p.state='bank';eligible,_,code=M:Eligible(p)
check(not eligible and code=='CROSS_PROFESSION_MATERIAL','old reserved foreign-material delivery cannot auto-pickup through ordinary rule')
reset();crossRule=rule(4,'known')
bags[BAG_BACKPACK][0]={id=1001,name='rune',qty=10,quality=2,filter=ITEMFILTERTYPE_CRAFTING}
R:Open();check(#requests==0 and R.current and R.current.qty==10,'known cross rule waits at banker instead of automatically moving')
local before=assert(C:Encode(R.data));local preview=assert(T:Preview())
check(#requests==0 and assert(C:Encode(R.data))==before and preview.rows[1].approval=='confirmation required','preview cannot grant cross-recipe consent')
R:Confirm(false);apply();p=R.data.plans[1]
check(p.state=='bank'and p.recipeConsent and R:Reserved('rune')==10,'manual confirmation authorizes and reserves only this named delivery')
R:Close();bags[BAG_BACKPACK][0]={id=1002,name='rune',qty=5,quality=2,filter=ITEMFILTERTYPE_CRAFTING}
R:Open();check(#requests==1 and R.current and not R.data.plans[2].recipeConsent,'later farmed foreign quantity requires fresh confirmation')
R:Confirm(true);apply();check(R:Reserved('rune')==15 and R.data.plans[2].recipeConsent,'explicit Confirm all approves named frozen-queue cross delivery')
R:Close();R.character='A';bags[BAG_BACKPACK]={};R:Open()
check(#requests==3 and R.pending and R.pending.qty==15,'previously confirmed cross quantities can complete their named pickup')
apply();check(R:Reserved('rune')==0 and R.data.plans[1].state=='done'and R.data.plans[2].state=='done','combined pickup completes consented quantities without duplication')
print('PASS: '..checks..' profession ownership and explicit cross-recipe approval checks (Lua 5.1 mock).')
