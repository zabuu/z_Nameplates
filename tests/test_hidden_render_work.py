"""Execute actual render/layout paths for projection gaps and overlap labels."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")
plates = (ROOT / "nameplates.lua").read_text(encoding="utf-8-sig")
sticky = (ROOT / "sticky.lua").read_text(encoding="utf-8-sig")
tree = ast.parse((ROOT / "tests/test_sticky_placement.py").read_text())
boot = next(ast.literal_eval(n.value.args[0]) for n in tree.body
            if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
            and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(boot)
lua.execute("local Z=zNameplates\n" + core[core.index("function Z.IsPlateUnitCurrent("):
                                        core.index("-- zAPI projects in the native WorldFrame")])
lua.execute(sticky)
lua.execute('''
nameplates={}; cfg={}; frameState={}; visuals=0; alphaWrites=0; clockReads=0
ApplyDistanceEffects=function(p) visuals=visuals+1; p:SetAlpha(1); p.cachedAlpha=1 end
function a:SetAlpha(v) self.alpha=v; alphaWrites=alphaWrites+1 end
function a.clusterAlpha(self,v) self.alpha=v end
a.clusterCountFrame={alpha=1,GetAlpha=function(self) return self.alpha end,SetAlpha=a.clusterAlpha}
a.eventcache=true; a.auraUpdate=true; a.castUpdate=true; a.targetUpdate=true
a.losNextSample=100
''')
start = plates.index("  nameplates.OnUpdate = function(frame, state, visualOnly)")
end = plates.index("    if visualOnly then return end", start) + len("    if visualOnly then return end")
lua.execute(plates[start:end] + "\nend")
lua.execute('''
update(0); nameplates.OnUpdate(a.parent,{now=0},true); assert(visuals==1 and a.alpha==1)
-- Short gaps still render the held anchor throughout the existing grace.
a.px=nil; update(.05); nameplates.OnUpdate(a.parent,{now=.05},true)
assert(not a.worldPlacementHidden and visuals==2)
update(.13); nameplates.OnUpdate(a.parent,{now=.13},false)
assert(a.worldPlacementHidden and visuals==2 and a.alpha==0 and a.clusterCountFrame.alpha==0)
assert(a.eventcache and a.auraUpdate and a.castUpdate and a.targetUpdate and not a.losNextSample)
local writes=alphaWrites
for i=1,120 do update(1+i/120); nameplates.OnUpdate(a.parent,{now=clock},false) end
assert(visuals==2 and alphaWrites==writes)
-- No throttling of projection/layout: reappearance renders on this very tick.
a.px=230; update(3); nameplates.OnUpdate(a.parent,{now=3},true)
assert(not a.worldPlacementHidden and visuals==3 and a.alpha==1)
assert(a.stickyPlacement.baseX==230 and a.eventcache and a.auraUpdate)
-- A recycled stale slot is hidden through the same fast path.
a.worldPlacementHidden=true; a.cachedGuid="replacement"
nameplates.OnUpdate(a.parent,{now=3.01},false); assert(visuals==3 and a.alpha==0)
''')

# Exercise the actual normal path through event dispatch too. Hidden metadata
# (especially tap ownership used by cluster keys) must still refresh immediately.
full_end = plates.index("  -- ============================================================================\n  -- DEDICATED TARGET CASTBAR FRAME", start)
lua.execute(plates[start:full_end])
lua.execute('''
zNameplates.throttle={Get=function() return 0 end}; visiblePlateCount=1
a.castbar={IsShown=function() return false end}; a.original={name={GetText=function() return "unit" end}}
a.eventcache=true
function nameplates:OnDataChanged(p) assert(p==a); error("hidden metadata refreshed") end
local ok,reason=pcall(nameplates.OnUpdate,a.parent,{now=3.02},false)
assert(not ok and string.find(reason,"hidden metadata refreshed",1,true))
assert(visuals==3)
''')

lua.execute('''
visible={}; pack={}; scaleReads=0; overlap=true
for i=1,50 do
 local p=add("friend"..i,100+i,200)
 function p:GetEffectiveScale() scaleReads=scaleReads+1; return 1 end
 pack[i]=p
end
update(5); local initial=scaleReads
for i=1,120 do
 for j,p in ipairs(pack) do p.px=100+j+i*.1 end
 update(5+i/120)
 for _,p in ipairs(pack) do render(p,clock) end
end
assert(scaleReads==initial) -- 6,000 unused native scale reads removed.
assert(math.abs(pack[1].stickyPlacement.baseX-113)<.001)
-- Switching to avoidance refreshes dimensions/scale before using them.
overlap=false; update(7); assert(scaleReads>initial)
assert(pack[1].stickyPlacement.avoidance and pack[1].stickyPlacement.w>=20)
''')
print("PASS projection grace, 120 invisible frames with zero visual/LOS work, immediate hidden metadata events, immediate return/recycle, 6,000 unused scale reads avoided, avoidance restoration")
