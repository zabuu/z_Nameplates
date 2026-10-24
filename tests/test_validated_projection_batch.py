"""Real Lua render path: fuse validation/projection without losing live checks."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")
old = ast.parse((ROOT / "tests/test_projection_batch.py").read_text())
prelude = next(ast.literal_eval(n.value.args[0]) for n in old.body
               if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
               and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(prelude)
lua.execute(r'''
zNameplates=Z; version=3.1; validationCap=1; validatedCalls=0; existsCalls=0; lookupCalls=0
validatedMode="ok"; baseAPI=api
UnitExists=function(u) existsCalls=existsCalls+1; return units[u]~=nil end
C_NamePlate.GetNamePlateForUnit=function(u) lookupCalls=lookupCalls+1; return owners[u] end
function validatedAPI(command,ids,count,out,tokens,parents)
 if command=="nameplateValidationVersion" then return validationCap end
 if command~="projectNameplatesValidatedInto" then return baseAPI(command,ids,count,out) end
 validatedCalls=validatedCalls+1
 if validatedMode=="throw" then error("native failure") end
 if validatedMode=="nil" then return end
 if validatedMode=="short" then return count-1 end
 local old=table.getn(out)
 for i=1,count do
  local current=units[tokens[i]]==ids[i] and owners[tokens[i]]==parents[i]
  local x,y,d,wx,wy,wz=result(ids[i]); local k=(i-1)*8
  out[k+1]=current and 1 or 0; out[k+2]=current and x and 1 or 0
  out[k+3],out[k+4],out[k+5]=x or 0,y or 0,d or 0
  out[k+6],out[k+7],out[k+8]=wx or 0,wy or 0,wz or 0
 end
 for i=count*8+1,old do out[i]=nil end
 if validatedMode=="malformed" then out[1]=nil end
 if validatedMode=="impossible" then out[1],out[2]=0,1 end
 if validatedMode=="coordinates" then out[3]=nil end
 if onValidated then local f=onValidated;onValidated=nil;f() end
 return count
end
zAPI=validatedAPI
''')
lua.execute("local Z=Z\n" + core[core.index("function Z.BeginPlateRender("):
                                core.index("function Z.GetPlayerWorldPosition(")])
lua.execute((ROOT / "renderbatch.lua").read_text())
lua.execute(r'''
function render(t)
 clock=t; Z.BeginPlateRender(t);Z.PreparePlateProjections(t,visible)
 for parent in pairs(visible) do
  local p=parent.nameplate
  if parent:IsVisible() and not p.isDummy and not p.clusterHidden and Z.IsPlateUnitCurrent(p,t) then
   local x,y,d,wx,wy,wz=Z.GetPlateProjection(p,t)
   local a,b,c,e,f,g=result(p.cachedGuid)
   if gap[p.cachedGuid] then assert(x==nil and d==nil)
   else assert(math.abs(x-a/ui)<1e-9 and math.abs(y-b/ui)<1e-9)
    assert(d==c and wx==e and wy==f and wz==g) end
  end
 end
 Z.EndPlateRender()
end
assert(Z.PrepareValidatedPlateProjections(0,visible)==false)
render(1)
assert(validatedCalls==1 and batches==0 and individual==0)
assert(validations==0 and existsCalls==0 and lookupCalls==0)
local batch=Z.validatedPlateBatch;local ids,output,refs=batch.ids,batch.output,batch.plates
local sample=pack[1].projectionSample; local validation=pack[1].unitValidation
-- New camera at an identical clock timestamp still validates/projects anew.
camera=.2;render(1)
for i=1,120 do camera=i/1000;render(1+i/120) end
assert(validatedCalls==122 and batches==0 and individual==0)
assert(validations==0 and existsCalls==0 and lookupCalls==0)
assert(sample==pack[1].projectionSample and validation==pack[1].unitValidation)
assert(batch.ids==ids and batch.output==output and batch.plates==refs)
-- A missing model preserves association; a recycled native slot never does.
gap[pack[1].cachedGuid]=true;render(3)
assert(pack[1].unitValidation.current and pack[1].projectionSample.x==nil)
gap[pack[1].cachedGuid]=nil; units[pack[2].unit]="replacement";render(3.01)
assert(not pack[2].unitValidation.current and Z.GetPlateProjection(pack[2],clock)==nil)
units[pack[2].unit]=pack[2].cachedGuid
owners[pack[2].unit]=pack[3].parent;render(3.02);assert(not pack[2].unitValidation.current)
owners[pack[2].unit]=pack[2].parent
pack[2].parent.shown=false;pack[3].clusterHidden=true;pack[4].isDummy=true
render(3.03);assert(batch.count==47)
pack[2].parent.shown=true;pack[3].clusterHidden=nil;pack[4].isDummy=nil
-- A Lua callback changes identity after the DLL snapshot: discard that row.
onValidated=function() units[pack[1].unit]="0xF130000000000100";pack[1].cachedGuid=units[pack[1].unit] end
local n=individual;render(4);assert(individual==n+1)
for _,failure in ipairs({"throw","nil","short","malformed","impossible","coordinates"}) do
 validatedMode=failure;local b=batches;render(clock+.01)
 assert(batches==b+1 and not batch.busy) -- original validated Lua + v1 projection batch
end
validatedMode="ok"
-- API replacement cannot seed an association validated by a different API.
onValidated=function() UnitGUID=function(u) validations=validations+1;return units[u] end end
local b=batches;render(5);assert(batches==b+1)
version=3;zAPI=function(a,b,c,d,e,f) return validatedAPI(a,b,c,d,e,f) end
n=validatedCalls;b=batches;render(5.01);assert(validatedCalls==n and batches==b+1)
version=3.1;validationCap=0;zAPI=function(a,b,c,d,e,f) return validatedAPI(a,b,c,d,e,f) end
render(5.02);assert(validatedCalls==n)
validationCap=1;zAPI=validatedAPI;render(5.03)
collectgarbage("collect");collectgarbage("stop");local memory=collectgarbage("count")
for i=1,2000 do camera=i/10000;render(6+i/10000) end
local growth=collectgarbage("count")-memory;collectgarbage("restart")
assert(growth<10,"steady render allocation KB: "..growth)
for i=51,520 do add(i) end
n=individual;render(7);assert(batch.count==512 and individual==n+8)
-- Reentry leaves the outer mapping intact; its guarded fallback remains safe.
onValidated=function() Z.PreparePlateProjections(clock,visible) end
render(7.01)
for i=2,520 do visible[pack[i].parent]=nil end
render(8);assert(batch.count==1 and table.getn(output)==8 and ids[2]==nil and refs[2]==nil)
visible[pack[1].parent]=nil;render(9);assert(batch.count==0 and ids[1]==nil and refs[1]==nil)
assert(Z.PrepareValidatedPlateProjections(9,visible)==false)
''')
# Exercise the actual central scheduler's regular and >100 FPS visual branches.
plates = (ROOT / "nameplates.lua").read_text(encoding="utf-8-sig")
central = plates[plates.index('  nameplates:SetScript("OnUpdate", function()'):
                 plates.index("  -- combat tracker")]
lua.execute(r'''
frameState={};visiblePlateCount=50;visiblePlates=visible;OctoPerf=nil
for i=1,50 do visible[pack[i].parent]=true end
ShouldOverlap=function() return true end
Z.UpdatePlateClusters=function() return false end
Z.UpdateStickyPlacements=function(now,v) for parent in pairs(v) do Z.GetPlateProjection(parent.nameplate,now) end end
UpdateNameplateDepthLayers=function() for parent in pairs(visible) do Z.GetPlateProjection(parent.nameplate,frameState.now) end end
RefreshVisibleNameplatePool=function() error("unexpected refresh") end
nameplates={OnUpdate=function(parent,state) Z.GetPlateProjection(parent.nameplate,state.now) end}
function nameplates:SetScript(_,f) self.update=f end
''')
lua.execute(central)
lua.execute(r'''
local before,b=validatedCalls,batches;this=nameplates;clock=20;this.depthDirty=true
nameplates.update();clock=20.005;camera=.4;nameplates.update()
assert(validatedCalls==before+2 and batches==b and not Z.plateRenderContext.active)
''')
print("PASS 122 x 50 plate renders: 18,300 Lua validation bridge calls -> 0; all live associations/projections retained, both scheduler branches, old DLL/failure fallback, recycle/model gaps, API replacement, 512 bound, reentry and <10KB warm allocation")
