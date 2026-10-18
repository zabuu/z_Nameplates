"""Sort-function allocation counts, exact comparison parity and scene ownership."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "sticky.lua").read_text(encoding="utf-8-sig")
core = (root / "core.lua").read_text(encoding="utf-8-sig")
tree = ast.parse((root / "tests/test_sticky_placement.py").read_text(encoding="utf-8-sig"))
bootstrap = next(ast.literal_eval(n.value.args[0]) for n in tree.body
                 if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
                 and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")


def runtime(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(bootstrap)
    lua.execute("local Z=zNameplates\n" + core[core.index("function Z.IsPlateUnitCurrent("):
                                               core.index("-- zAPI projects in the native WorldFrame")])
    lua.execute(code)
    return lua


def measure_comparators(code):
    lua = runtime(code)
    lua.execute('''
visible={}; pack={}; functions={}; newFunctions=0; projections=0
local project=Z.GetPlateProjection
Z.GetPlateProjection=function(...) projections=projections+1; return project(...) end
for i=1,40 do pack[i]=add("enemy"..i,350,450) end
local original=table.sort
table.sort=function(list,less)
 if less and not functions[less] then functions[less]=true; newFunctions=newFunctions+1 end
 return original(list,less)
end
update(1); warmFunctions=newFunctions
for i=1,20 do update(1+i*.06) end
''')
    return {"warm": lua.globals().warmFunctions,
            "new_after_warmup": lua.globals().newFunctions - lua.globals().warmFunctions,
            "projections": lua.globals().projections}


counts = measure_comparators(source)
assert counts == {"warm": 41, "new_after_warmup": 0, "projections": 840}, counts
lua = runtime(source)
lua.execute('''
visible={}; pack={}; allPlates={}; previousFunctions={}
for i=1,40 do pack[i]=add("enemy"..i,350+i*.1,450); allPlates[i]=pack[i] end
local original=table.sort
table.sort=function(list,less)
 local owner
 for _,p in ipairs(allPlates) do
  if p.stickyPlacement and p.stickyPlacement.neighbors==list then owner=p.stickyPlacement end
 end
 if previousFunctions[list] then assert(previousFunctions[list]==less,"Comparator recreated on warm solve") end
 previousFunctions[list]=less
 -- Every comparison must match the original hover/distance/order expressions.
 for i=1,#list do for j=1,#list do
  local a,b=list[i],list[j]
  local expected
  if a.hovered~=b.hovered then expected=a.hovered
  elseif owner then
   local da=(owner.x-a.x)^2+(owner.y-a.y)^2
   local db=(owner.x-b.x)^2+(owner.y-b.y)^2
   if da==db then expected=a.order<b.order else expected=da<db end
  else expected=a.order<b.order end
  assert(less(a,b)==expected,"Comparator changed ordering")
 end end
 if owner then
  local x,y=owner.x,owner.y
  local a,b={x=0,y=0,hovered=false,order=2},{x=20,y=0,hovered=false,order=1}
  owner.x,owner.y=0,0; assert(less(a,b) and not less(b,a))
  owner.x=20; assert(not less(a,b) and less(b,a))
  owner.x=10; assert(not less(a,b) and less(b,a)) -- Equal distances: stable order.
  a.hovered=true; assert(less(a,b)) -- Hover priority still overrides distance/order.
  owner.x,owner.y=x,y
 end
 return original(list,less)
end
update(1)
for _,p in ipairs(pack) do assert(#p.stickyPlacement.neighbors==32) end
pack[1].layoutHoverReceiver=pack[1].parent
pack[2].isFriendly=true
for i=1,10 do
 pack[3].px=pack[3].px+.125; update(1+i*.06)
 assert(pack[1].stickyPlacement.hovered and pack[2].stickyPlacement.collisionFamily=="friendly")
 assert(#pack[2].stickyPlacement.neighbors==0)
end
-- Dummy scene comparators remain owned by that scene's states, never a shared
-- mutable "currently sorting" centre that could leak into the next live solve.
local live=visible; visible={}
local d1=add("dummy1",120,140); local d2=add("dummy2",120,140)
allPlates[#allPlates+1]=d1; allPlates[#allPlates+1]=d2
local preview=visible; visible=live; local scene={}
Z.UpdateStickyPlacements(2,preview,function() return false end,nil,nil,scene)
local comparator=d1.stickyPlacement.neighborOrder
Z.UpdateStickyPlacements(2.06,preview,function() return false end,nil,nil,scene)
assert(d1.stickyPlacement.neighborOrder==comparator)
update(2.12)
assert(pack[1].stickyPlacement.identity=="enemy1" and d1.stickyPlacement.identity=="dummy1")
-- Recycled identities get a new state/comparator; the self-capturing old
-- comparator is collectable once the solver and its neighbor lists let it go.
local old=pack[4].stickyPlacement
retired=setmetatable({old},{__mode="v"})
pack[4].cachedGuid="replacement"; update(2.18); update(2.24)
assert(pack[4].stickyPlacement~=old and pack[4].stickyPlacement.neighborOrder~=old.neighborOrder)
table.sort=original; previousFunctions=nil; old=nil
''')
lua.execute("collectgarbage('collect'); collectgarbage('collect'); assert(retired[1]==nil)")
print(f"Sticky comparator cache: {counts}; comparison parity, hover/family/32-neighbor rules, preview and cleanup passed.")
