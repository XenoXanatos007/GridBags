local checks=0
local function check(v,message)assert(v,message);checks=checks+1 end
local R,I,U,H,T,C=GridBagsRouting,GridBagsRoutingInsights,GridBagsDeliveryUI,GridBagsHelp,GridBagsTransferTools,GridBagsConfig
local calls=0;CallSecureProtected=function()calls=calls+1 end
R.data={plans={},rules={},profiles={},protections={}};G.saved.routing[GetWorldName()]=R.data
R.character=characterId;bankOpen=false;G.sceneName='inventory';G.saved.transfersPaused=false
GridBagsSnapshots.records.A={name='Crafter A',updatedAt=timestamp,items={}}
GridBagsSnapshots.records.B={name='Crafter B',updatedAt=timestamp,items={}}
local function plan(source,dest,name,state)
    local p=assert(R:Add({source=source,dest=dest,link=name,name=name,qty=10,uid=name,maxStack=200,mode='ask'}))
    p.state=state or p.state;return p
end
local source=plan(characterId,'A','ore','source')
local bank=plan('B','A','wood','bank')
local review=plan(characterId,'B','recipe','review');review.reason='Bank is full';review.reasonCode='BANK_FULL'
local done=plan(characterId,R.BANK,'Herbs','done')
local cancelled=plan('A','B','old item','cancelled')
local before=assert(C:Encode(R.data))
local rows,counts=I:Deliveries()
check(#rows==5 and counts.source==1 and counts.bank==1 and counts.review==1 and counts.done==1 and counts.cancelled==1,'delivery stages counted independently')
check(rows[1]==cancelled,'newest delivery records first')
rows=I:Deliveries({character='A'});check(#rows==3,'character filter includes both source and destination')
rows=I:Deliveries({query='HERBS'});check(#rows==1 and rows[1]==done,'item search case-insensitive and completed records searchable')
rows=I:Deliveries({query='[ore]'});check(#rows==0,'item query treated literally rather than as a Lua pattern')
rows=I:Deliveries({character='A',state='bank',query='WOOD'});check(#rows==1 and rows[1]==bank,'filters compose')
check(I:Reason(bank):find('Reserved',1,true)and I:Reason(bank):find('Crafter A',1,true),'banked status explains named pickup')
check(I:Reason(review)=='Bank is full','recorded failure retained')
check(I:Reason(done):find('deposit verified',1,true),'completed bank storage distinguished from recipient pickup')
check(I:DeliveryDetails(done):find('Units awaiting delivery: 0',1,true),'completed storage displays zero outstanding despite retained ledger quantity')
check(I:DeliveryDetails(review):find('not proof that nothing moved',1,true),'uncertain outcome details do not suggest blind replay')
check(I:DeliveryDetails(cancelled):find('repeat rule may still',1,true),'cancelled batch explains repeat-rule distinction')
check(assert(C:Encode(R.data))==before and calls==0,'delivery inspection does not mutate data or issue requests')
R.pending={allocations={{plan=source.id}}}
check(I:Reason(source):find('Transfer requested',1,true),'in-flight transfer shown as unverified')
R.pending=nil
local op={status='queued',allocations={{plan=source.id}}};R.current=op;R.data.visit={open=true,queue={op}}
check(I:Reason(source):find('Awaiting your confirmation',1,true),'active confirmation distinct from waiting for bank visit')
op.status='skipped';op.reason='Skipped by player';R.current=nil
check(I:Reason(source):find('Skipped this bank opening',1,true),'skips remain visible during current opening')
R.data.visit=nil

local function rule(extra)
    local spec={source=characterId,dest='A',link='ore',name='Ore route',qty=20,maxStack=200,mode='ask'}
    for k,v in pairs(extra or {})do spec[k]=v end
    return assert(R:AddRule(spec))
end
local overflow=rule({source=R.BANK,overflow=true,overflowStacks=3})
local clearing=rule({material=true,craft=0,scope='all'})
local storage=rule({material=true,craft=1,scope='all'})
local usable=rule({material=true,craft=1,scope='usable'})
local known=rule({material=true,craft=5,scope='known'})
local exact=rule()
local learning=rule({dest='@learners',strategy='recipe',qty=1})
local other=rule({dest='B',name='Other ore route'})
local order=R:OrderedRules()
check(order[1]==learning and order[2]==exact and order[3]==other and order[4]==known and order[5]==usable and order[6]==storage and order[7]==clearing and order[8]==overflow,'explanations use actual engine processing order')
check(R.data.rules[1]==overflow,'sorting for explanation preserves planner list order')
bags[BAG_BACKPACK][0]={id=230,name='ore',qty=100,quality=2,filter=ITEMFILTERTYPE_CRAFTING}
GetItemLink=function(bag,slot)return bags[bag][slot]and bags[bag][slot].name or ''end
GetBagSize=function(bag)return bag==BAG_SUBSCRIBER_BANK and 0 or 2 end
GetBagUseableSize=GetBagSize
source.uid='230';source.available=100
before=assert(C:Encode(R.data));local history=#GridBagsActivity.data.history
local text=I:ExplainRule(exact)
check(text:find('Specific items',1,true)and text:find('named sources precede Any',1,true),'explanation describes effective priorities and tie order')
check(text:find('Other ore route also matches ore',1,true),'observed overlap explains competing rule and item')
check(text:find('does not automatically win',1,true),'overlap does not falsely guarantee allocation')
check(text:find('Read-only next-visit',1,true),'explanation includes preview output')
check(assert(C:Encode(R.data))==before and #GridBagsActivity.data.history==history and calls==0,'explanations and preview preserve plans, budgets, activity and transfer requests')
other.enabled=false;text=I:ExplainRule(exact)
check(not text:find('Other ore route also matches',1,true),'paused rules excluded from active overlap examples')
R.pending={allocations={{plan=source.id}}};text=I:ExplainRule(exact)
check(text:find('current transfer receipt',1,true),'in-flight preview blocked with explicit reason')
R.pending=nil
check(I:ExplainRule({id=-1}):find('no longer exists',1,true),'deleted rule explanation fails safely')
source.rule=exact.id
check(I:DeliveryDetails(source):find('Rule 6',1,true),'delivery refers to current compact rule label rather than historic global ID')

U:Show();check(not U.window:IsHidden(),'delivery screen opens')
U.search:SetText('recipe');U:Update()
check(not U.rows[1].button:IsHidden()and U.rows[1].label:GetText():find('Bank is full',1,true),'filtered UI presents actual failure reason')
U.search:SetText('no matches');U:Update();check(U.rows[1].button:IsHidden(),'empty filter removes stale rows')
U.search:SetText('');U:Update();U.rows[1].button:GetHandler('OnClicked')()
check(U.window:IsHidden()and not GridBagsToolsUI.textWindow:IsHidden(),'delivery detail uses existing readable text viewer')
GridBagsToolsUI:Close();U:Show();G.saved.enabled=false;G:Refresh()
check(U.window:IsHidden(),'overview follows inventory close without taking keyboard control')
G.saved.enabled=true

InformationTooltip={AddLine=function(self,text)self.text=text end}
SetTooltipText=function(tip,text)tip.text=text end
local control=WINDOW_MANAGER:CreateControl(nil,GuiRoot,CT_CONTROL)
local entered,left,clicked=0,0,0
local click=function()clicked=clicked+1 end
control:SetHandler('OnMouseEnter',function()entered=entered+1 end)
control:SetHandler('OnMouseExit',function()left=left+1 end)
control:SetHandler('OnClicked',click)
H:Bind(control,'First explanation');control:GetHandler('OnMouseEnter')(control)
check(entered==1 and InformationTooltip.text=='First explanation','tooltip retains native hover appearance handler and supplies text')
check(control:GetHandler('OnClicked')==click and not control.keyboardEnabled,'help does not replace click actions or capture keyboard')
H:Bind(control,'Updated explanation');control:GetHandler('OnMouseEnter')(control)
check(entered==2 and InformationTooltip.text=='Updated explanation','rebinding updates content without stacking wrappers')
control:GetHandler('OnMouseExit')(control)
check(left==1 and InformationTooltip.hidden,'tooltip clears and previous exit handler still runs')
check(GridBagsCraftingUI.scope.gridBagsHelp:find('Known requires',1,true),'blanket scopes explain eligibility')
check(GridBagsRoutingUI.quantity.gridBagsHelp:find('Maximum units',1,true),'numeric planner fields have mouseover help')
check(GridBagsGoldUI.edits.bankReserve.gridBagsHelp:find('manual native',1,true),'gold reserve tooltip states exact scope')
check(H.text['Confirm all']:find('does not turn',1,true),'confirmation tooltip explains limited approval scope')
check(calls==0,'all insights and tooltip interactions remained read-only')
print('PASS: '..checks..' read-only delivery, rule explanation, overlap and tooltip checks (Lua 5.1 mock).')
