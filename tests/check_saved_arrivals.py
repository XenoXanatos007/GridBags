"""Read-only replay: saved inventories stand in for live observations in a mock."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
parser=argparse.ArgumentParser()
parser.add_argument('saved_variables',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((root/'tests/eso_mock.lua').read_text())
for name in (root/'GridBags/GridBags.txt').read_text().splitlines():
    if name.endswith('.lua') and name!='GridBags.lua':lua.execute((root/'GridBags'/name).read_text())
lua.globals().G=lua.execute((root/'GridBags/GridBags.lua').read_text()+'\nreturn G')
lua.execute('G:Initialize()')
lua.globals().saved=lua.eval('function(s)local e={};local f=assert(loadstring(s));setfenv(f,e);f();return e.GridBagsSavedVariables end')(args.saved_variables.read_text(encoding='utf-8-sig'))
lua.execute('''
local checked,completed,events=0,0,0
for _,profile in pairs(saved)do for _,account in pairs(profile)do for _,settings in pairs(account)do
 if type(settings)=='table'and settings.routing then for world,data in pairs(settings.routing)do
  local R,A=GridBagsRouting,GridBagsActivity
  R.data=data;R.pending=nil;if data.visit then data.visit.inFlight=nil end
  A.data={history={},errors={},backups={}}
  for id,record in pairs(settings.snapshots[world])do
   R.character=id;local inventory={[BAG_BACKPACK]={},[BAG_WORN]={}}
   for _,item in ipairs(record.items or {})do table.insert(inventory[BAG_BACKPACK],item)end
   for _,item in ipairs(record.equipment and record.equipment.items or {})do table.insert(inventory[BAG_WORN],item)end
   GetBagSize=function(bag)return #(inventory[bag]or {})end
   R.Read=function(_,bag,slot)local item=inventory[bag]and inventory[bag][slot+1]
    if item then return {uid=item.uid,maxStack=item.maxStack,qty=item.stack,bag=bag,slot=slot,link=item.link}end
   end
   local owned={};for _,items in pairs(inventory)do for _,item in ipairs(items)do if item.maxStack==1 and item.stack==1 then owned[item.uid]=true end end end
   local expected,before={},{}
   for _,p in ipairs(data.plans)do
    before[p.id]=p.state;local uid=p.bankUid or p.uid
    if p.dest==id and p.maxStack==1 and p.qty==1 and p.remaining==1 and type(uid)=='string'and uid:match('^%d+$')and uid~='0'and owned[uid]
     and (p.state=='source'or p.state=='bank'or(p.state=='review'and p.reserve and p.reasonCode=='RESERVATION_MISSING'))then expected[p.id]=true end
   end
   local n=R:ReconcileArrivals();local count=0
   for _,p in ipairs(data.plans)do
    if expected[p.id]then assert(p.state=='done'and p.remaining==0 and not p.reserve);count=count+1
    else assert(p.state==before[p.id],'unrelated state changed')end
   end
   assert(n==count);assert(R:ReconcileArrivals()==0,'not idempotent')
   checked=checked+1;completed=completed+n
  end
  events=events+#A.data.history
 end end
end end end
print('PASS: '..checked..' saved inventories replayed as mocked live observations; '..completed..' delivery records reconciled in '..events..' unique-item arrival events. Save file untouched.')
''')
