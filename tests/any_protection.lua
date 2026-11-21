local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
local R,F,M,S,U,T,C,I=GridBagsRouting,GridBagsCrafting,GridBagsSmartRouting,GridBagsSnapshots,GridBagsProtectionUI,GridBagsTransferTools,GridBagsConfig,GridBagsRoutingInsights
ITEMTYPE_STYLE_MATERIAL=5001;ITEMTYPE_ARMOR_TRAIT=5002;ITEMTYPE_WEAPON_TRAIT=5003
ITEMTYPE_JEWELRY_TRAIT=5004;ITEMTYPE_JEWELRY_RAW_TRAIT=5005;ITEMTYPE_RAW_MATERIAL=5006;ITEMTYPE_INGREDIENT=5007
GetItemLinkItemType=function(link)
    local kinds={style=ITEMTYPE_STYLE_MATERIAL,armortrait=ITEMTYPE_ARMOR_TRAIT,weapontrait=ITEMTYPE_WEAPON_TRAIT,jeweltrait=ITEMTYPE_JEWELRY_TRAIT,rawtrait=ITEMTYPE_JEWELRY_RAW_TRAIT,rawstyle=ITEMTYPE_RAW_MATERIAL}
    return kinds[link]or ITEMTYPE_INGREDIENT
end
GetItemLinkRefinedMaterialItemLink=function(link)return link=='rawstyle'and 'style'or ''end
GetItemLinkItemId=function(link)return link end
GetItemLink=function(bag,slot)return bags[bag][slot]and bags[bag][slot].name or ''end
GetBagSize=function(bag)return bag==BAG_SUBSCRIBER_BANK and 0 or 6 end;GetBagUseableSize=GetBagSize
local requests={}
CallSecureProtected=function(name,from,slot,to,target,qty)assert(name=='RequestMoveItem');requests[#requests+1]={from,slot,to,target,qty};return true end
local function reset()
    R.pending=nil;R.current=nil;R:Close();GridBagsRoutingUI:Close();GridBagsGoldUI:Close();U:Close()
    R.character=characterId;R.data={plans={},rules={},profiles={},protections={}};G.saved.routing[GetWorldName()]=R.data
    S.records={};for _,id in ipairs({characterId,'A','B'})do S.records[id]={name=id,updatedAt=timestamp,items={}}end
    G.saved.transfersPaused=false;G.saved.enabled=true;G.sceneName='bank';bankOpen=true;BMR=nil
    bags={[BAG_BACKPACK]={},[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={},[BAG_WORN]={}};requests={}
    F.recipeCache={complete=true,at=timestamp,related={[6]={style=true,armortrait=true}},usable={[6]={style=true}},known={},ready={}}
end
local function item(link,qty,uid)return {link=link,name=link,qty=qty or 100,uid=uid or link,maxStack=200,bag=BAG_BACKPACK,slot=0}end
local function material(source,dest,craft)
    return assert(R:AddRule({material=true,craft=craft,scope='all',source=source,dest=dest,link='@materials',name='Materials',qty=200,maxStack=1,mode='ask'}))
end
local function generate(backpack,bank)R:GenerateRules(backpack or {},bank or {})end
reset();local rule=material(R.ANY,'A',5)
generate({item('apple',50,'pack')},{item('apple',80,'bank')})
check(#R.data.plans==2 and R.data.plans[1].source==characterId and R.data.plans[2].source==R.BANK,'Any expands to concrete current backpack and bank sources')
check(R.data.plans[1].dest=='A'and R.data.plans[2].dest=='A'and rule.source==R.ANY,'Any definition stays reusable while deliveries are named')
check(not R.data.plans[1].approved and not R.data.plans[2].approved,'Any preserves Ask confirmation for each concrete batch')
generate({item('apple',50,'pack')},{item('apple',80,'bank')})
check(#R.data.plans==2,'Any does not duplicate unresolved source batches')
R.character='B';generate({item('apple',30,'second')},{item('apple',80,'bank')})
check(#R.data.plans==3 and R.data.plans[3].source=='B','one character pending delivery does not block another Any source')
reset();material(R.ANY,'A',5);R.character='A'
generate({item('apple',50,'own')},{item('apple',80,'bank')})
check(#R.data.plans==1 and R.data.plans[1].source==R.BANK,'recipient retains its backpack and can collect bank stock without a bounce loop')
reset();material(R.ANY,R.BANK,5);generate({item('apple')},{item('apple',60,'bank')})
check(#R.data.plans==1 and R.data.plans[1].source==characterId,'Any-to-bank is deposit-only and skips bank-to-bank routes')
reset();material(R.ANY,'A',5);R:SetProtection(characterId,'apple',true,0);R:SetProtection(R.BANK,'apple',false,60)
generate({item('apple')},{item('apple',80,'bank')})
check(#R.data.plans==1 and R.data.plans[1].source==R.BANK and R.data.plans[1].qty==20,'Any respects each concrete source protection independently')
check(not R:SetProtection(R.ANY,'apple',true,0),'Any cannot create an ambiguous global source protection')
check(not R:Add({source=R.ANY,dest='A',link='apple',qty=1,mode='ask'}),'physical ledger refuses unresolved Any source')
check(not R:BuildRule({source=characterId,dest=R.ANY,link='apple',qty=1,mode='ask'}),'Any cannot be a destination')
reset();local broad=material(R.ANY,'A',5);local specific=material(characterId,'B',5)
generate({item('apple')})
check(#R.data.plans==1 and R.data.plans[1].dest=='B','named-source exception precedes older Any rule within the same group')
check(R:OrderedRules()[1]==specific and R.data.rules[1]==broad,'effective ordering does not reorder planner definitions')
local export=T:CaptureConfig();local prepared=assert(C:Prepare(export,C:Mappings(export)))
check(export.characters[R.ANY]==nil and prepared.rules[1].source==R.ANY and prepared.rules[1].mode=='ask'and not prepared.rules[1].enabled,'Any round-trips as selector with conservative import approval')

reset()
for _,link in ipairs({'style','rawstyle'})do
    check(F:SharedCategory(link)==8 and F:Related(link,8),'raw and refined style material match independent style category')
    for craft=1,7 do check(not F:Related(link,craft),'style never enters profession via direct type or recipe catalog')end
end
for _,link in ipairs({'armortrait','weapontrait','jeweltrait','rawtrait'})do
    check(F:SharedCategory(link)==9 and F:Related(link,9),'all trait families match independent trait category')
    for craft=1,7 do check(not F:Related(link,craft),'trait never enters profession category')end
end
check(not F:MatchesSource({craft=0,source=characterId},'style')and not F:MatchesSource({craft=0,source=characterId},'armortrait'),'all-profession clearing also excludes style and trait stock')
material(R.ANY,R.BANK,8);material(R.ANY,'A',9)
generate({item('style',30,'style'),item('armortrait',20,'trait')})
check(#R.data.plans==2 and R.data.plans[1].dest==R.BANK and R.data.plans[2].dest=='A','separate shared categories can use different named storage destinations')
check(not R:BuildRule({material=true,craft=8,scope='usable',source=R.ANY,dest='A'}),'style storage does not guess profession usability')
check(not R:BuildRule({material=true,craft=9,scope='all',source=R.ANY,dest='@best-crafter'}),'shared category cannot select an arbitrary best profession crafter')
reset();local old=material(characterId,'A',6)
local p=assert(R:Add({source=characterId,dest='A',link='style',uid='style',qty=10,mode='ask',rule=old.id}))
local ok,reason,code=M:Eligible(p)
check(not ok and code=='SHARED_CATEGORY_CHANGED','old unstarted profession blanket style delivery held with explicit reason')
p.state='bank';check(M:Eligible(p),'already banked delivery keeps its original destination and eligibility')
reset();old=material(characterId,'A',5)
assert(R:Add({source=characterId,dest='A',link='style',uid='style',qty=10,mode='ask',rule=old.id}))
generate({item('apple')})
check(#R.data.plans==2 and R.data.plans[2].link=='apple','obsolete unstarted shared-material hold does not stall unrelated profession stock')
reset();local one=assert(R:AddRule({source=characterId,dest='A',link='style',name='style',qty=1,maxStack=200,mode='ask'}))
p=assert(R:Add({source=characterId,dest='A',link='style',uid='style',qty=1,mode='ask',rule=one.id}))
check(M:Eligible(p),'explicit exact-item exception remains valid for shared material')

reset();R:SetProtection(characterId,'apple',true,20);R:SetProtection('A','apple',false,5);R:SetProtection(R.BANK,'style',true,0);R:SetProtection('B','noop',false,0)
check(#U:Entries()==3,'list shows effective blocks and keep reserves but hides no-op entries')
check(#U:Entries('A','APP')==1,'protection search and source filters compose')
U:Show();check(not U.window:IsHidden()and not U.rows[1].button:IsHidden(),'protected list opens without locating live item')
local entry=U:Entries(characterId)[1];U:Edit(entry);U.keep:SetText('bad');U:Save(false)
check(not U.editor:IsHidden()and R:Protection(characterId,'apple').keep==20,'invalid protection edits leave actual guard intact')
U.keep:SetText('7');U.blocked=false;U:Save(false)
check(R:Protection(characterId,'apple').keep==7 and not R:Protection(characterId,'apple').blocked,'editor can clear Never export while preserving a chosen keep reserve')
U:Edit(U:Entries(characterId)[1]);U:Save(true)
check(not R.data.protections[characterId]and R:Protection('A','apple').keep==5,'remove clears only selected source exact-item protection')
check(R:Protection(R.BANK,'style').blocked,'bank protection unaffected by character edit')
local last=GridBagsActivity.data.history[#GridBagsActivity.data.history]
check(last.code=='PROTECTION_REMOVED','protection removal recorded in local log')
R.pending={};check(not R:RemoveProtection('A','apple')and R:Protection('A','apple').keep==5,'in-flight item receipt prevents protection removal');R.pending=nil
U:Close();check(U.window:IsHidden()and U.editor:IsHidden(),'protection windows close together')

-- Exercise the unchanged executor with an Any definition through deposit and named pickup.
reset();rule=assert(R:AddRule({source=R.ANY,dest='A',link='apple',name='apple',qty=40,maxStack=200,mode='standing'}))
bags[BAG_BACKPACK][0]={id=1001,name='apple',qty=100,quality=2,filter=ITEMFILTERTYPE_CRAFTING}
local function apply()
    local request=requests[#requests];assert(request)
    local from,slot,to,target,qty=unpack(request);local original=bags[from][slot]
    local destination=bags[to][target]
    if destination then destination.qty=destination.qty+qty
    else destination={id=2001,name=original.name,qty=qty,quality=original.quality,filter=original.filter};bags[to][target]=destination end
    original.qty=original.qty-qty;if original.qty==0 then bags[from][slot]=nil end
    R:Observe()
end
R:Open();check(#requests==1 and R.data.plans[1].source==characterId,'Any rule executes through concrete source validation')
apply();p=R.data.plans[1]
check(p.state=='bank'and R:Reserved('apple')==40,'verified Any deposit reserves stock for named recipient')
R:Tick();check(#requests==1,'Any deposit cannot bounce or reuse stack during same opening')
R:Close();R.character='A';bags[BAG_BACKPACK]={};R:Open()
check(#requests==2 and R.pending.phase=='bank','recipient collects existing Any delivery rather than re-exporting own inventory')
apply();check(p.state=='done'and R:Reserved('apple')==0,'Any delivery completes only after observed pickup')
for _,kind in ipairs({'material','exact'})do
    reset()
    if kind=='material'then rule=material(R.ANY,'A',5)
    else rule=assert(R:AddRule({source=R.ANY,dest='A',link='apple',name='apple',qty=200,maxStack=200,mode='ask'}))end
    for visit,quantity in ipairs({10,20,30})do
        bags[BAG_BACKPACK][0]={id=1001,name='apple',qty=quantity,quality=2,filter=ITEMFILTERTYPE_CRAFTING}
        R:Open()
        check(#R.data.plans==visit,kind..' repeat adds only new farmed quantities despite pending pickups')
        check(#requests==visit-1 and R.current~=nil,kind..' fresh deposit still needs Ask approval')
        R:Confirm(false);apply();R:Tick()
        check(R:Reserved('apple')==visit*(visit+1)*5,kind..' all deposited batches retain correct independent reservations')
        check(#requests==visit,kind..' one physical deposit per bank opening')
        R:Close()
    end
    check(R.data.plans[1].qty==10 and R.data.plans[2].qty==20 and R.data.plans[3].qty==30,kind..' old transactions are not inflated or overwritten')
    R.character='A';bags[BAG_BACKPACK]={};R:Open()
    check(#R.data.plans==3 and R.pending and R.pending.qty==60,kind..' pickup aggregates reserved batches without allocating them again')
    apply();check(R:Reserved('apple')==0 and R.data.plans[3].state=='done',kind..' aggregate pickup settles every batch')
end
reset();rule=material(characterId,'A',5);rule.maxPerStack=20
generate({item('apple',10,'growing')});generate({item('apple',15,'growing')})
check(#R.data.plans==2 and R.data.plans[2].qty==5,'growing unstarted source stack contributes only newly unallocated units')
generate({item('apple',15,'growing')});check(#R.data.plans==2,'unchanged reevaluation cannot duplicate growing-stack allocations')
generate({item('apple',30,'growing')})
check(#R.data.plans==3 and R.data.plans[3].qty==5,'outstanding allocations preserve per-rule source-stack cap')
reset();rule=material(R.ANY,'A',5)
local uncertain=assert(R:Add({source=characterId,dest='A',link='apple',uid='held',qty=10,mode='ask',rule=rule.id}))
uncertain.state='review';uncertain.reserve=true
generate({item('berry',50,'fresh')})
check(#R.data.plans==2 and R.data.plans[2].link=='berry'and uncertain.state=='review','one uncertain item does not lock an entire profession or replay its hold')
reset();rule=material(R.ANY,'A',5)
local existing=assert(R:Add({source=characterId,dest='A',link='apple',uid='previous',qty=40,mode='ask',maxStack=200,rule=rule.id}))
existing.state='bank';existing.approved=true
generate({}, {item('apple',70,'bank')})
check(#R.data.plans==2 and R.data.plans[2].qty==30 and not R.data.plans[2].approved,'only genuinely unreserved bank stock becomes a new Ask transaction')

reset();local auditRule=material(R.ANY,'A',4)
check(R.data.ruleAudit[1].action=='CREATED'and R.data.ruleAudit[1].after.craft==4,'Alchemy creation recorded outside bounded transfer history')
assert(R:UpdateRule(auditRule.id,{material=true,craft=5,scope='all',source=R.ANY,dest='A',link='@materials',name='Provisioning',qty=200,mode='ask'}))
check(R.data.ruleAudit[2].before.craft==4 and R.data.ruleAudit[2].after.craft==5,'category edits preserve before and after evidence')
assert(R:DeleteRule(auditRule.id));check(R.data.ruleAudit[3].action=='DELETED'and R.data.ruleAudit[3].before.id==auditRule.id,'rule deletion remains traceable after planner removal')
check(R:RuleHistory():find('category 4',1,true)~=nil,'rule audit is readable through tools history')
local auditCount=#R.data.ruleAudit
check(not R:AddRule({material=true,craft=4,scope='all',source=R.ANY,dest='A',qty=0,mode='ask',link='@materials'})and #R.data.ruleAudit==auditCount,'failed saves do not masquerade as successful persisted rules')
for index=1,101 do material(R.ANY,'A',4)end
check(#R.data.ruleAudit==100 and #R.data.rules==101,'bounded rule history never prunes actual routing definitions')
reset();GridBagsCraftingUI:Edit();GridBagsCraftingUI.editing.craft=4;GridBagsCraftingUI.editing.source=R.ANY;GridBagsCraftingUI.editing.dest='A';GridBagsCraftingUI:Save()
check(#R.data.rules==1 and R.data.rules[1].craft==4 and G.saved.routing[GetWorldName()].rules[1]==R.data.rules[1],'Alchemy UI save updates the same account/world table ESO persists')
print('PASS: '..checks..' Any-source, style/trait separation, protection management and executor checks (Lua 5.1 mock).')
