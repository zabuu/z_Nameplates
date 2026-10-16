"""Real render loop: fresh camera order, shared projections and no target bias."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
tree = ast.parse((root / "tests/test_single_owner_layout.py").read_text(encoding="utf-8-sig"))
bootstrap = next(ast.literal_eval(n.value.args[0]) for n in tree.body
                 if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
                 and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(bootstrap)
lua.execute("local Z=zNameplates\n" + core[core.index("function Z.GetPlateProjection("):
                                          core.index("Z.throttle = {}")])
lua.execute((root / "sticky.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
visiblePlates=visible; visiblePlateCount=50; depthPlates={}; plateRank={}; frameState={}
checks=0; writes=0; sorts=0; assignments=0; visualOnlyCalls=0; renderCalls=0
fallbacks=0; legacyReads=0; pool={}; layers={}
for i=1,50 do
 local p,u=add("nameplate"..i,"guid"..i,200+i*5,300+i,true)
 u.depth=10+i*2; pool[i]=p
end
-- Sorting must never perform screen-space overlap geometry queries.
for _,p in ipairs(pool) do
 function p:GetLeft() assert(not inDepthCheck,"depth queried a screen rectangle"); return 100 end
 function p:GetRight() assert(not inDepthCheck,"depth queried a screen rectangle"); return 200 end
 function p:GetTop() assert(not inDepthCheck,"depth queried a screen rectangle"); return 320 end
 function p:GetBottom() assert(not inDepthCheck,"depth queried a screen rectangle"); return 300 end
end
local sort=table.sort
table.sort=function(t,less)
 if less==Z.PlateDepthLess then sorts=sorts+1 end
 return sort(t,less)
end
local assign=Z.AssignStablePlateDepthRanks
Z.AssignStablePlateDepthRanks=function(...) assignments=assignments+1; return assign(...) end
local api=zAPI
zAPI=function(command,...)
 if command=="unitPosition" or command=="worldToScreen" then fallbacks=fallbacks+1 end
 return api(command,...)
end
ExactUnitDistance=function(unit) legacyReads=legacyReads+1; return units[unit] and units[unit].depth end
SetPlateDepthLayer=function(p,strata,base)
 checks=checks+1
 if p.cachedStrata~=strata or p.cachedBaseLevel~=base then
  writes=writes+1; p.layerSetAt=frameState.now
  p.cachedStrata,p.cachedBaseLevel=strata,base
 end
end
ShouldOverlap=function() return true end
Z.UpdatePlateClusters=function() return false end
RefreshVisibleNameplatePool=function() error("unexpected visibility refresh") end
nameplates={}
function nameplates:SetScript(k,f) self[k.."Script"]=f end
function nameplates.OnUpdate(parent,state,visualOnly)
 local p=parent.nameplate
 if p.clusterHidden then return end
 p.istarget=p.cachedGuid==state.targetGuid or nil
 Z.UpdatePlateTransition(p,state.now)
 if visualOnly then visualOnlyCalls=visualOnlyCalls+1 end
end
''')
depth = plates[plates.index("  local function GetUnitDepth("):
               plates.index("  local function SaveVisualColor(")]
# The real depth routine uses real cached/native depth reads; substitute only
# the tree-writing bridge, which is tested with native cascades in other suites.
start = depth.index("  local function SetPlateDepthLayer(")
end = depth.index("  local function UpdateNameplateDepthLayers(", start)
depth = depth[:start] + depth[end:]
lua.execute(depth + "\ndepthUpdate=UpdateNameplateDepthLayers")
lua.execute('''
UpdateNameplateDepthLayers=function(...)
 inDepthCheck=true; depthUpdate(...); inDepthCheck=false
end
''')
central = plates[plates.index('  nameplates:SetScript("OnUpdate", function()'):
                 plates.index("  -- combat tracker")]
lua.execute(central)
lua.execute('''
function render(t,fast)
 clock=t; this=nameplates
 if fast then nameplates.frameTick=t end
 nameplates.OnUpdateScript(); renderCalls=renderCalls+1
end
function ordered()
 for i=2,#depthPlates do assert(not Z.PlateDepthLess(depthPlates[i],depthPlates[i-1])) end
end
-- 50 plates / 120 FPS: one projection per plate/frame, one initial sort only.
for tick=0,119 do
 for i,p in ipairs(pool) do units[p.unit].depth=10+i*2+tick*.01 end
 render(tick/120); ordered()
end
assert(nativeCalls==6000 and sorts==1 and assignments==1 and writes==50)
assert(visualOnlyCalls>0 and fallbacks==0)
-- A crossing on the visual-only path updates layers in THIS rendered frame.
units.nameplate25.depth,units.nameplate26.depth=units.nameplate26.depth,units.nameplate25.depth
local before=nativeCalls; local previousWrites=writes
render(1.001,true); ordered()
assert(nativeCalls==before+50 and sorts==2 and assignments==2 and writes==previousWrites+2)
assert(pool[25].layerSetAt==1.001 and pool[26].layerSetAt==1.001)
previousWrites=writes
render(1.002,true); assert(sorts==2 and assignments==2 and writes==previousWrites)
-- Exact depth ties have a stable identity order, unaffected by target changes.
units.nameplate25.depth=units.nameplate26.depth
frameState.targetGuid=pool[25].cachedGuid; render(1.01,true); ordered()
local beforeSorts=sorts; previousWrites=writes
frameState.targetGuid=pool[26].cachedGuid; render(1.011,true); ordered()
assert(sorts==beforeSorts and writes==previousWrites)
-- Cluster/visibility membership changes are noticed without waiting for a
-- depth timer, and removing one plate never re-spaces unaffected survivors.
pool[10].clusterHidden=true; previousWrites=writes
render(1.02,true); assert(#depthPlates==49 and writes==previousWrites)
assert(not frameState.depthMembers[pool[10].parent])
pool[10].clusterHidden=nil; render(1.021,true); assert(#depthPlates==50); ordered()
-- Same pooled frame, new GUID: no duplicate entry or inherited old depth.
local p=pool[2]; local u=units[p.unit]
objects[u.guid]=nil; u.guid="replacement"; objects[u.guid]=u; p.cachedGuid=u.guid; u.depth=200
render(1.03,true); ordered()
assert(#depthPlates==50 and depthPlates[1].nameplate==p and p.depth==200)
assert(frameState.depthMembers[p.parent]=="replacement" and p.depthLayerIdentity=="replacement")
-- A visible native frame with a stale token must not remain in the ordering.
p=pool[3]; local oldUnit=units[p.unit]
units[p.unit]=nil; render(1.04,true)
assert(#depthPlates==49 and not frameState.depthMembers[p.parent])
units[p.unit]=oldUnit; render(1.041,true); assert(#depthPlates==50); ordered()
-- Projection gaps hold last depth for the existing short grace, then leave
-- the drawing order; neither stage calls the old native fallback chain.
p=pool[4]; u=units[p.unit]; local oldDepth=p.depth; u.projectable=false
render(1.05,true); assert(p.depth==oldDepth and #depthPlates==50 and fallbacks==0)
render(1.2,true); assert(p.worldPlacementHidden and #depthPlates==49 and fallbacks==0)
u.projectable=true; render(1.201,true); assert(not p.worldPlacementHidden and #depthPlates==50)
-- Recreated overlay state on the same native frame/GUID also gets a new slot.
p=pool[5]; p.depthIdentity=nil; p.depthLayerRank=nil
p.cachedStrata=nil; p.cachedBaseLevel=nil
local oldAssignments=assignments; render(1.202,true)
assert(assignments==oldAssignments+1 and p.depthLayerRank and p.cachedStrata)
-- Removing all plates clears membership references and supports a clean return.
for _,p in ipairs(pool) do p.parent.visible=false end
render(1.21,true); assert(#depthPlates==0 and not next(frameState.depthMembers))
for _,p in ipairs(pool) do p.parent.visible=true end
render(1.22,true); assert(#depthPlates==50); ordered()
-- Legacy clients retain bounded expensive fallback sampling, not 120 Hz reads.
zAPI=nil; Z.depthUpdateTime=nil; legacyReads=0; before=nativeCalls
for tick=0,119 do render(2+tick/120) end
assert(nativeCalls==before and legacyReads>=1000 and legacyReads<=1750)
ordered()
''')
print("Per-frame depth: shared projections at 120 FPS; same-frame visual-only crossings; stable ties/targets; no overlap geometry; no unnecessary sorts; cluster/pool/gap lifecycle; legacy cadence passed.")
