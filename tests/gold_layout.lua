local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local Gold,UI,R,L=GridBagsGold,GridBagsGoldUI,GridBagsRouting,GridBagsLayout
local requests,capacity={},1000000000
TransferCurrency=function(currency,amount,from,to)
    requests[#requests+1]={currency=currency,amount=amount,from=from,to=to}
end
GetMaxCurrencyTransfer=function()return capacity end
local function reset(carried,bank)
    Gold.pending=nil;Gold.current=nil
    Gold.data={profiles={},daily={},holds={},history={},bankReserve=0}
    G.saved.goldRouting[GetWorldName()]=Gold.data
    R.pending=nil;R.current=nil;R.data.visit={queue={},open=true,index=1}
    R.data.plans={};R.data.rules={}
    GridBagsRoutingUI:Close();UI:Close()
    mockCharacterGold=carried or 30000;mockBankGold=bank or 100000
    bankOpen=true;G.sceneName="bank";G.saved.enabled=true;G.saved.externalFilters=false
    requests={};capacity=1000000000;BMR=nil
end
local function spec(mode)
    return {enabled=true,min=10000,max=20000,fixed=0,threshold=0,cap=0,resetHour=0,frequency="visit",mode=mode or "ask"}
end
local function save(p,reserve)return assert(Gold:SaveProfile(characterId,p,reserve or 0))end
local function apply()
    local op=assert(requests[#requests])
    local change=op.from==CURRENCY_LOCATION_CHARACTER and -op.amount or op.amount
    mockCharacterGold=mockCharacterGold+change;mockBankGold=mockBankGold-change
    Gold:Observe()
end

reset();Gold:Open()
check(#requests==0 and Gold.data.visit.state=="idle","gold rules start disabled")
reset();local p=save(spec());Gold:Open()
check(Gold.current and Gold.current.amount==10000 and #requests==0,"carried excess proposes an exact deposit before asking")
check(not UI.confirm:IsHidden() and UI.confirmText.text:find("20,000",1,true),"confirmation shows resulting balances")
Gold:Confirm();check(#requests==1 and Gold.data.visit.state=="sent" and #Gold.data.history==0,"currency request is not a receipt")
Gold:Tick();check(#requests==1,"gold request serialized while awaiting receipt")
apply();check(mockCharacterGold==20000 and mockBankGold==110000 and #Gold.data.history==1,"both balances verify a deposit")
Gold:Tick();Gold:Open();check(#requests==1,"completed gold cannot replay in same visit or normal reload")

reset(5000,6000);p=save(spec("standing"),2000);Gold:Open()
check(#requests==0 and Gold.data.visit.reason:find("reserve"),"bank reserve prevents an underfunded refill")
reset(5000,100000);p=save(spec("standing"),2000);Gold:Open()
check(#requests==1 and requests[1].from==CURRENCY_LOCATION_BANK and requests[1].amount==5000,"carried minimum withdraws the shortfall")
apply();check(mockCharacterGold==10000 and mockBankGold==95000,"withdrawal verified in both locations")
reset(5000);local depositOnly=spec("standing");depositOnly.refill=false;save(depositOnly);Gold:Open()
check(#requests==0,"deposit-only policy can protect a carried floor without automatically withdrawing")

reset(50000);local cfg=spec("standing");cfg.cap=2000;p=save(cfg);Gold:Open();apply();Gold:Tick()
check(#requests==1 and mockCharacterGold==48000,"cap limits the move and does not cause repeated cleanup this visit")
Gold:Close();Gold:Open();check(#requests==2,"next bank opening may make another capped move")

reset(50000);cfg=spec("once");cfg.cap=10000;p=save(cfg);Gold:Open()
check(p.mode=="once","one-time preapproval not spent on request alone")
apply();check(p.mode=="ask","one-time preapproval reverts to Ask after success")
Gold:Close();Gold:Open();check(Gold.current and #requests==1,"next eligible visit requires confirmation after one-time approval")

reset(50000);cfg=spec("limited");cfg.cap=10000;cfg.unitsLeft=15000;cfg.movesLeft=1;p=save(cfg);Gold:Open();apply()
check(p.unitsLeft==5000 and p.movesLeft==0,"verified gold spends allowance once")
Gold:Close();Gold:Open();check(Gold.current and #requests==1,"insufficient automatic allowance falls back to asking for whole move")
Gold:Confirm();apply();check(p.unitsLeft==0 and p.movesLeft==0,"confirmed move exhausts but never replenishes allowance")

reset(25000);cfg=spec("standing");cfg.max=nil;cfg.fixed=5000;cfg.frequency="daily";cfg.threshold=12000;p=save(cfg)
Gold:Open();check(#requests==1 and Gold.data.daily[characterId]==nil,"daily marker not spent before receipt")
apply();local day=Gold.data.daily[characterId]
Gold:Close();Gold:Open();check(#requests==1 and Gold.data.visit.state=="idle","daily contribution cannot repeat on another bank visit that day")
timestamp=timestamp+86400;Gold:Close();Gold:Open()
check(#requests==2 and Gold.data.daily[characterId]==day,"next day becomes eligible while old day remains recorded until success")
apply();check(Gold.data.daily[characterId]~=day,"next day's receipt advances daily marker")

reset(50000);cfg=spec("standing");cfg.fixed=5000;cfg.frequency="daily";p=save(cfg);Gold:Open()
check(requests[1].amount==30000,"max-excess and daily reasons combine without double depositing")
apply();Gold:Close();Gold:Open();check(#requests==1,"combined success satisfies daily contribution")
local oldTime=timestamp;p.resetHour=6;timestamp=100*86400+5*3600
check(Gold:DayKey(p)==99,"UTC reset applies before configured hour")
timestamp=100*86400+6*3600;check(Gold:DayKey(p)==100,"UTC reset changes at configured hour");timestamp=oldTime

reset(12000);cfg=spec("standing");cfg.max=nil;cfg.fixed=5000;cfg.threshold=10000;p=save(cfg);Gold:Open()
check(#requests==0,"fixed deposit is skipped if full amount would breach carried minimum")
reset(12000);cfg=spec("standing");cfg.max=nil;cfg.fixed=1000;cfg.threshold=12000;p=save(cfg);Gold:Open()
check(#requests==0,"deposit threshold is strictly over the configured amount")
reset(15000);cfg=spec("standing");cfg.max=nil;cfg.fixed=1000;cfg.threshold=12000;p=save(cfg);Gold:Open();apply();Gold:Close();Gold:Open()
check(#requests==2,"per-visit contribution can recur at the next eligible opening")

reset();p=save(spec());Gold:Open();mockCharacterGold=30001;Gold:Confirm()
check(#requests==0 and Gold.data.visit.state=="skipped","changed balance invalidates an approved proposal")
reset();cfg=spec("standing");p=save(cfg);capacity=0;Gold:Open()
check(#requests==0 and Gold.data.visit.state=="skipped","game currency capacity checked before request")

reset();cfg=spec("limited");cfg.unitsLeft=20000;cfg.movesLeft=2;p=save(cfg);Gold:Open()
mockCharacterGold=20000;mockBankGold=109999;timestamp=timestamp+5;Gold:Observe()
check(Gold.data.holds[characterId] and p.unitsLeft==20000 and p.movesLeft==2,"mismatched receipt holds without spending an unverified allowance")
Gold:Close();Gold:Open();check(#requests==1,"review hold prevents later automatic retries")
assert(Gold:ReleaseHold(characterId));check(p.mode=="ask","clearing a checked hold revokes automatic approval")
Gold:Close();mockCharacterGold=30000;mockBankGold=100000;Gold:Open()
check(Gold.current and #requests==1,"fresh bank visit requires confirmation after review")

reset();p=save(spec("standing"));Gold:Open();Gold.pending=nil;Gold:Open()
check(Gold.data.holds[characterId] and #requests==1,"persisted in-flight intent holds after reload rather than replaying")
reset();p=save(spec("standing"));Gold:Open();bankOpen=false;Gold:Close()
check(Gold.data.holds[characterId] and not Gold.data.visit.open,"closing bank mid-transfer preserves a review hold")

reset();p=save(spec("standing"));R.current={};Gold:Open()
check(#requests==0 and not Gold.current,"item confirmation has priority over gold")
R.current=nil;Gold:Tick();check(#requests==1,"gold starts after item queue settles")
apply()
reset();p=save(spec("standing"));R.data.visit.queue={{status="queued"}};Gold:Open()
check(#requests==0,"unprocessed item queue blocks premature gold proposal")
R.data.visit.queue[1].status="skipped";Gold:Tick();check(#requests==1,"skipped item queue can hand control to gold")
apply()
reset();p=save(spec("standing"));GridBagsRoutingUI.editingSession=true;Gold:Open()
check(#requests==0,"item rule editing pauses gold too");GridBagsRoutingUI.editingSession=false
Gold:Tick();check(#requests==1,"closing item editor releases the gold scheduler")
apply()

reset();p=save(spec());Gold:Open();Gold:Skip();Gold:Tick();Gold:Open()
check(#requests==0 and Gold.data.visit.state=="skipped","gold skip applies to the whole current opening")
reset();p=save(spec());Gold:Open();cfg=spec("standing");assert(Gold:SaveProfile(characterId,cfg,0));Gold:Tick()
check(#requests==0 and Gold.data.visit.state=="changed","editing policy cancels old frozen proposal until next opening")
Gold:Close();Gold:Open();check(#requests==1,"edited policy applies to next opening")
apply()

reset();BMR={};save(spec("standing"));Gold:Open();check(#requests==0,"BankManager overlap blocks automatic gold");BMR=nil
reset();cfg=spec();cfg.max=9999;check(not Gold:ValidateProfile(cfg),"inverted gold limits rejected")
cfg=spec();cfg.fixed=5000;cfg.cap=1000;check(not Gold:ValidateProfile(cfg),"fixed contribution cannot be silently truncated by cap")
cfg=spec("limited");check(not Gold:ValidateProfile(cfg),"limited mode requires a visible counter")
cfg=spec("limited");cfg.movesLeft=1;check(Gold:ValidateProfile(cfg).unitsLeft==nil,"one blank allowance counter means unlimited")
cfg=spec();cfg.resetHour=24;check(not Gold:ValidateProfile(cfg),"invalid daily reset rejected")

reset();p=save(spec("standing"))
ZO_Dialogs_ShowDialog=function(name)mockCurrencyDialog=name end
Gold:Manual("deposit");check(mockCurrencyDialog=="BANK_DEPOSIT_GOLD" and #requests==0,"manual deposit opens ESO's native currency selector")
Gold:Open();check(#requests==0,"manual currency action before scheduler starts suppresses automatic gold this visit")
Gold:Manual("withdraw");check(mockCurrencyDialog=="BANK_WITHDRAW_GOLD","manual withdrawal opens native currency selector")
bankOpen=false;mockCurrencyDialog=nil;Gold:Manual("deposit")
check(mockCurrencyDialog==nil,"manual currency button cannot act outside a personal bank")

reset();UI:Show();UI.enabled=true;UI.mode="ask";UI.frequency="daily"
UI.edits.min:SetText("10000");UI.edits.max:SetText("20000");UI.edits.fixed:SetText("2500")
UI.edits.threshold:SetText("12000");UI.edits.cap:SetText("5000");UI.edits.resetHour:SetText("6")
UI.previewButton.handlers.OnClicked()
check(UI.preview.text:find("deposit 5,000",1,true) and #requests==0,"form preview uses unsaved values without executing")
UI.saveButton.handlers.OnClicked()
check(Gold:Profile(characterId).fixed==2500 and Gold:Profile(characterId).resetHour==6,"gold editor saves daily min/max policy")
UI.edits.min:TakeFocus();UI:Close();check(not UI.edits.min.focused,"gold editor releases typing focus on close")
Gold:Close();Gold:Open();check(Gold.current and #requests==0,"saved Ask policy presents confirmation after reopening bank")
Gold:Skip()

-- Separate native inventory/banking layouts and their lock state.
bankOpen=false;G.sceneName="inventory";G.saved.layouts=nil;G:Refresh()
check(L:Get("inventory").locked and L:Get("bank").locked and not G.root.movable,"both layouts default locked")
L:SetLocked("inventory",false)
L.header.handlers.OnMouseDown(L.header,MOUSE_BUTTON_INDEX_LEFT)
check(L.moving and G.root.moving,"unlocked header starts drag")
G.root.mockLeft=333;G.root.mockTop=222
local anchor=G.root.anchors[1]
G:Refresh();check(G.root.anchors[1]==anchor,"inventory refresh does not reanchor a dragged window")
L.header.handlers.OnMouseUp()
check(not L.moving and L:Get("inventory").x==333/GuiRoot:GetWidth(),"drag completion saves inventory position")
bankOpen=true;G.sceneName="bank";G:Refresh()
check(G.root.anchors[1][1]==CENTER and not G.root.movable,"bank retains its separate default position and lock")
L:SetLocked("bank",false);L.header.handlers.OnMouseDown(L.header,1)
G.root.mockLeft=111;G.root.mockTop=100;L.header.handlers.OnMouseUp()
check(L:Get("bank").x==111/GuiRoot:GetWidth() and L:Get("inventory").x==333/GuiRoot:GetWidth(),"bank drag does not overwrite inventory position")
L:SetLocked("inventory",true);bankOpen=false;G.sceneName="inventory";G:Refresh()
check(not G.root.movable and G.root.anchors[1][4]==333 and G.root.anchors[1][5]==222,"inventory restores saved position and lock")
L.header.handlers.OnMouseDown(L.header,1);check(not L.moving,"locked header cannot start drag")
L:Get("inventory").x=10;L:Get("inventory").y=-5;L:Apply()
check(G.root.anchors[1][4]<=GuiRoot:GetWidth()-G.root:GetWidth()*G.root:GetScale()+0.001 and G.root.anchors[1][5]==0,"off-screen saved position clamped after size/resolution changes")
L:Reset("inventory");check(G.root.anchors[1][1]==RIGHT and L:Get("bank").x~=nil,"reset affects only selected layout")
bankOpen=true;G.sceneName="bank";G:Refresh()
check(not G.depositCurrency:IsHidden() and not G.withdrawCurrency:IsHidden(),"bank grid exposes both native currency buttons")
bankOpen=false;G.sceneName="inventory";G:Refresh()
check(G.depositCurrency:IsHidden() and G.withdrawCurrency:IsHidden(),"currency buttons hidden outside banker")
print("PASS: "..checks.." gold policy/receipt, native currency and layout checks (Lua 5.1 mock).")
