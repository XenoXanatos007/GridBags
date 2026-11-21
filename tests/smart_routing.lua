local checks = 0
local function check(v, message) assert(v, message); checks = checks + 1 end
local R, M, S, U = GridBagsRouting, GridBagsSmartRouting, GridBagsSnapshots, GridBagsRoutingUI
GetBagSize=function(bag)return bag==BAG_SUBSCRIBER_BANK and 0 or 8 end
GetBagUseableSize=GetBagSize
local known, researchTime = {}, {}
LibCharacterKnowledge = {
    KNOWLEDGE_KNOWN=1, KNOWLEDGE_UNKNOWN=2, KNOWLEDGE_NODATA=3, KNOWLEDGE_INVALID=0, ITEM_CATEGORY_NONE=0,
    GetItemKnowledgeForCharacter=function(link,server,id) assert(server==nil);return known[id] or 3 end,
    GetSmithingResearchStatusForCharacter=function(craft,line,trait,server,id) assert(craft==1 and line==2 and server==nil);return known[id] or 3,researchTime[id] end,
    GetSmithingResearchFromItemLink=function(link) local n=link:match("research:(%d+)");if n then return 1,2,tonumber(n) end end,
    GetItemCategory=function(link) return link:find("recipe",1,true) and 1 or 0 end,
}
GetItemLinkItemId=function(link) return link:find("recipe",1,true) and 100 or link end
local function fresh()
    R:Close(); R.pending=nil;R.current=nil;R.character=characterId;BMR=nil
    R.data={plans={},rules={},protections={},profiles={}}
    G.saved.routing[GetWorldName()]=R.data
    bankOpen=true;G.sceneName="bank"
    bags[BAG_BACKPACK]={};bags[BAG_BANK]={};bags[BAG_SUBSCRIBER_BANK]={}
    S.records={}
    for _,id in ipairs({characterId,"A","B","C"}) do S.records[id]={name=id,updatedAt=timestamp,items={},used=0,capacity=8} end
    known={A=2,B=2,C=3};researchTime={}
end
local function stack(link,qty,id)
    return {name=link,variant=link,qty=qty,id=id or 2001,maximum=200,quality=2,filter=ITEMFILTERTYPE_CONSUMABLE}
end
fresh()
check(M:Knowledge("recipe", "A")=="unknown", "confirmed unknown distinct from no-data")
check(M:Knowledge("recipe", "C")=="no-data", "missing provider data is not an unknown recipe")
known.A=1;check(M:Knowledge("recipe","A")=="known", "known recipe classified explicitly")
known.A=2;S.records.A.updatedAt=timestamp-8*86400
check(M:Knowledge("recipe","A")=="no-data", "stale recipient snapshot held for review")
S.records.A.updatedAt=timestamp
researchTime.A=300
check(M:Knowledge("research:3","A",true)=="researching", "in-progress research is not a missing trait")
researchTime.A=nil
check(M:Knowledge("research:3","A",true)=="unknown", "confirmed missing research eligible")
S.records.A.items={{link="recipe:variant2"}}
check(M:Duplicate("A","recipe:variant1"), "recipe duplicate detection normalizes item identity across link variants")
S.records.A.items={{link="research:3:quality2"}}
check(M:Duplicate("A","research:3:quality1",true), "research duplicates match craft/line/trait across item variants")
check(not M:Duplicate("A","research:4",true), "different research trait is not a duplicate")

fresh()
R.data.profiles={A={learner=true,priority=10},B={learner=true,priority=1},C={learner=true,priority=20}}
local entries,noData=M:Learners("recipe",characterId,false)
check(#entries==2 and entries[1].id=="B" and noData, "learner priorities and no-data hold coexist")
bags[BAG_BACKPACK][0]=stack("recipe",10)
assert(R:AddRule({source=characterId,dest="@learners",link="recipe",name="recipe",qty=1,maxStack=200,mode="ask",strategy="recipe"}))
R:Open()
check(#R.data.plans==2,"learning rule proposes one copy per confirmed eligible learner")
check(R.data.plans[1].dest=="B" and R.data.plans[2].dest=="A", "higher-priority learner gets first allocation")
check(R.data.plans[1].qty==1 and R.data.plans[2].qty==1,"stack of recipes is not sent wholesale to one learner")
check(R.current and R.current.qty==2 and #R.current.allocations==2, "learning allocations share one confirmed source-stack operation")
local count=#R.data.plans
R:Close();R:Open();check(#R.data.plans==count,"pending/reserved deliveries suppress duplicate learning proposals")
check(R.data.learningHolds.recipe,"no-data learner prevents automatic duplicate overflow")
fresh();R.data.profiles={[characterId]={learner=true},A={learner=true}}
known[characterId]=2;bags[BAG_BACKPACK][0]=stack("recipe",1)
assert(R:AddRule({source=characterId,dest="@learners",link="recipe",qty=1,maxStack=200,mode="standing",strategy="recipe"}))
R:Open();check(#R.data.plans==0,"learning rule keeps the source learner's own needed copy")

fresh()
R.data.profiles={A={learner=true,priority=1},B={learner=true,priority=2}}
known.A=1;known.B=1
bags[BAG_BACKPACK][0]=stack("recipe",10)
assert(R:AddRule({source=characterId,dest="@learners",link="recipe",qty=1,maxStack=200,mode="standing",strategy="recipe"}))
R:Open();check(#R.data.plans==0 and not R.current and not R.pending,"known copies remain untouched without explicit duplicate-storage rule")

fresh()
R.data.profiles={A={learner=true},B={learner=true}}
known.A=1;known.B=3
bags[BAG_BANK][0]=stack("recipe",10)
assert(R:AddRule({source=R.BANK,dest=characterId,link="recipe",qty=10,maxStack=200,mode="standing",overflow=true,overflowStacks=0}))
assert(R:AddRule({source=R.BANK,dest="@learners",link="recipe",qty=1,maxStack=200,mode="ask",strategy="recipe"}))
R:Open();check(#R.data.plans==0,"learning holds outrank overflow even when overflow rule was added first")

fresh()
S.records.A.items={{link="recipe"}}
local p=assert(R:Add({source=R.BANK,dest="A",link="recipe",name="recipe",qty=1,uid="123",maxStack=200,mode="advance",smart={kind="recipe"}}))
check(not M:Eligible(p),"recipient already holding a copy blocks a smart delivery")
S.records.A.items={};check(M:Eligible(p),"own reservation is not mistaken for a duplicate")
known.A=1;check(not M:Eligible(p),"learning eligibility rechecked after recipient learns recipe")
known.A=3;check(not M:Eligible(p),"preapproval cannot override loss of provider evidence")

fresh()
local bonusNames={"BLACKSMITHING","CLOTHIER","ENCHANTING","ALCHEMY","PROVISIONING","WOODWORKING","JEWELRYCRAFTING"}
for i,n in ipairs(bonusNames) do _G["NON_COMBAT_BONUS_"..n.."_LEVEL"]=i end
GetCraftingSkillLineIndices=function(craft)return 7,craft end
GetSkillLineDynamicInfo=function(_,line)return line+10 end
GetNonCombatBonus=function()return 3 end
GetNumSkillAbilities=function()return 2 end
GetSkillAbilityInfo=function(_,_,index)return "passive","icon",1,true,false,index==1 end
GetSkillAbilityUpgradeInfo=function()return 2 end
local professions=M:CaptureProfessions()
check(professions[1].rank==11 and professions[7].rank==17,"profession rank captured independently of combat level")
check(professions[1].tier==3 and professions[1].passivePoints==2,"usable tier and purchased passive investment captured")
ITEMTYPE_BLACKSMITHING_MATERIAL=910
GetItemLinkItemType=function(link)return link=="ore" and 910 or 0 end
GetItemLinkRequiredCraftingSkillRank=function()return 4 end
R.data.profiles={A={crafter=true,priority=1},B={crafter=true,priority=2}}
S.records.A.professions={[1]={rank=30,tier=3,passivePoints=10}}
S.records.B.professions={[1]={rank=25,tier=6,passivePoints=12}}
local id,err=M:Crafter("ore",characterId)
check(not id and err:find("cannot use"),"highest-level lead cannot receive material above its usable tier")
check(R.data.tierHolds.ore,"unusable lead material is held out of overflow")
S.records.A.professions[1].tier=5
local requirement,reason
id,err,requirement,reason=M:Crafter("ore",characterId)
check(id=="A" and requirement.tier==4,"qualified lead chosen by profession rank with usable material check")
check(not R.data.tierHolds.ore,"fresh qualification clears prior tier hold")
S.records.B.professions[1]={rank=30,tier=5,passivePoints=11}
id=M:Crafter("ore",characterId);check(id=="B","passive investment resolves equal profession ranks")
S.records.B.professions[1].passivePoints=10;R.data.profiles.B.priority=1
id=M:Crafter("ore",characterId);check(not id,"equal lead evidence needs manual priority rather than alphabetical selection")
check(not M:Crafter("unclassified",characterId),"unclassified ingredients do not inherit smithing-tier assumptions")
R.data.profiles.B.priority=2
local lead,leadReason=M:Crafter("ore","A")
check(not lead and leadReason:find("source is already"),"highest crafter being the source keeps its own usable materials rather than choosing a lower crafter")
p={dest="A",link="ore",smart={kind="craft",craft=1,tier=4}}
check(M:Eligible(p),"saved qualified crafter permits a scoped material proposal")
p.dest=characterId
check(not M:Eligible(p),"bank pickup rechecks current live usable tier rather than old snapshot")

fresh()
R:SetProtection(characterId,"recipe",true,10)
check(not R:SetProtection(characterId,"recipe",false,"bad"),"invalid keep input cannot clear a source protection")
check(R:Protection(characterId,"recipe").blocked,"previous hard protection survives invalid edit")
check(not R:AddRule({source=characterId,dest="A",link="recipe",qty=1,mode="limited",units="bad",moves=3}),"invalid allowance rejected rather than silently authorizing defaults")
local limited=assert(R:AddRule({source=characterId,dest="A",link="recipe",qty=1,mode="limited",moves=3}))
check(limited.unitsLeft==nil and limited.movesLeft==3,"route-only allowance can leave unit counter unlimited")
R.data.rules={}
limited=assert(R:AddRule({source=characterId,dest="A",link="recipe",qty=1,mode="limited",units=200}))
check(limited.movesLeft==nil and limited.unitsLeft==200,"unit-only allowance can leave route counter unlimited")
R.data.rules={}
G.sceneName="inventory";G.saved.externalFilters=false
bags[BAG_BACKPACK][0]=stack("recipe",10)
U:Mark(G.backpack,{bag=BAG_BACKPACK,slot=0,identity=tostring(bags[BAG_BACKPACK][0].id)})
check(U.editing and not U.editor:IsHidden(),"live plan marker opens editor with observed identity")
U.quantity:TakeFocus();U:Close();check(not U.quantity.focused,"closing planner releases keyboard focus")
U:Mark(G.backpack,{bag=BAG_BACKPACK,slot=0,identity=tostring(bags[BAG_BACKPACK][0].id)})
U.editing.mode="advance"
local originalDest=U.editing.dest
U:Save("learning")
check(#R.data.rules==0 and U.editing.dest==originalDest,"invalid learning approval leaves the editor's named destination unchanged")
U.editing.mode="ask";U.keep:SetText("5");U.never=true
U.quantity:TakeFocus();U:Save("learning")
check(#R.data.rules==1 and R.data.rules[1].strategy=="recipe" and R.data.rules[1].dest=="@learners","learning editor creates a scoped recipe rule")
check(R:Protection(characterId,"recipe").blocked and R:Protection(characterId,"recipe").keep==5,"displayed source constraints apply atomically when saving a rule")
check(not U.quantity.focused and U.editor:IsHidden(),"saving a route releases input focus before returning to planner")
G.selectedCharacter=characterId;G.backpack.query="";G.backpack.filter=nil
bags[BAG_BACKPACK][1]=stack("other",25,2002)
G.saved.sort="stack"
local sorted=G:ReadItems(G.backpack,{BAG_BACKPACK})
check(sorted[1].stack==25,"stack sorting orders observed quantities without moving items")
G.saved.sort="slot";sorted=G:ReadItems(G.backpack,{BAG_BACKPACK})
check(sorted[1].slot==0 and sorted[2].slot==1,"slot sorting restores physical order")
print("PASS: "..checks.." smart recipe/research/crafter/profile checks (Lua 5.1, mocked provider records).")
