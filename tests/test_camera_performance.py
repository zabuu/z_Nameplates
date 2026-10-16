"""Camera movement retains rank slots, single anchors and resting layout state."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")


def bootstrap(filename):
    tree = ast.parse((root / "tests" / filename).read_text(encoding="utf-8-sig"))
    return next(ast.literal_eval(n.value.args[0]) for n in tree.body
                if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
                and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")


rank_source = core[core.index("function Z.AssignStablePlateDepthRanks("):
                   core.index("function Z.SuppressNativePlateVisuals(")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("Z={}; zNameplates=Z")
lua.execute(rank_source)
lua.execute('''
function make(id) return {nameplate={cachedGuid=id}} end
function check(pack,ranks)
 for i=1,#pack do
  assert(ranks[i]>=1 and ranks[i]<=100 and ranks[i]==math.floor(ranks[i]))
  if i>1 then assert(ranks[i]>=ranks[i-1]) end
  if i>1 and #pack<=100 then assert(ranks[i]>ranks[i-1]) end
 end
end
pack={}; saved={}
for i=1,30 do pack[i]=make("g"..i) end
ranks=Z.AssignStablePlateDepthRanks(pack,#pack)
local scratch=Z.depthRankState.slots
for _,p in ipairs(pack) do saved[p]=p.nameplate.depthLayerRank end
for tick=1,120 do
 local r=Z.AssignStablePlateDepthRanks(pack,#pack,ranks)
 assert(r==ranks and Z.depthRankState.slots==scratch)
 check(pack,r)
 for _,p in ipairs(pack) do assert(p.nameplate.depthLayerRank==saved[p]) end
end
-- Removal never re-spaces the survivors. A new plate fits the freed/local gap.
table.remove(pack,12)
check(pack,Z.AssignStablePlateDepthRanks(pack,#pack,ranks))
for _,p in ipairs(pack) do assert(p.nameplate.depthLayerRank==saved[p]) end
local newcomer=make("new"); table.insert(pack,12,newcomer)
check(pack,Z.AssignStablePlateDepthRanks(pack,#pack,ranks))
for _,p in ipairs(pack) do if p~=newcomer then assert(p.nameplate.depthLayerRank==saved[p]) end end
-- Adjacent units crossing in depth swap only their own slots.
local a,b=pack[5],pack[6]; pack[5],pack[6]=b,a
check(pack,Z.AssignStablePlateDepthRanks(pack,#pack,ranks))
assert(a.nameplate.depthLayerRank==saved[b] and b.nameplate.depthLayerRank==saved[a])
for i,p in ipairs(pack) do
 if p~=newcomer and p~=a and p~=b then assert(p.nameplate.depthLayerRank==saved[p]) end
end
-- Recycled frames don't carry an old unit's allocation into a different place.
pack[4].nameplate.cachedGuid="recycled"
check(pack,Z.AssignStablePlateDepthRanks(pack,#pack,ranks))
assert(pack[4].nameplate.depthLayerIdentity=="recycled")
-- Dense/no-gap and over-budget scenes remain bounded, including recovery.
for _,count in ipairs({100,99,100,150,30}) do
 local big={}; for i=1,count do big[i]=make("big"..i) end
 local r=Z.AssignStablePlateDepthRanks(big,count,ranks); check(big,r)
 for i=1,math.min(20,count) do big[i],big[count-i+1]=big[count-i+1],big[i] end
 check(big,Z.AssignStablePlateDepthRanks(big,count,ranks))
 table.remove(big,math.ceil(count/2))
 check(big,Z.AssignStablePlateDepthRanks(big,#big,ranks))
 table.insert(big,2,make("inserted"))
 check(big,Z.AssignStablePlateDepthRanks(big,#big,ranks))
end
''')

# Integrate the actual depth routine with real layer setters, including native
# cascades. Absolute depth moves; unchanged relative order writes zero layers.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(bootstrap("test_plate_layers.py"))
lua.execute("Z=zNameplates\n" + rank_source)
lua.execute(core[core.index("function Z.ShouldUpdatePlateDepth("):core.index("function Z.AssignStablePlateDepthRanks(")])
lua.execute((root / "layers.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
visiblePlates={}; visiblePlateCount=0; pack={}; frameState={now=0}
depthPlates={}; DEPTH_STRATAS={"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG"}
plateLeft={}; plateRight={}; plateTop={}; plateBottom={}; plateStrata={}; plateRank={}
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
C_NamePlate=nil
Z.IsPlateUnitCurrent=function() return true end
GetUnitDepth=function(p) return p.testDepth end
SetPlateDepthLayer=function(p,s,b) Z.ApplyPlateLayers(p,s,b,frameState.now) end
for i=1,30 do
 local native=frame(); local p=frame(native); p.parent=native; native.nameplate=p
 p.cachedGuid=string.format("0x%08X",i); p.testDepth=20+i*2; p.screenX=i*200
 p.health=frame(p); p.health.backdrop=frame(p.health)
 p.textframe=frame(p); p.name={zSmoothFrame=frame(p.textframe)}
 p.guild={zSmoothFrame=frame(p.textframe)}; p.level={zSmoothFrame=frame(p.textframe)}
 p.castbar=frame(p.health); p.debuffs={frame(p)}; p.debuffs[1].cd=frame(p.debuffs[1])
 p.debuffs[1].cd.zText=frame(p.debuffs[1]); p.chatLabel=frame(p)
 p.raidiconframe=frame(p); p.clusterCountFrame=frame(native)
 function p:GetLeft() return self.screenX-50 end
 function p:GetRight() return self.screenX+50 end
 function p:GetTop() return 120 end
 function p:GetBottom() return 100 end
 visiblePlates[native]=native; pack[i]=p
end
''')
depth_source = plates[plates.index("  local function UpdateNameplateDepthLayers("):
                      plates.index("  local function SaveVisualColor(")]
lua.execute(depth_source + "\nupdateDepth=UpdateNameplateDepthLayers")
lua.execute('''
updateDepth(); local before=writes
for tick=1,60 do
 frameState.now=tick/60
 for i,p in ipairs(pack) do p.testDepth=20+i*2+tick*.5 end
 updateDepth()
end
assert(writes==before,"unchanged order still rewrites layers")
local saved={}
for _,p in ipairs(pack) do saved[p]={p.cachedStrata,p.cachedBaseLevel} end
pack[8].testDepth,pack[9].testDepth=pack[9].testDepth,pack[8].testDepth
frameState.now=2; updateDepth()
local changed=0
for _,p in ipairs(pack) do
 if saved[p][1]~=p.cachedStrata or saved[p][2]~=p.cachedBaseLevel then changed=changed+1 end
end
assert(changed==2,"a two-plate crossing reshuffled "..changed.." plates")
-- Screen overlap and target selection must not override true camera depth.
pack[29].screenX=pack[30].screenX
frameState.now=2.1; updateDepth()
local front,back=pack[29],pack[30]
assert(front.depth<back.depth and front.depthLayerRank>back.depthLayerRank)
before=writes; frameState.now=2.2; updateDepth(); assert(writes==before)
local old=back.cachedStrata; back.istarget=true; frameState.now=2.3; updateDepth()
assert(back.cachedStrata==old and writes==before)
back.istarget=nil; pack[29].screenX=pack[29].screenX+200
frameState.now=2.4; updateDepth()
assert(writes==before)
-- Complete layer bands never interleave, even at adjacent rank slots.
local strata={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5}
for rank=1,99 do
 local a,baseA=Z.GetPlateDepthLayer(rank)
 local b,baseB=Z.GetPlateDepthLayer(rank+1)
 assert(baseA+11<255 and baseB+11<255)
 assert(strata[a]<strata[b] or (a==b and baseA+11<baseB))
end
for _,p in ipairs(pack) do
 assert(p.chatLabel:GetFrameLevel()==p.cachedBaseLevel+11)
 assert(p.debuffs[1].cd.zText:GetFrameLevel()==p.cachedBaseLevel+6)
end
''')

# Run actual projection/solver/transition code at 120 FPS. Only one point clear
# is needed per identity/reference; motion still gets every rendered position.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(bootstrap("test_single_owner_layout.py"))
lua.execute("local Z=zNameplates\n" + core[core.index("function Z.GetPlateProjection("):
                                          core.index("Z.throttle = {}")])
lua.execute((root / "sticky.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
local p,u=add("nameplate1","moving",400,300,true)
clears=0; anchors=0; damping=0
function p:ClearAllPoints() clears=clears+1 end
local point=p.SetPoint
function p:SetPoint(...) anchors=anchors+1; return point(self,...) end
local exp=math.exp
math.exp=function(v) damping=damping+1; return exp(v) end
for tick=0,119 do
 clock=tick/120; u.x=400+tick*.25; u.y=300+tick*.3
 Z.UpdateStickyPlacements(clock,visible,function() return true end)
 Z.UpdatePlateTransition(p,clock)
 near(p.anchorX*p.scale,u.x); near((p.anchorY-8)*p.scale,u.y)
end
assert(nativeCalls==120 and anchors==120 and clears==1)
assert(damping==0) -- A resting avoidance displacement needs no spring work.
-- Explicit config invalidation or a recycled identity still clears anchors.
p.positionTransition.appliedX=nil; clock=2; Z.UpdatePlateTransition(p,clock)
assert(clears==2)
u.guid="replacement"; p.cachedGuid=u.guid; objects[u.guid]=u
clock=3; Z.UpdateStickyPlacements(clock,visible,function() return true end)
Z.UpdatePlateTransition(p,clock); assert(clears==3)
-- Real relocation still moves smoothly, then rests exactly at home.
local s=p.stickyPlacement; s.displayX=20; s.displayY=40; s.vx=0; s.vy=0
s.dx=0; s.dy=0; s.returningHome=true
local oldX=s.displayX; Z.ApplyStickyPlacement(p,3.01,nil,nil,uiScale,p.scale)
assert(s.displayX<oldX and s.displayX>oldX-1.401 and damping==1)
for tick=2,400 do Z.ApplyStickyPlacement(p,3+tick*.01,nil,nil,uiScale,p.scale) end
assert(s.displayX==0 and s.displayY==0 and s.vx==0 and s.vy==0)
local before=damping
for tick=401,520 do Z.ApplyStickyPlacement(p,3+tick*.01,nil,nil,uiScale,p.scale) end
assert(damping==before)
''')

# A world-owned camera gap must not trigger the old native fallback chain.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; zNameplates=Z; frameState={now=1}; nativeFallbacks=0
Z.GetPlateProjection=function() return nil end
zAPI=function(command)
 nativeFallbacks=nativeFallbacks+1
 if command=="unitPosition" then return 1,2,3 end
 if command=="worldToScreen" then return .2,.3,60 end
 error(command)
end
''')
depth_getter = plates[plates.index("  local function GetUnitDepth("):
                      plates.index("  local function SetPlateDepthLayer(")]
lua.execute(depth_getter + "\ngetDepth=GetUnitDepth")
lua.execute('''
local p={cachedGuid="guid",unit="nameplate1",worldPlacementOwned=true,depth=12}
for i=1,120 do assert(getDepth(p)==12) end
assert(nativeFallbacks==0)
p.depth=nil; assert(getDepth(p)==40 and nativeFallbacks==0)
p.worldPlacementOwned=false; assert(getDepth(p)==60 and nativeFallbacks==2)
Z.GetPlateProjection=function() return .2,.3,15 end
p.worldPlacementOwned=true; assert(getDepth(p)==15 and nativeFallbacks==2)
''')

# Displaced target/hover guide dots keep working, without re-clearing anchors,
# re-layering, or re-writing an unchanged native single-precision scale.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={}}}; zNameplates=Z; UIParent={}
linkLayers=0; linkScales=0; dotAnchors=0; linkHides=0; dotClears=0
local methods={}
function methods:EnableMouse() end
function methods:SetWidth() end
function methods:SetHeight() end
function methods:SetTexture() end
function methods:SetVertexColor() end
function methods:GetScale() return self.scale end
function methods:SetScale(s) self.scale=s+.00000001; linkScales=linkScales+1 end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level=v; linkLayers=linkLayers+1 end
function methods:GetFrameStrata() return self.strata end
function methods:SetFrameStrata(v) self.strata=v; linkLayers=linkLayers+1 end
function methods:SetPoint(...) dotAnchors=dotAnchors+1 end
function methods:ClearAllPoints() dotClears=dotClears+1 end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown=false; linkHides=linkHides+1 end
function methods:Show() self.shown=true end
function methods:CreateTexture() return CreateFrame() end
function CreateFrame() return setmetatable({scale=1,level=0,strata="BACKGROUND",shown=true},{__index=methods}) end
p=CreateFrame(); p.parent={GetEffectiveScale=function() return 1 end}
p.level=20; p.strata="LOW"; p.istarget=true
p.stickyPlacement={baseX=100,baseY=100,displayX=30,displayY=30,dx=30,dy=30,vx=0,vy=0}
''')
lua.execute((root / "sticky.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
Z.ApplyStickyPlacement(p,0,nil,nil,.9,.9)
assert(dotAnchors==12 and dotClears==0 and p.layoutAnchorLink:IsShown())
local layers,scales=linkLayers,linkScales
for i=1,120 do Z.ApplyStickyPlacement(p,i/120,nil,nil,.9,.9) end
assert(dotAnchors==12 and linkLayers==layers and linkScales==scales)
p.stickyPlacement.baseX=105; Z.ApplyStickyPlacement(p,2,nil,nil,.9,.9)
assert(dotAnchors==24 and dotClears==0)
p.istarget=false
for i=1,120 do Z.ApplyStickyPlacement(p,2+i/120,nil,nil,.9,.9) end
assert(linkHides==1 and not p.layoutAnchorLink:IsShown())
p.istarget=true; p.level=30; Z.ApplyStickyPlacement(p,4,nil,nil,.9,.9)
assert(p.layoutAnchorLink:IsShown() and linkLayers==layers+1)
''')

# LOS existence checks follow the existing 10 Hz phased raycasts instead of
# making 6,000 redundant native UnitExists calls for 50 plates at 120 FPS.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; zNameplates=Z; abs=math.abs; existsReads=0; rays=0; transitions=0
Z.RepairPlateTextLayers=function() end
Z.UpdatePlateTransition=function() transitions=transitions+1 end
SetLineOfSightDesaturation=function() end
UIParent={GetScale=function() return 1 end}
cfg={distance_scale=false,distance_alpha=false,los_fade=true,distance_unitxp=true,distance_min_alpha=.4}
UnitExists=function(u) existsReads=existsReads+1; return u~="missing" end
UnitXP=function(cmd,a,b) rays=rays+1; assert(cmd=="inSight"); return inSight~=false end
pack={}
for i=1,50 do
 local p={unit="nameplate"..i,cachedGuid=string.format("0x%08X",i)}
 function p:SetScale(s) self.scale=s end
 function p:SetAlpha(a) self.alpha=a end
 pack[i]=p
end
''')
visual = plates[plates.index("  local function ApplyDistanceEffects("):
                plates.index("  local function RefreshVisibleNameplatePool(")]
lua.execute(visual + "\nvisual=ApplyDistanceEffects")
lua.execute('''
for tick=0,119 do for _,p in ipairs(pack) do visual(p,tick/120,1) end end
assert(transitions==6000 and rays==existsReads and existsReads>=500 and existsReads<=550)
local p=pack[1]; inSight=false; visual(p,2,1); assert(p.losOutOfSight)
local before=existsReads; visual(p,2.001,1); assert(existsReads==before)
p.unit="nameplate51"; p.cachedGuid="new"; visual(p,2.002,1)
assert(existsReads==before+1 and p.losOutOfSight) -- New identity is immediate.
p.unit=nil; visual(p,2.003,1); assert(not p.losOutOfSight and not p.losNextSample)
p.unit="missing"; p.cachedGuid="gone"; before=rays; visual(p,3,1)
assert(rays==before and not p.losOutOfSight)
local reads=existsReads; visual(p,3.001,1); assert(existsReads==reads)
cfg.los_fade=false; visual(p,3.002,1); assert(not p.losNextSample)
''')
print("Camera performance: stable depth slots and no layer writes for unchanged order; only two plates change on a crossing; 120 camera anchors/one clear; no damping at rest; LOS validation phased at 10 Hz with lifecycle safety passed.")
