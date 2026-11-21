local checks=0
local function check(v,label)assert(v,label);checks=checks+1 end
local R,Gold,A,T,C,U=GridBagsRouting,GridBagsGold,GridBagsActivity,GridBagsTransferTools,GridBagsConfig,GridBagsToolsUI
local requests,money,sizes,uid={}, {}, {}, 1000
GetBagSize=function(bag)return sizes[bag]or 6 end
GetBagUseableSize=GetBagSize
GetItemLink=function(bag,slot)return bags[bag][slot]and bags[bag][slot].variant or ""end
GetSlotStackSize=function(bag,slot)local i=bags[bag][slot];return i and i.qty or 0,i and i.maximum or 200 end
IsItemPlayerLocked=function(bag,slot)return bags[bag][slot]and bags[bag][slot].locked or false end
CallSecureProtected=function(_,...)requests[#requests+1]={...};return true end
TransferCurrency=function(_,amount,from,to)money[#money+1]={amount,from,to}end
GetMaxCurrencyTransfer=function()return 1000000000 end
GetUnitName=function()return "Private Hero"end
local function item(name,quantity)
 uid=uid+1;return{name=name,variant=name,id=uid,qty=quantity,quality=2,maximum=200,filter=ITEMFILTERTYPE_CRAFTING}
end
local function reset()
 R.pending=nil;R.current=nil;R.confirmAll=false
 R.data={plans={},rules={},protections={},profiles={}}
 G.saved.routing[GetWorldName()]=R.data
 Gold.pending=nil;Gold.current=nil;Gold.data={profiles={},daily={},holds={},history={},bankReserve=0}
 G.saved.goldRouting[GetWorldName()]=Gold.data
 A.data={history={},errors={},backups={}};A.previewDepth=0;G.saved.transferTools[GetWorldName()]=A.data;G.saved.transfersPaused=false
 GridBagsRoutingUI:Close();GridBagsGoldUI:Close();U:Close()
 bags={[BAG_BACKPACK]={},[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={},[BAG_WORN]={}}
 sizes={[BAG_BACKPACK]=6,[BAG_BANK]=6,[BAG_SUBSCRIBER_BANK]=0,[BAG_WORN]=6}
 GridBagsSnapshots.records={A={name="Secret Crafter",items={},updatedAt=timestamp,capacity=20,used=0},B={name="Other Target",items={},updatedAt=timestamp,capacity=20,used=0}}
 G.saved.bankSnapshots[GetWorldName()]=nil
 G.selectedCharacter=characterId;G.equipmentView=false
 bankOpen=true;G.sceneName="bank";G.saved.enabled=true;G.saved.externalFilters=false
 mockCharacterGold=30000;mockBankGold=100000
 requests={};money={};BMR=nil
 CallSecureProtected=function(_,...)requests[#requests+1]={...};return true end
end
local function plan(source,dest,stack,qty,mode,rule)
 return assert(R:Add({source=source,dest=dest,link=stack.variant,name=stack.name,uid=tostring(stack.id),available=stack.qty,
  maxStack=stack.maximum,qty=qty,mode=mode or"ask",rule=rule,observedAt=timestamp-3600}))
end
local function apply()
 local q=assert(requests[#requests]);local from,slot,to,target,quantity=unpack(q)
 local old=bags[from][slot];local dest=bags[to][target]
 if dest then dest.qty=dest.qty+quantity else dest={};for k,v in pairs(old)do dest[k]=v end;uid=uid+1;dest.id=uid;dest.qty=quantity;bags[to][target]=dest end
 old.qty=old.qty-quantity;if old.qty==0 then bags[from][slot]=nil end
 R:Observe()
end
local function last()return A.data.history[#A.data.history]end

reset();local s=item("Private Ore",100);bags[BAG_BACKPACK][0]=s;sizes[BAG_BANK]=0
local p=plan(characterId,"A",s,20,"advance");R:Open()
check(last().code=="BANK_FULL"and last().reason:find("Bank is full",1,true),"bank-full skip has a concrete reason code")
check(last().outcome=="skipped"and #requests==0 and p.state=="source","full bank is not recorded as a successful request")
reset();s=item("ore",100);bags[BAG_BANK][0]=s;sizes[BAG_BACKPACK]=0
p=plan(R.BANK,characterId,s,20,"advance");R:Open()
check(last().code=="INVENTORY_FULL"and last().reason:find("Inventory is full",1,true),"inventory-full withdrawal separately identified")
reset();s=item("ore",100);p=plan(characterId,"A",s,20);R:Open()
check(last().code=="ITEM_MISSING"and last().outcome=="waiting"and last().observedAt==timestamp-3600,"missing planned item logs its observation evidence")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;p=plan(characterId,"A",s,20);R:Open();bags[BAG_BACKPACK][0]=item("ore",100);R:Confirm(false)
check(last().code=="SOURCE_CHANGED"and #requests==0,"changed physical identity logged before request")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;p=plan(characterId,"A",s,20,"advance");s.qty=80;R:Open()
check(last().code=="STALE_SNAPSHOT","shrunken observation distinguished from a missing item")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;p=plan(characterId,"A",s,50);s.qty=30;R:Open()
check(last().code=="QUANTITY_CHANGED_OR_FRAGMENTED","insufficient observed quantity has a reason")
reset();s=item("ore",100);s.locked=true;bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20);R:Open()
check(last().code=="ITEM_LOCKED","source lock has a specific reason")
reset();assert(R:AddRule({source=characterId,dest="A",link="ore",name="ore",qty=20,maxStack=200,mode="ask"}));R:Open()
check(last().kind=="rule"and last().reason:find("No matching item",1,true),"recurring rule with no match explains why it made no batch")
local rulePreview=assert(T:Preview());check(#rulePreview.rows==1 and rulePreview.rows[1].state=="waiting","preview includes rules that produced no operation")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20,"advance");R:Open()
check(last().outcome=="requested"and last().code=="REQUESTED","request recorded before its outcome")
apply();check(last().outcome=="success"and last().code=="VERIFIED_MOVE","observed success is logged")
check(last().source==characterId and last().destination==R.BANK and last().allocations[1].destination=="A","physical and planned recipient recorded separately")
check(last().observedSourceCount==80 and last().observedDestinationCount==20,"receipt counts available in detail")
local count=#A.data.history;R:Tick();R:Open();check(#A.data.history==count,"completed visit reload does not duplicate receipts")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20,"advance")
local update=U.Update;U.Update=function()error("GridBags/ToolsUI.lua:1 fixture display error")end
R:Open();apply();U.Update=update
check(#requests==1 and last().code=="VERIFIED_MOVE"and A.data.uiProblem,"history rendering error cannot interrupt authorized transfer verification")

reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20,"advance");R:Open();s.qty=80;timestamp=timestamp+5;R:Observe()
check(last().code=="TIMEOUT_UNCERTAIN"and last().outcome=="review","timeout does not falsely declare a definite failure")
check(last().reason:find("timed out",1,true)and last().observedDestinationCount==0,"timeout reason and partial evidence retained")
count=#A.data.history;R:Tick();check(#requests==1 and #A.data.history==count,"timeout does not retry or spam history")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20,"advance")
CallSecureProtected=function()return false end;R:Open()
check(last().code=="REQUEST_REJECTED"and last().outcome=="review","game rejection distinguished from timeout")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20,"advance");R:Open();R:Close()
check(last().code=="BANK_CLOSED_UNCERTAIN","bank closure during pending operation logged")
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20);R:Open();R:Skip(true)
check(last().code=="USER_SKIP"and last().outcome=="skipped","user skip differentiated from errors")

reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;local s2=item("wood",100);bags[BAG_BACKPACK][1]=s2
plan(characterId,"A",s,20,"advance");plan(characterId,"B",s2,20,"advance");R:Open();A:SetPaused(true);apply();R:Tick()
check(#requests==1 and last().outcome=="success"and A:IsPaused(),"pause lets in-flight receipt settle and prevents next item")
A:SetPaused(false);R:Tick();check(#requests==2,"resume continues eligible frozen work without replay")
apply()
reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;plan(characterId,"A",s,20);R:Open();A:SetPaused(true);R:Confirm(true)
check(#requests==0 and GridBagsRoutingUI.confirmWindow:IsHidden(),"global pause blocks even an old confirmation callback")
A:SetPaused(false);check(not GridBagsRoutingUI.confirmWindow:IsHidden(),"resume restores the pending confirmation")
reset();assert(Gold:SaveProfile(characterId,{enabled=true,min=10000,max=20000,fixed=0,threshold=0,cap=0,resetHour=0,frequency="visit",mode="standing"},0))
A:SetPaused(true);Gold:Open();check(#money==0,"global pause also blocks gold")
A:SetPaused(false);Gold:Tick();check(#money==1,"gold resumes under its own approval")
mockCharacterGold=20000;mockBankGold=110000;Gold:Observe()
check(last().kind=="gold"and last().code=="GOLD_VERIFIED","gold receipt appears in unified history")
reset();assert(Gold:SaveProfile(characterId,{enabled=true,min=0,max="",fixed=1000,threshold=40000,cap=0,resetHour=0,frequency="visit",mode="standing"},0));Gold:Open()
check(last().code=="GOLD_BELOW_THRESHOLD"and #money==0,"scheduled gold skip gives its specific threshold reason")

reset();s=item("ore",100);bags[BAG_BACKPACK][0]=s;p=plan(characterId,"A",s,20,"advance")
local original=R.data;local before=assert(C:Encode(R.data));local historyCount=#A.data.history
local preview=assert(T:Preview())
check(preview.live and preview.rows[1].state=="eligible now","live preview evaluates eligible next-visit work")
check(R.data==original and assert(C:Encode(R.data))==before and #A.data.history==historyCount,"preview restores all planning/approval state and emits no fake logs")
check(#requests==0 and #money==0,"preview invokes no transfer API")
local originalScan=R.Scan;R.Scan=function()error("preview fixture failure")end
local failedPreview=T:Preview();R.Scan=originalScan
check(not failedPreview and R.data==original and A.previewDepth==0 and assert(C:Encode(R.data))==before,"preview exception restores the owning state and log suppression")
bankOpen=false;G.sceneName="inventory"
G.saved.bankSnapshots[GetWorldName()]={items={},updatedAt=timestamp-7200,name="Account bank",capacity=10,used=0}
preview=assert(T:Preview())
check(not preview.live and preview.rows[1].state=="tentative"and preview.note:find("120 min",1,true),"away-bank preview labels saved age and unknown capacity")
G.saved.bankSnapshots[GetWorldName()]=nil
R.data.plans={};s=item("ore",100);p=plan(R.BANK,characterId,s,20)
preview=assert(T:Preview());check(preview.rows[1].code=="BANK_NOT_OBSERVED"and preview.rows[1].state=="unknown","no snapshot is unknown rather than a fake stock failure")
R.pending={};check(not T:Preview(),"preview waits for current receipt");R.pending=nil

reset()
GridBagsSnapshots.records[characterId]={name="Private Hero",items={{name="Secret Inventory Item",link="private-link"}},updatedAt=timestamp}
GetAPIVersion=function()return 101051 end
GetAddOnManager=function()return{GetNumAddOns=function()return 2 end,
 GetAddOnInfo=function(_,i)return i==1 and"GridBags"or"UnrelatedAddon","title","author","description",true end,
 GetAddOnVersion=function()return 13 end}end
A:Append({kind="item",outcome="skipped",code="ITEM_MISSING",reason="Private Hero missing Secret Inventory Item",item="Secret Inventory Item",source=characterId,destination="A"})
EVENT_MANAGER.events.GridBagsActivity[EVENT_LUA_ERROR](nil,"Private Hero Secret Inventory Item |H1:item:123|hSecret|h nil value user:/AddOns/GridBags/Routing.lua:42")
local report=T:Report()
check(report:find("ITEM_MISSING",1,true)and report:find("GridBags/Routing.lua:42",1,true),"report contains useful failure code and safe frame")
check(not report:find("Private Hero",1,true)and not report:find("Secret Inventory Item",1,true)and not report:find(characterId,1,true)and not report:find("|H",1,true),"report omits private error/item/character data")
check(report:find("101051",1,true)and report:find("GridBags: 13",1,true),"report includes API and relevant addon version")
A:Append({kind="Private Hero",outcome="Secret Inventory Item",code="Private Hero",reason="private"})
report=T:Report();check(not report:find("Private Hero",1,true)and not report:find("Secret Inventory Item",1,true),"unclassified diagnostic fields cannot bypass privacy filtering")
for _=1,350 do A:Append({kind="control",outcome="control",code="PAUSED",reason="test"})end
check(#A.data.history==300,"history bounded to latest 300 events")

reset();s=item("Private Ore",100);bags[BAG_BACKPACK][0]=s
local rule=assert(R:AddRule({source=characterId,dest="A",link="Private Ore",name="Private Ore",qty=20,maxStack=200,mode="standing"}))
local sourcePlan=plan(characterId,"A",s,20,"ask",rule.id)
local reserved=plan(R.BANK,"A",s,10,"ask",rule.id)
R.data.profiles.A={learner=true,priority=1};R:SetProtection(characterId,"Private Ore",true,10)
assert(Gold:SaveProfile(characterId,{enabled=true,min=1000,max=10000,fixed=0,threshold=0,cap=0,resetHour=0,frequency="visit",mode="standing"},777))
local config=T:CaptureConfig();local export=assert(C:Encode(config));local decoded=assert(C:Decode(export))
check(export:sub(1,4)=="GB1:"and decoded.rules[1].link=="Private Ore"and decoded.characters.A=="Secret Crafter","data-only configuration round-trips")
check(decoded.plans==nil and decoded.snapshots==nil and decoded.history==nil and decoded.rules[1].uid==nil,"config excludes live plans, custody and snapshots")
check(not C:Decode(export:sub(1,-2)..(export:sub(-1)=="0"and"1"or"0")),"checksum catches a damaged export")
_G.importExecuted=false;check(not C:Decode("return (_G.importExecuted=true)" )and not _G.importExecuted,"import never runs pasted Lua")
local mapping=C:Mappings(decoded);local prepared=assert(C:Prepare(decoded,mapping))
check(prepared.rules[1].mode=="ask"and not prepared.rules[1].enabled and not prepared.gold[characterId].enabled,"import preview downgrades automation to disabled/Ask")
local wrapped=export:gsub("(."..string.rep(".",39)..")","%1\n")
check(C:Decode(wrapped)~=nil,"line-wrapped copy retains configuration data")
local deep={schema=1};local node=deep;for _=1,14 do node.child={};node=node.child end
check(not C:Encode(deep),"overdeep export is refused rather than recursively overflowing")
local function transport(raw)
 local x,y=1,0;for i=1,#raw do x=(x+raw:byte(i))%65521;y=(y+x)%65521 end
 return"GB1:"..raw:gsub(".",function(ch)return string.format("%02x",ch:byte())end)..":"..string.format("%.0f",y*65536+x)
end
check(not C:Decode(transport("T2:S6:schemaN1;S6:schemaN1;")),"duplicate keys rejected even with valid checksum")
check(not C:Decode(transport(string.rep("T1:S1:x",14).."B1")),"import depth bounded independently of encoder")
check(not C:Decode(transport("T999999999:")),"hostile table count rejected before allocation")
local meta=assert(C:Decode(assert(C:Encode({schema=1,__index="inert"}))))
check(getmetatable(meta)==nil and meta.__index=="inert","imported keys never become executable metatables")
local bad=T:Clone(decoded);bad.view.size=999;local ruleId=rule.id;local backupCount=#A.data.backups
check(not C:Apply(bad,mapping)and R:Rule(ruleId)and #A.data.backups==backupCount and not A:IsPaused(),"invalid import leaves live config and pause untouched")
Gold.pending={};check(not C:Apply(decoded,mapping)and #A.data.backups==backupCount and R:Rule(ruleId),"import cannot replace configuration during an in-flight receipt");Gold.pending=nil
R:SetProtection(characterId,"Private Ore",true,30);Gold.data.bankReserve=999;Gold:Profile(characterId).min=2000
local result=assert(C:Apply(decoded,mapping))
check(A:IsPaused()and #R.data.rules==1 and not R.data.rules[1].enabled and R.data.rules[1].mode=="ask","apply pauses globally and leaves repeat rule disabled")
check(sourcePlan.state=="cancelled"and reserved.state=="bank"and reserved.rule==nil and reserved.dest=="A","import cancels old source batches but preserves bank custody/destination")
check(R:Protection(characterId,"Private Ore").keep==30 and Gold.data.bankReserve==999,"import cannot weaken existing source or bank reserves")
check(Gold:Profile(characterId).min==2000,"import preserves a stronger carried-gold minimum")
check(not Gold:Profile(characterId).enabled and Gold:Profile(characterId).mode=="ask","gold approvals are not silently restored")
check(#A.data.backups==1 and #requests==0 and #money==0,"recovery backup made before import, with no moves")
local malicious=T:Clone(decoded);malicious.rules[1].name="'); _G.importExecuted=true --"
local transported=assert(C:Decode(assert(C:Encode(malicious))))
check(C:Prepare(transported,mapping)and not _G.importExecuted,"code-looking strings remain inert data")
local foreign={schema=1,world="Other world",characters={x="Foreign Source",y="Foreign Target"},
 rules={{source="x",dest="y",link="ore",name="ore",qty=1,maxStack=200,mode="ask"}},roles={},protections={},gold={},view={},bankReserve=0}
check(not C:Prepare(foreign,{}),"foreign characters require mapping")
check(C:Prepare(foreign,{x=characterId,y="A"}).rules[1].dest=="A","explicit character mapping applied to routes")
check(not C:Prepare(foreign,{x=characterId,y=characterId}),"ambiguous many-to-one mapping rejected")
check(C:Prepare(foreign,{x=characterId,y="@skip"}).skipped==1,"skipping a character drops related imported rules")
for _=1,7 do T:Backup()end;check(#A.data.backups==5,"local recovery backups bounded to five")

U:Show("history");U:Text("Import",export,"import");U:ImportPreview(true)
check(U.prepared and U.importPayload,"import UI previews validated data before enabling apply")
U.edit:TakeFocus();U.edit:SelectAll();U:Close();check(not U.edit.focused,"copy/import textbox releases keyboard focus")
U:Text("Import",export,"import");U:ImportPreview(true);U.edit:SetText(export.."bad");U.edit.handlers.OnTextChanged()
check(not U.prepared and not U.importPayload,"editing imported text invalidates staged approval")
U:Show("preview");check(U.mode=="preview"and not U.window:IsHidden(),"preview reachable through visible tools screen")
local errorText='user:/AddOns/GridBags/Routing.lua:87: nil value\n'..string.rep('x',4000)..'\nuser:/AddOns/GridBags/RecipeGather.lua:120'
EVENT_MANAGER.events.GridBagsActivity[EVENT_LUA_ERROR](EVENT_LUA_ERROR,errorText)
local savedError=A.data.errors[#A.data.errors];local restored=savedError.text
check(#restored<2000,'error header fits ESO saved-string limit')
for _,part in ipairs(savedError.continuation)do check(#part<2000,'error continuation fits ESO saved-string limit');restored=restored..part end
check(restored==errorText,'full captured error survives chunk reassembly')
A.data.errors[#A.data.errors+1]={at=1} -- pre-fix records lost their oversized text during ESO serialization
local diagnostic=T:Report()
check(diagnostic:find('GridBags/RecipeGather.lua:120',1,true)and diagnostic:find('GridBags/Routing.lua:87',1,true),'report reads late frames and tolerates old missing error text')
print("PASS: "..checks.." failure logging, pause, preview, diagnostics and configuration checks (Lua 5.1 mock).")
