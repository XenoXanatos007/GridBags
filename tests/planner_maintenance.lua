local checks=0
local function check(v,label) assert(v,label);checks=checks+1 end
local R,U,S=GridBagsRouting,GridBagsRoutingUI,GridBagsSnapshots
G.sceneName="inventory";G.saved.externalFilters=false;G.saved.enabled=true
S.records.A={name="A",items={},updatedAt=timestamp,used=0,capacity=10}
S.records.B={name="B",items={},updatedAt=timestamp,used=0,capacity=10}
R.data={plans={},rules={},protections={},profiles={},nextId=4}
local function spec(link)
 return {source=characterId,dest="A",link=link or "ore",name=link or "ore",qty=2,mode="ask",maxStack=200}
end
local a=assert(R:AddRule(spec()));local b=assert(R:AddRule(spec()));local c=assert(R:AddRule(spec()))
U:Update(R)
check(a.id==5 and U.rows[1].button.text=="Rule 1" and U.rows[3].button.text=="Rule 3","display numbering is compact despite existing internal IDs")
assert(R:DeleteRule(b.id));U:Update(R)
check(#R.data.rules==2 and U.rows[2].button.text=="Rule 2" and c.id==7,"deletion renumbers display without breaking stable identities")
local source=assert(R:Add({source=characterId,dest="A",link="ore",qty=1,uid="100",available=2,maxStack=200,mode="ask",rule=a.id}))
local bank=assert(R:Add({source=R.BANK,dest="A",link="ore",qty=1,uid="101",maxStack=200,mode="standing",rule=a.id}))
local op={status="queued",allocations={{plan=source.id,qty=1},{plan=bank.id,qty=1}}}
R.data.visit={queue={op},open=true};R.current=op
assert(R:DeleteRule(a.id))
check(source.state=="cancelled","delete cancels an unstarted generated batch")
check(bank.state=="bank" and bank.rule==nil and bank.mode=="ask" and not bank.approved,"delete preserves existing bank delivery with fresh approval required")
check(R:Reserved("ore")==1 and op.status=="skipped" and R.current==nil,"delete retains custody reservation and invalidates frozen queue")
local before=R.data.nextId
local updated=assert(R:UpdateRule(c.id,{source="A",dest="B",link="wood",name="wood",qty=5,maxStack=200,mode="limited",units=10,moves=2,enabled=false}))
check(updated.id==7 and R.data.nextId==before and #R.data.rules==1,"editing neither renumbers stable identity nor creates another rule")
check(updated.source=="A" and updated.dest=="B" and updated.link=="wood" and updated.maxPerStack==5,"full edit changes source, recipient, item and amount")
check(updated.unitsLeft==10 and updated.movesLeft==2 and not updated.enabled,"full edit changes allowance and enabled state")
check(not R:UpdateRule(7,{source="A",dest="B",link="bad",qty=-1,mode="ask"}),"invalid update rejected")
check(updated.link=="wood" and updated.unitsLeft==10,"invalid edit leaves original rule intact")
R.pending={}
check(not R:DeleteRule(7) and not R:UpdateRule(7,spec()),"in-flight transfer blocks delete/edit")
R.pending=nil
U:EditRule(updated)
check(U.editingRuleId==7 and U.quantity.text=="5" and U.allowUnits.text=="10" and not U.saveRuleButton:IsHidden(),"rule editor loads complete current configuration")
check(U.editingSession,"rule editor pauses new background transfers while allowance counters are being edited")
U.editing.source=R.BANK;U.editing.dest="A";U.editing.mode="ask";U.ruleKind="overflow"
U.quantity:SetText("25");U.bankStacks:SetText("3");U.allowUnits:SetText("");U.allowMoves:SetText("")
U:Save("overflow")
check(R:Rule(7).overflowStacks==3 and R:Rule(7).source==R.BANK and R:Rule(7).maxPerStack==25,"rule editor saves a type conversion without adding a new rule")
check(not U.editingSession,"saving releases the rule-edit execution pause")
check(not R:BuildRule({source=R.BANK,dest="@learners",link="ore",qty=1,mode="ask"}),"ordinary rule cannot retain virtual learning destination")
U:EditRule(R:Rule(7));U.ruleKind="repeat";U.quantity:SetText("17")
U.replaceButton.handlers.OnClicked()
bags[BAG_BACKPACK][0]={name="replacement",id=777,quality=2,filter=ITEMFILTERTYPE_CRAFTING}
U:Mark(G.backpack,{bag=BAG_BACKPACK,slot=0,identity="777"})
check(U.editingRuleId==7 and U.editing.link=="item-link-777" and U.quantity.text=="17" and U.ruleKind=="repeat","replacement item preserves other unsaved rule edits")
U:Close()
check(not U.editingSession,"closing without saving releases the execution pause")

LibCharacterKnowledge={ITEM_CATEGORY_NONE=0,KNOWLEDGE_UNKNOWN=2,KNOWLEDGE_KNOWN=1,KNOWLEDGE_NODATA=3,
 GetItemCategory=function(link)return link=="recipe" and 1 or 0 end,
 GetItemKnowledgeForCharacter=function()return 2 end}
U.editing={link="recipe",source=characterId,dest=R.BANK,mode="ask"}
menuEntries={};U:Suggestions(U.destination)
local crafterOption,explanation=false,false
for _,entry in ipairs(menuEntries) do
 if entry.name:find("designated crafter",1,true) then crafterOption=true end
 if entry.name:find("No eligible recipe learner",1,true) then explanation=true end
end
check(not crafterOption and explanation,"recipe suggestions hide material-only action and explain empty learner list")
R.data.profiles.A={learner=true};menuEntries={};U:Suggestions(U.destination)
local suggested
for _,entry in ipairs(menuEntries) do if entry.name:find("Missing recipe: A",1,true) then suggested=entry end end
check(suggested~=nil,"designated confirmed-unknown recipe learner is offered")
suggested.callback()
check(U.editing.dest=="A" and U.quantity.text=="1" and U.editing.smart.kind=="recipe","recipe suggestion selects learner and one copy")

local requests=0;CallSecureProtected=function()requests=requests+1 end
mockCharacterGold=123456;mockBankGold=987654
S.ready=true;S:Capture()
check(S.records[characterId].gold==123456 and S.records[characterId].equipment.gold==123456,"character/equipment snapshots retain character gold")
bankOpen=true;S:CaptureBank()
check(G.saved.bankSnapshots[S.world].gold==987654,"open personal bank snapshot captures bank gold")
bankOpen=false;mockBankGold=42;S:CaptureBank()
check(G.saved.bankSnapshots[S.world].gold==987654,"closed bank cannot overwrite saved bank gold")
S:Select(G,characterId);G:Refresh()
check(G.backpack.goldLabel.text=="Gold: 123,456","live character gold formatted in grid")
mockCharacterGold=777;EVENT_MANAGER.events.GridBagsSnapshots[EVENT_MONEY_UPDATE]()
G:Refresh();check(G.backpack.goldLabel.text=="Gold: 777" and S.pending,"gold event refreshes live display and queues snapshot")
S.records.A.gold=0;S:Select(G,"A")
check(G.backpack.goldLabel.text=="Gold: 0 (saved)","saved zero gold distinguished from missing data")
S.records.A.gold=nil;G:Refresh()
check(G.backpack.goldLabel.text:find("not captured",1,true),"old snapshots do not falsely show live character's balance")
S:Select(G,"@account-bank")
check(G.backpack.goldLabel.text=="Gold: 987,654 (saved)","saved bank view uses last observed gold")
bankOpen=true;G.sceneName="bank";G:Refresh()
check(G.bank.goldLabel.text=="Gold: 42","banking screen shows live bank gold")
mockBankGold=100;EVENT_MANAGER.events.GridBagsSnapshots[EVENT_BANKED_MONEY_UPDATE]()
check(G.saved.bankSnapshots[S.world].gold==100 and requests==0,"bank currency update refreshes snapshot without any automatic gold moves")

LibAddonMenu2={RegisterAddonPanel=function()end,RegisterOptionControls=function(self,_,options)self.options=options end}
GridBagsCompatibility:Initialize(G)
local options={};for _,option in ipairs(LibAddonMenu2.options)do options[option.name or option.type]=option end
check(options["Open routing planner"] and options["Character role profiles"] and options["Open grid to mark items"],"settings expose planner/profile/marking shortcuts")
options["Show character and bank gold"].setFunc(false)
check(G.bank.goldLabel:IsHidden(),"gold display preference works")
options["Show character and bank gold"].setFunc(true)
SCENE_MANAGER.Show=function(_,name)G.sceneName=name end
bankOpen=false;options["Open routing planner"].func()
EVENT_MANAGER.updates.GridBagsSettingsShortcut()
check(not U.window:IsHidden() and G.sceneName=="inventory","settings shortcut opens planner in inventory scene")
options["Open grid to mark items"].func();EVENT_MANAGER.updates.GridBagsSettingsShortcut()
check(G.planMode and not G.root:IsHidden(),"settings marking shortcut enables visible grid planning controls")
print("PASS: "..checks.." rule maintenance, recipe suggestions, gold and settings checks (Lua 5.1 mock).")
