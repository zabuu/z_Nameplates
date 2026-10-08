"""Native-read counts, cache invalidation, and synchronized depth cadence."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "core.lua").read_text(encoding="utf-8-sig")
helper = source[source.index("function Z.GetPlateProjection("):source.index("function Z.SuppressNativePlateVisuals(")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; projectionCalls=0; playerCalls=0
zAPI=function(command,unit)
  if command=="projectUnit" then
    projectionCalls=projectionCalls+1
    if unit=="bad" then error("unavailable") end
    return .5,.6,20,1,2,3
  end
  assert(command=="unitPosition" and unit=="player")
  playerCalls=playerCalls+1
  return 10,20,30
end
''')
lua.execute(helper)
lua.execute('''
plates={}
for i=1,50 do
  plates[i]={cachedGuid=tostring(i)}
  local x,y,d=Z.GetPlateProjection(plates[i],1)
  assert(x==.5 and y==.6 and d==20)
  Z.GetPlateProjection(plates[i],1) -- Another consumer in the same frame.
  local px,py,pz=Z.GetPlayerWorldPosition(1)
  assert(px==10 and py==20 and pz==30)
end
assert(projectionCalls==50 and playerCalls==1)
for i=1,50 do Z.GetPlateProjection(plates[i],1.01); Z.GetPlayerWorldPosition(1.01) end
assert(projectionCalls==100 and playerCalls==2)
plates[1].cachedGuid="new"; Z.GetPlateProjection(plates[1],1.01)
assert(projectionCalls==101) -- Identity changes invalidate immediately.
plates[1].cachedGuid="bad"
assert(Z.GetPlateProjection(plates[1],1.01)==nil)
assert(Z.GetPlateProjection(plates[1],1.01)==nil)
assert(projectionCalls==102) -- Failed reads are cached, not retried by each consumer.
local previous=zAPI
zAPI=function(...) return previous(...) end
Z.GetPlateProjection(plates[2],1.01); Z.GetPlayerWorldPosition(1.01)
assert(projectionCalls==103 and playerCalls==3) -- Replaced API invalidates.

assert(Z.ShouldUpdatePlateDepth(0,50,false))
assert(not Z.ShouldUpdatePlateDepth(.01,50,false))
assert(Z.ShouldUpdatePlateDepth(1/30,50,false))
assert(Z.ShouldUpdatePlateDepth(.034,50,true)) -- New/removed/target plates bypass cadence.
assert(not Z.ShouldUpdatePlateDepth(.04,50,false))
assert(Z.ShouldUpdatePlateDepth(.051,5,false)) -- Smaller scenes retain 60 Hz.
''')
print("Plate native-read caching and depth-cadence checks passed (Lua 5.1).")

# Execute the actual recovery/depth routine with no global `nameplates`.
# It is defined before the local core frame, so that frame is not in scope.
plates_source = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
depth_helper = plates_source[
    plates_source.index("  local function UpdateNameplateDepthLayers()"):
    plates_source.index("  local function SaveVisualColor(")
]
lua.execute('''
nameplates=nil; scanCalls=0; layerCalls=0
frameState={now=0}; visiblePlates={}; visiblePlateCount=0
depthPlates={}; DEPTH_STRATAS={"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG"}
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
testPlate={nameplate={},IsVisible=function() return true end}
C_NamePlate={GetNamePlateForUnit=function(unit)
  scanCalls=scanCalls+1
  if unit=="nameplate1" then return testPlate end
end}
UnitExists=function(unit) return unit=="nameplate1" end
UnitGUID=function(unit) return "test-guid" end
GetUnitDepth=function() return 20 end
SetPlateDepthLayer=function() layerCalls=layerCalls+1 end
''')
lua.execute(depth_helper + '''
UpdateNameplateDepthLayers()
assert(scanCalls==1 and visiblePlateCount==1 and layerCalls==1)
assert(testPlate.nameplate.cachedGuid=="test-guid")
frameState.now=.1; UpdateNameplateDepthLayers()
assert(scanCalls==1 and layerCalls==2)
frameState.now=.5; UpdateNameplateDepthLayers()
assert(scanCalls==2 and visiblePlateCount==1 and layerCalls==3)
''')
print("Actual depth recovery routine passed with no global nameplates frame.")
