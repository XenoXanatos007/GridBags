local checks = 0
local function check(value, text) assert(value, text); checks = checks + 1 end
local R, U = GridBagsRouting, GridBagsRoutingUI
local uid, requests, sizes = 1000, {}, {}
local function item(name, count, variant, maximum)
    uid = uid + 1
    return { name = name, qty = count, variant = variant or name, id = uid, quality = 3, maximum = maximum or 200, filter = ITEMFILTERTYPE_CRAFTING }
end
GetBagSize = function(bag) return sizes[bag] or 8 end
GetBagUseableSize = GetBagSize
GetItemLink = function(bag, slot) return bags[bag][slot] and bags[bag][slot].variant or "" end
GetSlotStackSize = function(bag, slot) local i = bags[bag][slot]; return i and i.qty or 0, i and i.maximum or 200 end
IsItemPlayerLocked = function(bag, slot) return bags[bag][slot] and bags[bag][slot].locked or false end
CallSecureProtected = function(name, from, slot, to, target, qty)
    check(name == "RequestMoveItem", "executor uses secure move gateway only")
    requests[#requests + 1] = {from, slot, to, target, qty}; return true
end
local function reset()
    R:Close(); R.pending = nil; R.current = nil; BMR = nil
    R.data = { plans = {}, rules = {}, protections = {}, profiles = {} }
    G.saved.routing[GetWorldName()] = R.data
    R.character = characterId; bankOpen = true; G.sceneName = "bank"
    bags = {[BAG_BACKPACK]={},[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={},[BAG_WORN]={}}
    sizes = {[BAG_BACKPACK]=8,[BAG_BANK]=8,[BAG_SUBSCRIBER_BANK]=0,[BAG_WORN]=8}
    requests = {}
end
local function add(source, dest, stack, qty, mode)
    return assert(R:Add({ source = source, dest = dest, link = stack.variant, name = stack.name,
        qty = qty, available = stack.qty, uid = tostring(stack.id), maxStack = stack.maximum, mode = mode or "ask" }))
end
local function apply()
    local req = requests[#requests]
    assert(req, "no pending request")
    local from, slot, to, target, qty = unpack(req)
    local old = bags[from][slot]; assert(old and old.qty >= qty, "simulator source")
    local dest = bags[to][target]
    if dest then dest.qty = dest.qty + qty
    else
        dest = {}; for k,v in pairs(old) do dest[k] = v end
        dest.qty = qty; if qty < old.qty then uid = uid + 1; dest.id = uid end
        bags[to][target] = dest
    end
    old.qty = old.qty - qty
    if old.qty == 0 then bags[from][slot] = nil end
    R:Observe()
end

reset()
local stack = item("ore",100); bags[BAG_BACKPACK][0] = stack
local p = add(characterId,"crafter",stack,40)
R:Open()
check(R.current and #requests == 0, "marked plan asks before any transfer")
check(not U.confirmWindow:IsHidden(), "bank confirmation visible without selecting a grid item")
R:Confirm(false)
check(#requests == 1 and p.state == "source", "request alone is not proof of movement")
R:Tick(); check(#requests == 1, "pending operation serializes requests")
apply()
check(p.state == "bank" and p.approved and p.remaining == 40, "deposit reserves quantity and approves only the named route")
check(R:Reserved("ore") == 40 and bags[BAG_BACKPACK][0].qty == 60, "source remainder and bank reservation correct")
R:Tick(); check(#requests == 1, "deposit cannot bounce back in frozen queue")
R:Open(); R:Tick(); check(#requests == 1, "reloading an open visit cannot repeat completed stack")
R:Close(); R.character = "crafter"; R:Open()
check(#requests == 2 and not R.current, "preapproved recipient collects only at its own bank visit")
apply(); check(p.state == "done" and R:Reserved("ore") == 0, "observed withdrawal releases reservation")

reset(); stack=item("ore",100); bags[BAG_BACKPACK][0]=stack
local a=add(characterId,"A",stack,30); local b=add(characterId,"B",stack,20)
local fail,err=R:Add({source=characterId,dest="C",link="ore",uid=tostring(stack.id),qty=60,available=100,mode="ask"})
check(not fail and err, "snapshot splits cannot oversubscribe observed source units")
R:Open(); check(#R.data.visit.queue==1 and #R.current.allocations==2 and R.current.qty==50, "split recipients coalesce into one physical deposit")
R:Confirm(false); apply(); check(a.state=="bank" and b.state=="bank" and #requests==1,"one deposit creates independent named reservations")

reset(); stack=item("ore",100); bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance"); R:SetProtection(characterId,"ore",true,0);R:Open()
check(#requests==0 and not R.current and p.reason:find("protected"),"never-source protection overrides preapproval")
R:Close(); R:SetProtection(characterId,"ore",false,80);R:Open()
check(#requests==0 and p.state=="source", "keep floor prevents whole approved move rather than silently shrinking it")
R:Close(); R:SetProtection(characterId,"ore",false,60);R:Open();check(#requests==1,"permitted excess can move after protection edit")
apply()

reset(); stack=item("ore",100); bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance")
sizes[BAG_BANK]=1;bags[BAG_BANK][0]=item("ore",190)
R:Open(); check(#requests==0 and p.reason:find("No room"),"no-space skips without spending or changing plan")
R:Tick();check(#requests==0,"no-space skip is not retried in same opening")
R:Close();bags[BAG_BANK][0].qty=160;R:Open();check(#requests==1,"merge capacity is checked even when no empty slots exist")
apply();check(p.state=="bank" and bags[BAG_BANK][0].qty==190,"partial deposit merges exactly approved quantity")

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30)
R:Open();bags[BAG_BACKPACK][0]=item("ore",100);R:Confirm(false)
check(#requests==0 and p.reason:find("identity"),"confirmation revalidates physical identity")
R:Close();R:Open();check(#requests==0,"same-name replacement does not satisfy exact source plan")

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance");R:Open()
timestamp=timestamp+5;R:Observe()
check(p.state=="review" and R.pending==nil,"unacknowledged transfer stops for review")
R:Open();R:Tick();check(#requests==1,"uncertain result cannot replay on UI reload")
R:Close();R:Open();check(#requests==1,"uncertain result cannot replay on next opening")

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance");R:Open()
R.pending=nil;R:Open()
check(p.state=="review" and #requests==1,"persisted in-flight journal is held after reload")

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance");R:Open();R:Close()
check(p.state=="review" and R.data.visit.open==false,"closing bank during transfer holds uncertain plan")

reset();stack=item("ore",100);bags[BAG_BANK][0]=stack
p=add(R.BANK,characterId,stack,80);local q=add(R.BANK,"A",stack,50)
R:Open();check(#requests==0 and p.state=="review" and p.reserve,"missing reserved bank stock is held instead of stealing another reservation")

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
local s2=item("wood",70);bags[BAG_BACKPACK][1]=s2
p=add(characterId,"A",stack,20);q=add(characterId,"B",s2,20)
R:Open();R:Skip(true);R:Tick()
check(#requests==0 and p.state=="source" and q.state=="source","Skip All preserves pending plans without transfers")
R:Close();R:Open();R:Confirm(true);apply();R:Tick();check(#requests==2,"Confirm All covers this frozen queue")
apply();R:Close()
local third=item("ore",100);bags[BAG_BACKPACK][2]=third;add(characterId,"C",third,20)
R:Open();check(R.current and #requests==2,"Confirm All does not authorize a later bank visit")

reset(); stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
local rule=assert(R:AddRule({source=characterId,dest="A",link="ore",name="ore",qty=20,maxStack=200,mode="limited",units=40,moves=2}))
R:Open();check(#requests==1 and not R.current,"limited allowance starts matching move without prompt")
apply();check(rule.unitsLeft==20 and rule.movesLeft==1,"allowance charged once after observed first leg")
R:Close();R.character="A";R:Open();apply()
check(rule.unitsLeft==20 and rule.movesLeft==1,"second bank leg does not spend the same allowance twice")
R:Close();R.character=characterId;R:Open();apply()
R:Close();R.character="A";R:Open();apply();R:Close();R.character=characterId;R:Open()
check(R.current and rule.unitsLeft==0 and rule.movesLeft==0,"exhausted allowance falls back to confirmation")

reset();stack=item("ore",750);stack.maximum=1000;bags[BAG_BANK][0]=stack
rule=assert(R:AddRule({source=R.BANK,dest=characterId,link="ore",qty=1000,maxStack=200,mode="ask",overflow=true,overflowStacks=3}))
R:Open();check(R.current.qty==150,"overflow retains three full-stack equivalents, not three occupied slots")
R:Skip(true)

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance");R:Open();apply()
R:Close();R.character="A";R:SetProtection(R.BANK,"ore",true,0);R:Open()
check(#requests==1 and p.state=="bank","bank keep/never-export protection also overrides pickup approval")

reset();stack=item("sword",1,"same-gear-link",1);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,1,"advance");R:Open();apply()
check(p.bankUid==tostring(stack.id),"unique equipment identity follows its bank deposit")
R:Close();bags[BAG_BANK][0]=item("sword",1,"same-gear-link",1);R.character="A";R:Open()
check(#requests==1 and p.state=="review","identical-link gear cannot substitute for reserved unique equipment")

reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance");BMR={};R:Open()
check(#requests==0 and R.notice:find("BankManager"),"loaded BankManager blocks automatic execution")
BMR=nil
check(not R:Add({source=characterId,dest="A",link="ore",qty=1,mode="ask",equipped=true}),"worn items rejected by planning API")
check(not R:Add({source=characterId,dest="A",link="ore",qty=1,mode="ask"}),"old identity-free character snapshot cannot authorize a move")
check(not R:AddRule({source=characterId,dest="A",link="ore",qty=1,mode="advance"}),"repeat rule cannot inherit a one-time advance approval")
reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,20,"advance");stack.qty=80;R:Open()
check(#requests==0 and p.reason:find("shrank"),"decreased observed stack cannot replay an old approved deposit even if enough units remain")
reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack
p=add(characterId,"A",stack,30,"advance");R:Open()
stack.qty=90;bags[BAG_BANK][0]=item("ore",10);timestamp=timestamp+5;R:Observe()
check(p.state=="review" and p.remaining==30,"unexpected partial result cannot be accepted as a completed allocation")
R:Tick();check(#requests==1,"partial result never triggers a second attempt this visit")
reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack;sizes[BAG_BANK]=0
rule=assert(R:AddRule({source=characterId,dest="A",link="ore",qty=20,maxStack=200,mode="limited",units=40,moves=2}))
R:Open();check(#requests==0 and rule.unitsLeft==40 and rule.movesLeft==2,"no-space attempt consumes no automatic allowance")
reset();stack=item("ore",100);bags[BAG_BACKPACK][0]=stack;sizes[BAG_BANK]=0;sizes[BAG_SUBSCRIBER_BANK]=8
p=add(characterId,"A",stack,20,"advance");IsESOPlusSubscriber=function()return false end
R:Open();check(#requests==0,"unsubscribed account cannot deposit into unused subscriber bank slots")
R:Close();IsESOPlusSubscriber=function()return true end;R:Open()
check(#requests==1 and requests[1][3]==BAG_SUBSCRIBER_BANK,"active subscriber may use additional bank capacity")
apply();R:Close();IsESOPlusSubscriber=nil
reset();stack=item('unique belt',1,'belt',1);bags[BAG_BACKPACK][0]=stack
p=add(R.BANK,characterId,stack,1);p.state='review';p.reserve=true;p.reasonCode='RESERVATION_MISSING';p.reason='Missing'
local allowance=assert(R:AddRule({source=R.BANK,dest=characterId,link='belt',name='belt',qty=1,maxStack=1,mode='limited',units=4,moves=2,enabled=false}));p.rule=allowance.id
check(R:Reserved('belt')==1,'missing unique item reserves bank stock before reconciliation')
bankOpen=false;EVENT_MANAGER.events.GridBagsRouting[EVENT_PLAYER_ACTIVATED]()
check(p.state=='done'and p.remaining==0 and not p.reserve and not p.reason and not p.reasonCode,'login reconciles exact live recipient item and clears review hold')
check(R:Reserved('belt')==0 and #requests==0,'arrival releases reservation without requesting transfer')
check(allowance.unitsLeft==4 and allowance.movesLeft==2 and not p.approved,'observed arrival spends no allowance and grants no approval')
local event=GridBagsActivity.data.history[#GridBagsActivity.data.history]
check(event.code=='RECIPIENT_ALREADY_HAS_ITEM'and event.quantity==1 and event.plan==p.id,'reconciliation logs actual unique arrival with distinct reason')
check(GridBagsRoutingInsights:Reason(p):find('outside the GridBags',1,true),'delivery overview explains observed external arrival')
local n=#GridBagsActivity.data.history;check(R:ReconcileArrivals()==0 and #GridBagsActivity.data.history==n,'reconciliation idempotent')
reset();stack=item('unique boots',1,'boots',1);bags[BAG_WORN][0]=stack;p=add(R.BANK,characterId,stack,1)
R:Open();check(p.state=='done'and #requests==0 and #R.data.visit.queue==0,'bank visit recognizes already equipped unique item before building queue')
reset();stack=item('unique belt',1,'belt',1);p=add(R.BANK,characterId,stack,1);bags[BAG_BACKPACK][0]=item('identical belt',1,'belt',1)
R:Open();check(p.state=='review','same-link copy with different unique ID cannot complete delivery')
reset();stack=item('unique belt',1,'belt',1);p=add(R.BANK,'A',stack,1);bags[BAG_BACKPACK][0]=stack
check(R:ReconcileArrivals()==0 and p.state=='bank','exact item on wrong character cannot complete delivery')
reset();stack=item('ore',1,'ore',200);bags[BAG_BACKPACK][0]=stack;p=add(R.BANK,characterId,stack,1);p.state='review';p.reserve=true;p.reasonCode='RESERVATION_MISSING'
check(R:ReconcileArrivals()==0 and p.state=='review','stackable item identity cannot prove reserved quantity arrival')
reset();stack=item('unique belt',1,'belt',1);bags[BAG_BACKPACK][0]=stack;p=add(R.BANK,characterId,stack,1);p.state='review';p.reserve=true;p.reasonCode='TIMEOUT_UNCERTAIN'
check(R:ReconcileArrivals()==0 and p.state=='review','unrelated uncertain-result holds stay held')
reset();stack=item('unique belt',1,'belt',1);bags[BAG_BACKPACK][0]=stack;p=add(R.BANK,characterId,stack,1);R.pending={}
check(R:ReconcileArrivals()==0 and p.state=='bank','in-flight receipt cannot be reconciled early');R.pending=nil
R.data.visit={inFlight={}};check(R:ReconcileArrivals()==0,'persisted in-flight journal also prevents reconciliation');R.data.visit=nil
reset();stack=item('unique belt',1,'belt',1);p=add(R.BANK,characterId,stack,1)
GridBagsSnapshots.records[characterId]={items={{link='belt',uid=tostring(stack.id),stack=1,maxStack=1}}}
check(R:ReconcileArrivals()==0,'saved snapshot alone cannot complete delivery')
bags[BAG_BACKPACK][0]=stack;stack.variant='enchanted belt'
check(R:ReconcileArrivals()==1 and p.state=='done','unique ID still identifies exact item after enchantment/link change')
reset();stack=item('unique belt',1,'belt',1);bags[BAG_BACKPACK][0]=stack;p=add(R.BANK,characterId,stack,1);local duplicate=add(R.BANK,characterId,stack,1)
duplicate.state='source';duplicate.source='old-source'
local before=#GridBagsActivity.data.history
check(R:ReconcileArrivals()==2 and p.state=='done'and duplicate.state=='done','same exact item fulfils both old source and bank delivery records')
check(#GridBagsActivity.data.history==before+1 and #GridBagsActivity.data.history[#GridBagsActivity.data.history].relatedPlans==2,'duplicate goals generate one arrival event for one physical item')
check(R:ReconcileArrivals()==0 and #requests==0,'duplicate-goal completion never repeats or requests physical movement')
reset();stack=item('unique belt',1,'belt',1);bags[BAG_BACKPACK][0]=stack;p=add('old-source',characterId,stack,1)
duplicate=add(R.BANK,'other-target',stack,1)
check(R:ReconcileArrivals()==1 and p.state=='done'and duplicate.state=='bank','exact direct arrival completes source goal without fulfilling another recipient goal')
print("PASS: " .. checks .. " routing/approval/failure checks (Lua 5.1, asynchronous mock transfers).")
