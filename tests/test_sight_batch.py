"""Production LOS collection + visual loop: parity, cadence, bounded buffers, fallback."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
plates = (ROOT / "nameplates.lua").read_text(encoding="utf-8-sig")
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")
tree = ast.parse((ROOT / "tests/test_background_friendly.py").read_text())
boot = next(ast.literal_eval(n.value) for n in tree.body
            if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "BOOT" for t in n.targets))


def runtime(batched):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute(boot)
    vm.execute('''
Z.config={nameplates={los_fade="1"}}; units={}; owners={}; probes=0; batches=0; rows=0
mode="ok"; missing={}; nativeResult={}; visible={}; oldCalls=0
Z.IsBackgroundFriendlyPlate=function(p) return p.backgroundFriendly end
Z.IsPlateUnitCurrent=function(p) return units[p.unit]==p.cachedGuid and owners[p.unit]==p.parent end
UnitXP=function(command,source,unit) assert(command=="inSight" and source=="player"); oldCalls=oldCalls+1; return not missing[unit] end
function api(command,ids,count,out)
 if command=="nameplateSightVersion" then probes=probes+1; return capability end
 assert(command=="nameplateSightInto"); batches=batches+1; rows=rows+count
 if mode=="throw" then error("native failure") end
 if mode=="nil" then return end
 if mode=="short" then return count-1 end
 if onBatch then local f=onBatch; onBatch=nil; f() end
 local previous=table.getn(out)
 for i=1,count do out[i]=nativeResult[ids[i]] or 1 end
 for i=count+1,previous do out[i]=nil end
 if mode=="malformed" then out[1]=nil end
 return count
end
zAPI=api; capability=1
for i,p in ipairs(pack) do
 p.cachedGuid=string.format("0x%016X",i); p.parent={IsVisible=function() return true end}
 p.parent.nameplate=p; units[p.unit]=p.cachedGuid; owners[p.unit]=p.parent; visible[p.parent]=true
end
''')
    vm.execute(plates[plates.index("  local function SampleExactUnitDistance("):
                      plates.index("  local function GetUnitDepth(")] + "\n_G.SampleExactUnitDistance=SampleExactUnitDistance")
    vm.execute(plates[plates.index("  local function ApplyDistanceEffects("):
                      plates.index("  local function RefreshVisibleNameplatePool(")] + "\napply=ApplyDistanceEffects")
    if batched:
        vm.execute((ROOT / "sight.lua").read_text())
    vm.execute('''
function render(t,light)
 clock=t; Z.plateRenderContext=Z.plateRenderContext or {}
 local c=Z.plateRenderContext; c.active=true; c.now=t; c.ui=UIParent; c.baseScale=1; c.serial=(c.serial or 0)+1
 for _,p in ipairs(pack) do p.backgroundFriendly=light end
 if Z.PreparePlateSight then Z.PreparePlateSight(t,visible) end
 for _,p in ipairs(pack) do
  if visible[p.parent] and not p.clusterHidden and not p.worldPlacementHidden and Z.IsPlateUnitCurrent(p) then apply(p,t,1) end
 end
 c.active=false
end
''')
    return vm


for light in (False, True):
    old, new = runtime(False), runtime(True)
    for step in range(601):
        if step in (90, 180, 270, 360):
            blocked = "true" if step in (90, 270) else "nil"
            result = "0" if blocked == "true" else "1"
            for vm in (old, new):
                vm.execute(f'''for i,p in ipairs(pack) do
                  if math.mod(i,3)==0 then missing[p.unit]={blocked}; nativeResult[p.cachedGuid]={result} end
                end; distance={35 if step in (90,270) else 12}''')
        for vm in (old, new):
            vm.execute(f"render({step}/60,{str(light).lower()})")
        for i in (1, 17, 50):
            for key in ("alpha", "scale", "losAlpha", "losNextSample", "losOutOfSight"):
                assert old.globals().pack[i][key] == new.globals().pack[i][key], (step, key)
    assert new.globals().oldCalls == 0
    assert old.globals().oldCalls == new.globals().rows
    assert new.globals().batches <= 601 and new.globals().probes == 1
    assert old.globals().anchors == new.globals().anchors == 30050
    print(f"PASS light={light}: {old.globals().oldCalls} per-unit calls -> {new.globals().batches} batches; "
          f"same due samples, alpha/scale/fade schedule and 30,050 render anchors")

vm = runtime(True)
vm.execute('''
render(0,true); local before=rows; local buffer=Z.sightBatch; local output=buffer.output
render(.001,false); assert(rows==before+50 and oldCalls==0) -- interaction cadence upgrades now
local p=pack[1]; p.cachedGuid="0x0000000000000101"; units[p.unit]=p.cachedGuid
render(.002,false); assert(rows==before+51 and oldCalls==0)
-- Unknown native rows use the old provider; one unknown is not a whole-batch failure.
nativeResult[p.cachedGuid]=-1; p.losNextSample=nil; local previous=oldCalls
render(.003,false); assert(oldCalls==previous+1)
nativeResult[p.cachedGuid]=0; p.losNextSample=nil; missing[p.unit]=true
render(.004,false); assert(p.losOutOfSight and oldCalls==previous+1)
nativeResult[p.cachedGuid]=1; p.losNextSample=nil; missing[p.unit]=nil
render(.005,false); assert(not p.losOutOfSight)
for _,failure in ipairs({"throw","nil","short","malformed"}) do
 mode=failure; for _,q in ipairs(pack) do q.losNextSample=nil end
 previous=oldCalls; render(clock+.001,false); assert(oldCalls==previous+50 and not buffer.busy)
end
mode="ok"
-- Reentry cannot mutate reusable buffers; recycling during output rejects that row.
onBatch=function()
 Z.PreparePlateSight(clock,visible)
 p.cachedGuid="0x0000000000000102"; units[p.unit]=p.cachedGuid
end
for _,q in ipairs(pack) do q.losNextSample=nil end
previous=oldCalls; local b=batches; render(.02,false)
assert(oldCalls==previous+1 and batches==b+1)
-- Hide, stale association, cluster membership and preview dummies are excluded.
pack[2].worldPlacementHidden=true; pack[3].clusterHidden=true; pack[4].isDummy=true
owners[pack[5].unit]={}
for _,q in ipairs(pack) do q.losNextSample=nil end
render(.03,false); assert(buffer.count==46)
pack[2].worldPlacementHidden=nil; pack[3].clusterHidden=nil; pack[4].isDummy=nil; owners[pack[5].unit]=pack[5].parent
-- Old capability probes once; no unsupported batches. API changes refresh immediately.
capability=nil; zAPI=function(...) return api(unpack(arg)) end
b=batches; previous=oldCalls; render(.04,false); render(.041,false)
assert(batches==b and oldCalls>=previous+50)
capability=1; zAPI=api; for _,q in ipairs(pack) do q.losNextSample=nil end
render(.05,false); assert(batches==b+1 and buffer.output==output)
-- Read the old output only during its render; independent calls see no stale sample.
assert(Z.GetPreparedPlateSight(p,clock)==nil)
collectgarbage("collect"); collectgarbage("stop"); local memory=collectgarbage("count")
for i=1,2000 do render(1+i/120,false) end
local growth=collectgarbage("count")-memory; collectgarbage("restart")
assert(growth<10,"steady Lua allocation: "..growth)
-- Shrinking removes mappings/output; empty scenes retain no stale associations.
for i=2,50 do visible[pack[i].parent]=nil end
p.losNextSample=nil; render(20,false); assert(buffer.count==1 and buffer.ids[2]==nil and table.getn(output)==1)
visible[p.parent]=nil; render(20.01,false); assert(buffer.count==0 and buffer.ids[1]==nil)
''')
central = plates[plates.index('  nameplates:SetScript("OnUpdate", function()'):
                 plates.index("  -- combat tracker")]
assert central.count("zNameplates.PreparePlateSight(now,visiblePlates,") == 2
print("PASS unknown/failing/old providers, immediate upgrades/recycling, stale slots, hidden/cluster/dummy exclusion, reentry, both render branches, reused buffers and <10 KB warm Lua growth")
