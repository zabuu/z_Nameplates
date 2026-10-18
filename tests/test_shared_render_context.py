"""Compare live rendering with the preserved October 18 implementation.

Counts native UI/identity reads; does not claim an in-game FPS measurement.
"""
from pathlib import Path
import subprocess
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT.parent / "_pfUIFreezeFix/backups/2026-10-18-org-friendly"


def source(folder, name):
    path = folder / name
    if path.is_file():
        return path.read_text(encoding="utf-8-sig")
    # Keep the regression runnable in the repository without local maintenance backups.
    if folder == BASE:
        return subprocess.check_output(
            ["git", "-C", str(ROOT), "show", "501d82c:" + name], text=True, encoding="utf-8-sig"
        )
    raise FileNotFoundError(path)

BOOT = r'''
Z={config={nameplates={smooth_transitions="1",transition_duration=".12",vertical_offset="4"}}}
zNameplates=Z; counts={}; clock=1; camera=0; uiScale=.9; distances={}; owners={}
function count(k) counts[k]=(counts[k] or 0)+1 end
GetTime=function() count("clock"); return clock end
UIParent={}
function UIParent:GetScale() count("baseScale"); return uiScale end
function UIParent:GetEffectiveScale() count("uiScale"); return uiScale end
function UIParent:GetWidth() count("width"); return 1000 end
function UIParent:GetHeight() count("height"); return 800 end
WorldFrame={GetEffectiveScale=function() count("worldScale"); return 1 end}
UnitExists=function(u) count("exists"); return u~=nil end
UnitGUID=function(u) count("guid"); return u end
C_NamePlate={GetNamePlateForUnit=function(u) return owners[u] end}
zAPI=function(command,unit)
 if command=="version" then return 2.7 end
 assert(command=="projectNameplate"); count("projection")
 return .5+camera,.6,20,1,2,3
end
cfg={distance_scale=true,distance_alpha=true,distance_min_scale=.5,distance_min_alpha=.4,distance_max_range=40}
abs=math.abs
SampleExactUnitDistance=function(p,now) return distances[p.unit] or 8 end
SetLineOfSightDesaturation=function() end
Z.RepairPlateTextLayers=function() end
Z.ApplyStickyPlacement=function(p,now,x,y,ui,scale)
 local sx,sy=Z.GetPlateProjection(p,now)
 return sx*1000*ui/scale,sy*800*ui/scale
end
pack={}
for i=1,50 do
 local parent={GetEffectiveScale=function() return 1 end}
 local p={unit="unit"..i,cachedGuid="unit"..i,parent=parent,worldPlacementOwned=true,scale=uiScale}
 function p:GetEffectiveScale() return self.scale end
 function p:SetScale(s) self.scale=s; count("scaleWrites") end
 function p:SetAlpha(a) self.alpha=a; count("alphaWrites") end
 function p:ClearAllPoints() count("clears") end
 function p:SetPoint(a,b,c,x,y) self.x,self.y=x,y; count("anchors") end
 owners[p.unit]=parent; pack[i]=p
end
'''


def runtime(folder):
    core = source(folder, "core.lua")
    plates = source(folder, "nameplates.lua")
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(BOOT)
    start = "function Z.BeginPlateRender(" if "function Z.BeginPlateRender(" in core else "function Z.GetPlateProjection("
    lua.execute("local Z=Z\n" + core[core.index(start):core.index("function Z.SuppressNativePlateVisuals(")])
    lua.execute("local Z=Z\n" + core[core.index("function Z.UpdatePlateTransition("):core.index("Z.throttle = {}")])
    visual = plates[plates.index("  local function ApplyDistanceEffects("):plates.index("  local function RefreshVisibleNameplatePool(")]
    lua.execute(visual + "\nvisualPass=ApplyDistanceEffects")
    lua.execute(r'''
function render(t)
 clock=t
 if Z.BeginPlateRender then Z.BeginPlateRender(t) end
 for _,p in ipairs(pack) do Z.GetPlateProjection(p,t) end
 for _,p in ipairs(pack) do visualPass(p,t,1) end
 if Z.EndPlateRender then Z.EndPlateRender() end
end
render(1)
''')
    return lua, plates


old, old_plates = runtime(BASE)
new, new_plates = runtime(ROOT)
before, after = dict(old.globals().counts.items()), dict(new.globals().counts.items())
assert before["baseScale"] == 50 and after["baseScale"] == 1
assert before["uiScale"] == 150 and after["uiScale"] == 1, (before, after)
assert before["worldScale"] == 100 and after["worldScale"] == 1, (before, after)
assert before["projection"] == after["projection"] == 50
assert before["guid"] == after["guid"] == 50  # Current-frame lifecycle validation remains.
print("50 plates: shared base/effective-scale reads 300 -> 3; all 50 projections and unit validations retained.")


def snapshot(lua):
    return [tuple(lua.globals().pack[i][k] for k in ("x", "y", "scale", "alpha", "appearanceAlpha")) for i in range(1, 51)]


assert snapshot(old) == snapshot(new)
for script in [
    "camera=.01; render(1.01)",
    "distances.unit1=40; camera=.03; render(1.02)",
    "uiScale=.8; Z.config.nameplates.vertical_offset='-7'; render(1.03)",
    "Z.config.nameplates.smooth_transitions='0'; render(1.04)",
    "Z.config.nameplates.smooth_transitions='1'; Z.config.nameplates.transition_duration='.3'; render(1.05)",
    "pack[1].cachedGuid='new'; pack[1].unit='new'; owners.new=pack[1].parent; render(1.06)",
    "for i=1,120 do camera=i/1000; render(1.06+i/120) end",
]:
    old.execute(script)
    new.execute(script)
    assert snapshot(old) == snapshot(new)
new.execute(r'''
-- The active context must not leak into independent same-timestamp consumers.
assert(not Z.plateRenderContext.active)
uiScale=.5
local x,y=Z.GetPlateProjection(pack[2],clock)
assert(math.abs(x-(.5+camera)/.5)<.000001 and math.abs(y-.6/.5)<.000001)
local saved=Z.plateRenderContext
Z.BeginPlateRender(clock); Z.EndPlateRender()
assert(Z.plateRenderContext==saved) -- One reused record, not one new table per frame.
''')
print("Dynamic camera, scale, opacity, offsets, appearance, recycled units, same-timestamp live reads and storage reuse match baseline.")

# Exercise actual cast-state helper with/without caller-supplied identity/time.
cast = new_plates[new_plates.index("  local function GetCastInfo("):new_plates.index("  local debuffCache =")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
guidReads=0; clockReads=0; clock=1; guid="A"; castState={A={endTime=2},B={endTime=3}}
Z={}; zNameplates=Z; owner={}; p={unit="nameplate1",cachedGuid="A",parent=owner}
UnitExists=function(u) return u=="nameplate1" end
C_NamePlate={GetNamePlateForUnit=function(u) return owner end}
UnitGUID=function() guidReads=guidReads+1; return guid end
GetTime=function() clockReads=clockReads+1; return clock end
''')
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")
lua.execute("local Z=Z\n" + core[core.index("function Z.IsPlateUnitCurrent("):core.index("function Z.ReleasePlateNativeCollision(")])
lua.execute(cast + "\ncastInfo=GetCastInfo")
lua.execute(r'''
local first=castState.A
assert(Z.IsPlateUnitCurrent(p,1)); guidReads=0
for i=1,50 do assert(castInfo("nameplate1",p,1)==first) end
assert(guidReads==0 and clockReads==0)
assert(castInfo("nameplate1")==first and guidReads==1 and clockReads==1)
assert(not castInfo("nameplate1",p,2) and not castState.A)
guid="B"; p.cachedGuid="B"
assert(castInfo("nameplate1",p,2.1)==castState.B)
-- Lost lifecycle feedback cannot make an old GUID bypass live validation.
p.cachedGuid="A"
assert(castInfo("nameplate1",p,2.2)==castState.B)
guid="missing"; assert(not castInfo("nameplate1",p,2.3))
assert(not castInfo(nil,p,2.3))
''')
assert "GetCastInfo(nameplate.unit, nameplate, now)" in new_plates
print("50 known-identity cast checks: 50 GUID reads -> 0; expiry, legacy resolution and replacement identities remain correct.")
