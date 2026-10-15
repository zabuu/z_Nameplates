"""Run real central/visual/projection spans against the real optional recorder."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
recorder = (root.parent / "OctoPerf/OctoPerf.lua")
if not recorder.is_file():
    # OctoPerf is intentionally optional for public addon downloads.
    print("Optional recorder unavailable; source syntax checked by existing suites.")
    raise SystemExit(0)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
wall=1; clockReads=0; running=false; inWorld=true; warmUntil=0; captureSerial=1
clock=function() clockReads=clockReads+1; return wall end
GetTime=function() return wall end
P={}; OctoPerf=P; max=math.max; db={operations={}}
EnsureDB=function() return db end; Timestamp=function() return "test" end
Z={}; zNameplates=Z; cfg={distance_scale=true,distance_alpha=true,distance_min_scale=.5,
 distance_min_alpha=.4,distance_max_range=41,los_fade=true,distance_unitxp=true}
C={nameplates={vertical_offset="0"}}
frameState={}; visiblePlateCount=3; visiblePlates={}; units={}; parents={}
UIParent={GetScale=function() return 1 end}; abs=math.abs
UnitExists=function(u) return units[u]~=nil end
UnitGUID=function(u) return units[u] end
C_NamePlate={GetNamePlateForUnit=function(u) return parents[u] end}
zAPI=function(command)
 if command=="version" then return 1.9 end
 assert(command=="projectNameplate"); wall=wall+.0006
 return .5,.5,20,1,2,3
end
UnitXP=function() wall=wall+.0005; return true end
Z.RepairPlateTextLayers=function() wall=wall+.0001 end
Z.UpdatePlateTransition=function() wall=wall+.0003 end
SampleExactUnitDistance=function() wall=wall+.0004; return 20 end
SetLineOfSightDesaturation=function() wall=wall+.0001 end
RestoreLineOfSightColors=function() end
ShouldOverlap=function() return true end
Z.UpdatePlateClusters=function() wall=wall+.0001; return false end
Z.ShouldUpdatePlateDepth=function() return true end
UpdateNameplateDepthLayers=function() wall=wall+.002 end
RefreshVisibleNameplatePool=function() error("Unexpected refresh") end
nameplates={OnDataChanged=function() wall=wall+.0008 end}
function nameplates:SetScript(script,f) self[script.."Script"]=f end
for i=1,3 do
 local parent={IsVisible=function() return true end,EnableMouse=function() end}
 local p={unit="unit"..i,cachedGuid="guid"..i,parent=parent}
 function p:SetScale(v) self.scale=v; wall=wall+.0002 end
 function p:SetAlpha(v) self.alpha=v; wall=wall+.0002 end
 parent.nameplate=p; visiblePlates[parent]=parent
 units[p.unit]=p.cachedGuid; parents[p.unit]=parent
end
Z.UpdateStickyPlacements=function(now,visible)
 for parent in pairs(visible) do Z.GetPlateProjection(parent.nameplate,now) end
 wall=wall+.001
end
''')
r = recorder.read_text(encoding="utf-8-sig")
lua.execute(r[r.index("function P.BeginOperation("):r.index("local function Remember(")])
lua.execute("local Z=zNameplates\n" + core[core.index("function Z.BeginPlateCost("):
                                          core.index("function Z.SuppressNativePlateVisuals(")])
visual = plates[plates.index("  local function ApplyDistanceEffects("):
                plates.index("  local function RefreshVisibleNameplatePool(")]
lua.execute(visual + '\nvisualPass=ApplyDistanceEffects')
data_start = plates.index("  local hookOnDataChanged = nameplates.OnDataChanged")
data = plates[data_start:plates.index("  -- enable mouselook on rightbutton down", data_start)]
lua.execute(data)
lua.execute('''
function nameplates.OnUpdate(parent,state,visualOnly)
 visualPass(parent.nameplate,state.now,1)
 if not visualOnly then nameplates:OnDataChanged(parent.nameplate) end
end
''')
central = plates[plates.index('  nameplates:SetScript("OnUpdate", function()'):
                 plates.index("  -- combat tracker")]
lua.execute(central)
lua.execute('''
this=nameplates
nameplates.OnUpdateScript() -- No recorder clock reads/records while off.
assert(clockReads==0 and not next(db.operations) and not Z.platePerfActive)
running=true; wall=2; nameplates.OnUpdateScript()
local expected={"zNP full frame","zNP cluster bookkeeping","zNP depth ordering and layers",
 "zNP layout and projection","zNP plate visual-data loop","zNP native anchor projection",
 "zNP text layer guard","zNP distance sampling","zNP placement and scale writes",
 "zNP LOS raycasts","zNP LOS colour updates","zNP opacity writes","zNP full plate data refresh"}
for _,label in ipairs(expected) do
 local stat=db.operations[label]
 assert(stat and stat.calls>0 and stat.totalMs>=0,label)
end
assert(not Z.platePerfActive and db.operations["zNP full frame"].calls==1)
assert(db.operations["zNP full frame"].maxDetail=="visible=3")
assert(db.operations["zNP native anchor projection"].calls==3)
assert(math.abs(db.operations["zNP native anchor projection"].totalMs-1.8)<.0001)
assert(math.abs(db.operations["zNP depth ordering and layers"].totalMs-2)<.0001)
assert(math.abs(db.operations["zNP distance sampling"].totalMs-1.2)<.0001)
assert(math.abs(db.operations["zNP LOS raycasts"].totalMs-1.5)<.0001)
-- Exercise the alternate high-FPS visual-only branch; no scope leaks.
wall=3; this.frameTick=3
nameplates.OnUpdateScript()
assert(not Z.platePerfActive and db.operations["zNP full frame"].calls==2)
assert(db.operations["zNP depth ordering and layers"].calls==1)
assert(db.operations["zNP full plate data refresh"].calls==3)
-- Warmup and stopped capture stay free of extra timing reads/operation records.
local before=clockReads; local recorded=db.operations["zNP full frame"].calls
running=false; wall=4; nameplates.OnUpdateScript()
assert(clockReads==before and db.operations["zNP full frame"].calls==recorded and not Z.platePerfActive)
OctoPerf=nil; wall=5; nameplates.OnUpdateScript()
assert(clockReads==before and not Z.platePerfActive)
''')
print("zNP operation breakdown: real central/visual/data/native spans, recorder totals, crowd counts, fast branch, and zero-clock off/absent paths passed.")
