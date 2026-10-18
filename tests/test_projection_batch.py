"""Real Lua batch integration: per-render accuracy, buffers, gaps and fallback."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")
plates = (ROOT / "nameplates.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
Z={config={nameplates={}}}; clock=1; camera=0; ui=.9
version=2.8; capability=1; probes=0; batches=0; individual=0; validations=0
visible={}; pack={}; owners={}; units={}; gap={}; mode="ok"
GetTime=function() return clock end
UIParent={GetScale=function() return ui end,GetEffectiveScale=function() return ui end,
 GetWidth=function() return 1000 end,GetHeight=function() return 800 end}
WorldFrame={GetEffectiveScale=function() return 1 end}
UnitExists=function(u) return units[u]~=nil end
UnitGUID=function(u) validations=validations+1; return units[u] end
C_NamePlate={GetNamePlateForUnit=function(u) return owners[u] end}
function result(guid)
 if gap[guid] then return end
 local n=tonumber(string.sub(guid,-4),16)
 return camera+n/1000,.6,20+n,10+n,20+n,3+n
end
function api(command,ids,count,out)
 if command=="version" then return version end
 if command=="nameplateBatchVersion" then probes=probes+1; return capability end
 if command=="projectNameplate" then individual=individual+1; return result(ids) end
 assert(command=="projectNameplatesInto"); batches=batches+1
 if mode=="throw" then error("failed") end
 if mode=="nil" then return end
 if mode=="short" then return count-1 end
 if onBatch then local f=onBatch; onBatch=nil; f() end
 local old=table.getn(out)
 for i=1,count do
  local x,y,d,wx,wy,wz=result(ids[i]); local k=(i-1)*7
  out[k+1]=x and 1 or 0
  out[k+2],out[k+3],out[k+4]=x or 0,y or 0,d or 0
  out[k+5],out[k+6],out[k+7]=wx or 0,wy or 0,wz or 0
 end
 for i=count*7+1,old do out[i]=nil end
 if mode=="malformed" then out[1]=nil end
 return count
end
zAPI=api
function add(i)
 local u="nameplate"..i; local guid=string.format("0xF13000000000%04X",i)
 local parent={shown=true,IsVisible=function(self) return self.shown end}
 local p={unit=u,cachedGuid=guid,parent=parent}; parent.nameplate=p
 units[u]=guid; owners[u]=parent; visible[parent]=true; pack[i]=p
 return p
end
for i=1,50 do add(i) end
''')
lua.execute("local Z=Z\n" + core[core.index("function Z.BeginPlateRender("):
                                core.index("function Z.GetPlayerWorldPosition(")])
lua.execute(r'''
function render(t)
 clock=t; Z.BeginPlateRender(t); Z.PreparePlateProjections(t,visible)
 for parent in pairs(visible) do
  local p=parent.nameplate
  if parent:IsVisible() and not p.clusterHidden and Z.IsPlateUnitCurrent(p,t) then
   local x,y,d,wx,wy,wz=Z.GetPlateProjection(p,t)
   local a,b,c,e,f,g=result(p.cachedGuid)
   if gap[p.cachedGuid] then assert(x==nil and d==nil)
   else assert(math.abs(x-a/ui)<1e-9 and math.abs(y-b/ui)<1e-9)
    assert(d==c and wx==e and wy==f and wz==g) end
  end
 end
 Z.EndPlateRender()
end
render(1)
assert(batches==1 and individual==0 and probes==1 and validations==50)
local batch=Z.plateBatch; local ids,out,refs=batch.ids,batch.output,batch.plates
local sample=pack[1].projectionSample
-- Same timestamp, different camera snapshot: never reuse an earlier render.
camera=.03; render(1)
assert(batches==2 and individual==0 and pack[1].projectionSample==sample)
for i=1,120 do camera=i/1000; render(1+i/120) end
assert(batches==122 and individual==0 and probes==1)
assert(Z.plateBatch==batch and batch.ids==ids and batch.output==out and batch.plates==refs)
-- Failed individual models remain gaps, not duplicate fallback projections.
gap[pack[1].cachedGuid]=true; render(3)
assert(individual==0 and pack[1].projectionSample.x==nil)
gap[pack[1].cachedGuid]=nil; ui=.8; render(3.01)
-- Exclude stale slots, hidden/cluster-hidden plates, and camera-reactive dummies.
units[pack[1].unit]="replacement"; pack[2].parent.shown=false; pack[3].clusterHidden=true
pack[4].isDummy=true; pack[4].dummyProjection={x=.2,y=.3,depth=10}
Z.BeginPlateRender(4); Z.PreparePlateProjections(4,visible); Z.EndPlateRender()
assert(batch.count==46 and Z.GetPlateProjection(pack[1],4)==nil)
assert(Z.GetPlateProjection(pack[4],4)==.2)
units[pack[1].unit]=pack[1].cachedGuid; pack[2].parent.shown=true; pack[3].clusterHidden=nil
pack[4].isDummy=nil
-- Recycling during the native callback cannot apply another unit's sample.
onBatch=function() units[pack[1].unit]="0xF130000000000100"; pack[1].cachedGuid=units[pack[1].unit] end
local n=individual; render(5); assert(individual==n+1)
-- Whole-call failures (including malformed/short output) fall back correctly.
for _,failure in ipairs({"throw","nil","short","malformed"}) do
 mode=failure; local previous=individual; render(clock+.1); assert(individual==previous+50)
 assert(not batch.busy)
end
mode="ok"
-- Old DLL / unsupported capability: probe once, never call the batch command.
version=2.7; zAPI=function(...) return api(unpack(arg)) end
local b,p=batches,probes; n=individual; render(6); render(6.01)
assert(batches==b and probes==p and individual==n+100)
version=2.8; capability=0; zAPI=function(...) return api(unpack(arg)) end
b,p=batches,probes; render(6.02); render(6.03)
assert(batches==b and probes==p+1)
capability=1; zAPI=function(...) return api(unpack(arg)) end
render(6.04); assert(batches==b+1)
-- Repeated steady renders reuse the same Lua records and array capacities.
-- Use the direct mock C-API stand-in, not the legacy Lua vararg wrapper above
-- (Lua 5.1 compatibility creates an `arg` table in that test-only wrapper).
zAPI=api; render(6.045)
collectgarbage("collect"); collectgarbage("stop")
local memory=collectgarbage("count")
for i=1,2000 do camera=i/10000; render(6.04+i/10000) end
local growth=collectgarbage("count")-memory; collectgarbage("restart")
assert(growth<10,"steady batch Lua growth: "..growth)
-- Bound the batch without dropping any additional visible nameplates.
for i=51,520 do add(i) end
n=individual; render(7); assert(batch.count==512 and individual==n+8)
-- Native reentry cannot mutate the caller's reusable mapping/output.
onBatch=function() Z.PreparePlateProjections(clock,visible) end
b=batches; render(7.01); assert(batches==b+1)
-- Shrink removes retained mappings and output tail, including an empty scene.
for i=2,520 do visible[pack[i].parent]=nil end
render(8); assert(batch.count==1 and table.getn(out)==7 and ids[2]==nil and refs[2]==nil)
visible[pack[1].parent]=nil; render(9); assert(batch.count==0 and ids[1]==nil and refs[1]==nil)
-- Independent same-timestamp UI calls are not tied to a completed render context.
ui=.5; local x=Z.GetPlateProjection(pack[1],8)
local expected=result(pack[1].cachedGuid); assert(math.abs(x-expected/.5)<1e-9)
''')

# Both the regular and >100-FPS visual-only branches prepare fresh projections.
central = plates[plates.index('  nameplates:SetScript("OnUpdate", function()'):
                 plates.index("  -- combat tracker")]
assert central.count("zNameplates.PreparePlateProjections(now,visiblePlates)") == 2
assert "sample.renderSerial==render.serial" in plates
lua.execute(r'''
zNameplates=Z; frameState={}; visiblePlateCount=50; visiblePlates=visible; OctoPerf=nil
for i=1,50 do visible[pack[i].parent]=true end
ShouldOverlap=function() return true end
Z.UpdatePlateClusters=function() return false end
Z.UpdateStickyPlacements=function(now,visible)
 for parent in pairs(visible) do Z.GetPlateProjection(parent.nameplate,now) end
end
UpdateNameplateDepthLayers=function()
 for parent in pairs(visible) do Z.GetPlateProjection(parent.nameplate,frameState.now) end
end
RefreshVisibleNameplatePool=function() error("unexpected refresh") end
nameplates={OnUpdate=function(parent,state) Z.GetPlateProjection(parent.nameplate,state.now) end}
function nameplates:SetScript(_,f) self.update=f end
''')
lua.execute(central)
lua.execute(r'''
local before,old=batches,individual; this=nameplates; clock=20; this.depthDirty=true
nameplates.update() -- ordinary branch
clock=20.005; camera=.4; nameplates.update() -- visual-only >100-FPS branch
assert(batches==before+2 and individual==old and not Z.plateRenderContext.active)
''')
print("50 plates/122 camera frames: 6,100 individual projection calls -> 122 batches; "
      "all projections/validations retained. Gaps, recycle, old DLL, failure, reentry, "
      "512 bound, same-timestamp camera, UI conversion and reused buffers passed.")
