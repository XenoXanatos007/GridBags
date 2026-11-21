local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local D,R,M,F,S,P,C,T=GridBagsGearRouting,GridBagsRouting,GridBagsSmartRouting,GridBagsCrafting,GridBagsSnapshots,GridBagsRoutingUI,GridBagsConfig,GridBagsTransferTools
local known,remaining={},{}
LibCharacterKnowledge={KNOWLEDGE_KNOWN=1,KNOWLEDGE_UNKNOWN=2,
    GetSmithingResearchFromItemLink=function(link)if link=='sword'or link=='duplicateSword'then return 1,2,3 end end,
    GetSmithingResearchStatusForCharacter=function(craft,line,trait,server,id)return known[id]or 3,remaining[id]end}
GetItemLinkCraftingSkillType=function(link)if link=='cloth'then return 2 elseif link=='glyph'then return 0 else return 1 end end
ITEMTYPE_GLYPH_ARMOR=9901
GetItemLinkItemType=function(link)return link=='glyph'and ITEMTYPE_GLYPH_ARMOR or 0 end
IsItemLinkForcedNotDeconstructable=function(link)return link=='questGear'end
CanItemBeDeconstructed=function(bag,slot,craft)local item=bags[bag][slot];return item and item.gear and not item.noDecon and craft~=4 end
GetItemLink=function(bag,slot)return bags[bag][slot]and bags[bag][slot].name or ''end
GetBagSize=function(bag)return bag==BAG_SUBSCRIBER_BANK and 0 or 6 end;GetBagUseableSize=GetBagSize
IsItemPlayerLocked=function(bag,slot)return bags[bag][slot]and bags[bag][slot].locked or false end
local forbidden=0
local function noAction()forbidden=forbidden+1;error('Must not consume items')end
PrepareDeconstructMessage=noAction;AddItemToDeconstructMessage=noAction;SendDeconstructMessage=noAction;ResearchSmithingTrait=noAction
local function data(rank,points)return {rank=rank,passivePoints=points,tier=1,at=timestamp}end
M.CaptureProfessions=function()return {[1]=data(15,3),[2]=data(15,3),[3]=data(15,3)}end
local function reset()
    R.pending=nil;R.current=nil;R:Close();P:Close();GridBagsGoldUI:Close()
    R.character=characterId;R.data={plans={},rules={},protections={},profiles={}};G.saved.routing[GetWorldName()]=R.data
    G.saved.transfersPaused=false;G.saved.enabled=true;G.sceneName='bank';G.selectedCharacter=nil;bankOpen=true;BMR=nil
    bags={[BAG_BACKPACK]={},[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={},[BAG_WORN]={}}
    S.records={};F.skillFrame=nil
    for _,id in ipairs({'A','B','C'})do
        S.records[id]={name=id,updatedAt=timestamp,items={},professions={[1]=data(30,5),[2]=data(30,5),[3]=data(30,5)}}
        R.data.profiles[id]={crafts={[1]={crafter=true,researcher=true,priority=10},[2]={crafter=true,researcher=true,priority=10},[3]={crafter=true,priority=10}}}
    end
    known={A=2,B=2,C=1};remaining={}
end
local function gear(name,id)return {id=id or 100,name=name or 'sword',qty=1,quality=2,filter=ITEMFILTERTYPE_WEAPONS,gear=true}end
local function spec(source,link,uid)return {source=source or characterId,dest='A',link=link or 'sword',uid=uid or '100',maxStack=1,qty=1,mode='ask'}end
reset();bags[BAG_BACKPACK][0]=gear()
local observed=D:Observe(BAG_BACKPACK,0,'sword')
check(observed.allowed and observed.craft==1,'native deconstruction eligibility observed without acting')
bags[BAG_BACKPACK][1]=gear('questGear',101)
check(not D:Observe(BAG_BACKPACK,1,'questGear').allowed,'forced nondeconstructable quest gear rejected')
bags[BAG_BACKPACK][2]=gear('glyph',102)
check(D:Observe(BAG_BACKPACK,2,'glyph').craft==3,'glyph type fallback still requires native eligibility')
bags[BAG_BACKPACK][0].noDecon=true
check(not D:Observe(BAG_BACKPACK,0,'sword').allowed,'native negative eligibility cannot be guessed positive')
bags[BAG_BACKPACK][0].noDecon=nil
S.records.A.professions[1]=data(30,20);S.records.B.professions[1]=data(40,3);S.records.C.professions[1]=data(40,6)
local entries=D:Choices(spec(),'deconstruct')
check(entries[1].id=='C'and entries[2].id=='B'and entries[3].id=='A','deconstruction prioritizes earned rank then passive investment')
S.records.B.professions[1]=data(40,6);R.data.profiles.B.crafts[1].priority=1
entries=D:Choices(spec(),'deconstruct');check(entries[1].id=='B','profile priority breaks equal rank/passive ties')
R.data.profiles.C.crafts[1].priority=1
entries=D:Choices(spec(),'deconstruct');check(entries[1].top and entries[2].top,'unresolved score tie is visible for explicit selection')
R.data.profiles.B.crafts[1].crafter=false
entries=D:Choices(spec(),'deconstruct');check(#entries==2 and entries[1].id=='C','deconstruction uses profession-specific Crafter role')
S.records.C.updatedAt=timestamp-8*86400
entries=D:Choices(spec(),'deconstruct');check(#entries==1 and entries[1].id=='A','stale candidate data excluded from ranking')
reset();bags[BAG_BACKPACK][0]=gear()
entries=D:Choices(spec(),'research');check(#entries==2,'research excludes characters who already know the trait')
S.records.B.professions[1]=data(40,3)
entries=D:Choices(spec(),'research');check(entries[1].id=='B','research uses earned rank before passive investment')
remaining.B=100
entries=D:Choices(spec(),'research');check(#entries==1 and entries[1].id=='A','trait already being researched excluded')
remaining.B=nil;S.records.B.items={{link='duplicateSword'}}
entries=D:Choices(spec(),'research');check(#entries==1 and entries[1].id=='A','recipient with same trait on another item is excluded')
S.records.B.items={}
local queued=assert(R:Add({source=R.BANK,dest='B',link='duplicateSword',uid='999',qty=1,maxStack=1,mode='ask'}))
entries=D:Choices(spec(),'research');check(#entries==1 and entries[1].id=='A','already planned research copy is excluded')
queued.state='cancelled';known.A=1;known.B=1
entries=D:Choices(spec(),'research');check(#entries==0,'all knowledgeable researchers produce no recipient')
entries=D:Choices(spec(characterId,'ornate'),'research');check(#entries==0,'ornate or nonresearchable item has no research recipient')
known.A=2;R.data.profiles.A.crafts[1].researcher=false
entries=D:Choices(spec(),'research');check(#entries==0,'general research role cannot override explicit profession opt-out')
R.data.profiles.A.crafts[1].researcher=true;known.A=3
local reason;entries,reason=D:Choices(spec(),'research')
check(#entries==0 and reason:find('missing/stale',1,true),'unknown provider data is not mistaken for an unknown trait')

reset();bags[BAG_BACKPACK][0]=gear()
P:Mark({key='Backpack'},{bag=BAG_BACKPACK,slot=0,identity='100'})
check(P.deconstructButton.enabled and P.researchButton.enabled,'marked live gear exposes both delivery-purpose buttons')
menuEntries={};P:GearRecipients(P.researchButton,'research')
check(menuEntries[1].name:lower():find('top',1,true)and menuEntries[1].name:find('rank',1,true),'research menu shows best verified rank/point evidence')
menuEntries[1].callback()
check(P.editing.smart.kind=='research'and P.editing.smart.profileResearch and P.quantity:GetText()=='1','research selection retains qualification and one-item quantity')
known.A=1;known.B=1;P:UpdateEditor()
check(not P.researchButton.enabled and P.researchButton.gridBagsHelp:find('No other designated researcher',1,true),'no eligible researcher greys button with explanation')
known.A=2;known.B=2;menuEntries={};P:GearRecipients(P.deconstructButton,'deconstruct');menuEntries[1].callback()
check(P.editing.smart.kind=='deconstruct'and P.editing.smart.craft==1,'deconstruction selection pins recipient and purpose')
local selected=P.editing.dest;P:Save('once')
local delivery=R.data.plans[#R.data.plans]
check(delivery.dest==selected and delivery.smart.kind=='deconstruct'and not delivery.approved,'saving deconstruction creates a normal unapproved delivery')
check(M:Eligible(delivery),'deconstruction delivery passes live native and recipient checks')
bags[BAG_BACKPACK][0].noDecon=true
local ok,_,code=M:Eligible(delivery)
check(not ok and code=='DECONSTRUCTION_UNAVAILABLE','deconstruction eligibility rechecked before moving')
bags[BAG_BACKPACK][0].noDecon=nil;R.data.profiles[selected].crafts[1].crafter=false
ok,_,code=M:Eligible(delivery);check(not ok and code=='PROFILE_NOT_ASSIGNED','removed recipient role blocks previously selected deconstruction route')

reset();bags[BAG_BACKPACK][0]=gear()
delivery=assert(R:Add({source=characterId,dest='A',link='sword',uid='100',qty=1,maxStack=1,mode='ask',smart={kind='research',craft=1,profileResearch=true}}))
check(M:Eligible(delivery),'own planned research delivery not mistaken for duplicate')
known.A=1;ok,_,code=M:Eligible(delivery);check(not ok and code=='ALREADY_KNOWN','recipient learning trait before pickup blocks research delivery')
known.A=2;R.data.profiles.A.crafts[1].researcher=false
ok,_,code=M:Eligible(delivery);check(not ok and code=='PROFILE_NOT_ASSIGNED','research role rechecked at transfer')
R.data.profiles.A.crafts[1].researcher=true;remaining.A=100
ok,_,code=M:Eligible(delivery);check(not ok and code=='RESEARCH_IN_PROGRESS','research-in-progress rechecked at transfer')

reset();S.ready=true;bags[BAG_BACKPACK][0]=gear();S:Capture()
check(S.records[characterId].items[1].deconstruction.allowed,'snapshots capture item-specific deconstruction eligibility')
local offline='Offline';S.records[offline]=T:Clone(S.records[characterId]);S.records[offline].name=offline
entries=D:Choices(spec(offline),'deconstruct');check(#entries==3,'fresh offline deconstruction evidence supports planning')
S.records[offline].items[1].deconstruction=nil
entries,reason=D:Choices(spec(offline),'deconstruct');check(#entries==0 and reason:find('Refresh',1,true),'old snapshots grey deconstruction until refreshed')
S.records[offline].items[1].deconstruction=observed;S.records[offline].updatedAt=timestamp-8*86400
entries=D:Choices(spec(offline),'deconstruct');check(#entries==0,'stale source snapshot cannot authorize deconstruction routing')
local provider=LibCharacterKnowledge;LibCharacterKnowledge=nil
entries,reason=D:Choices(spec(),'research');check(#entries==0 and reason:find('Character Knowledge',1,true),'missing knowledge provider disables research with explanation');LibCharacterKnowledge=provider

reset()
assert(R:AddRule({source=R.ANY,dest='A',link='sword',name='sword',qty=1,mode='standing',maxStack=1,smart={kind='deconstruct',craft=1}}))
assert(R:AddRule({source=R.ANY,dest='B',link='sword',name='sword',qty=1,mode='ask',maxStack=1,smart={kind='research',craft=1,profileResearch=true}}))
local config=T:CaptureConfig();local decoded=assert(C:Decode(assert(C:Encode(config))))
local prepared=assert(C:Prepare(decoded,C:Mappings(decoded)))
check(prepared.rules[1].smart.kind=='deconstruct'and not prepared.rules[1].enabled and prepared.rules[1].mode=='ask','deconstruction condition survives import without automatic approval')
check(prepared.rules[2].smart.profileResearch and prepared.rules[2].smart.craft==1,'research profile condition survives import')
decoded.rules[1].smart.craft=4;check(not C:Prepare(decoded,C:Mappings(decoded)),'invalid deconstruction profession rejected during import')
decoded.rules[1].smart.craft=1;decoded.rules[2].smart.craft=3
check(not C:Prepare(decoded,C:Mappings(decoded)),'enchanting cannot masquerade as trait research')
check(forbidden==0,'helpers never invoke research or deconstruction actions')
print('PASS: '..checks..' gear-purpose, ranking, knowledge, snapshot, disabled-control and import checks (Lua 5.1 mock).')
