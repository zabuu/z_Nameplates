"""Name-attachment projection selection, caching, gaps, and legacy fallback."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; clock=0; versionReads=0; nameReads=0; collisionReads=0
apiVersion=1.9; modelReady=true; cameraX=.6; cameraY=.7; uiScale=.9
GetTime=function() return clock end
UnitExists=function(u) return u=="nameplate1" end
UnitGUID=function(u) return u=="nameplate1" and "guid" end
UIParent={GetEffectiveScale=function() return uiScale end}
WorldFrame={GetEffectiveScale=function() return 1 end}
plate={unit="nameplate1",cachedGuid="guid"}
zAPI=function(command,guid,offset)
 if command=="version" then versionReads=versionReads+1; return apiVersion end
 assert(guid=="guid" and offset==0)
 if command=="projectNameplate" then
  nameReads=nameReads+1
  if not modelReady then return nil end
  -- The model attachment can differ in X as well as height. Keep the entire
  -- native result; do not approximate its Y using a manual pixel/world lift.
  return cameraX,cameraY,15,10,20,4.6666667
 end
 assert(command=="projectUnit"); collisionReads=collisionReads+1
 return .5,.3,16,10,20,2
end
''')
lua.execute('local Z=Z\n' + core[core.index("function Z.GetPlateProjection("):core.index("-- zAPI projects in the native WorldFrame")])
lua.execute('local Z=Z\n' + core[core.index("function Z.NormalizeWorldProjection("):core.index("function Z.GetPlayerWorldPosition(")])
lua.execute('''
local x,y,d,wx,wy,wz=Z.GetPlateProjection(plate,0)
assert(math.abs(x-.6/.9)<.000001 and math.abs(y-.7/.9)<.000001)
assert(d==15 and wx==10 and wy==20 and wz==4.6666667)
assert(plate.projectionSample.command=="projectNameplate")
Z.GetPlateProjection(plate,0)
assert(versionReads==1 and nameReads==1 and collisionReads==0)
-- Camera movement is immediate and the correctly projected model anchor
-- remains independent of font size, threat state, or native-frame geometry.
for i=1,100 do
 cameraX=.6-i*.001; cameraY=.7-i*.001; clock=i*.01
 x,y=Z.GetPlateProjection(plate,clock)
 assert(math.abs(x-cameraX/uiScale)<.000001 and math.abs(y-cameraY/uiScale)<.000001)
end
assert(versionReads==1 and nameReads==101 and collisionReads==0)
-- A model-not-ready/hidden attachment is a real gap. Do not fall to a lower
-- anchor for a frame and snap back when the model becomes available again.
modelReady=false; clock=2
assert(Z.GetPlateProjection(plate,clock)==nil)
assert(Z.GetPlateProjection(plate,clock)==nil)
assert(nameReads==102 and collisionReads==0)
modelReady=true; clock=2.1
x,y=Z.GetPlateProjection(plate,clock)
assert(math.abs(y-cameraY/uiScale)<.000001)
-- UI scale conversion is live even when this frame's native result is cached.
uiScale=.8
x,y=Z.GetPlateProjection(plate,clock)
assert(math.abs(y-cameraY/.8)<.000001 and nameReads==103)
-- Older installed DLLs remain usable without making unsupported calls every
-- frame. Replacing the API invalidates both capability and projection caches.
local previous=zAPI
apiVersion=1.8; zAPI=function(...) return previous(...) end
x,y=Z.GetPlateProjection(plate,clock)
assert(x==.625 and math.abs(y-.375)<.000001)
assert(plate.projectionSample.command=="projectUnit" and versionReads==2 and collisionReads==1)
Z.GetPlateProjection(plate,clock)
assert(versionReads==2 and collisionReads==1)
apiVersion=1.9; zAPI=function(...) return previous(...) end
x,y=Z.GetPlateProjection(plate,clock)
assert(plate.projectionSample.command=="projectNameplate" and versionReads==3 and nameReads==104)
-- A faulty API version probe fails safely to the old command, once only.
zAPI=function(command,...)
 if command=="version" then versionReads=versionReads+1; error("unsupported") end
 return previous(command,...)
end
Z.GetPlateProjection(plate,3); Z.GetPlateProjection(plate,3.1)
assert(versionReads==4 and collisionReads==3)
''')
print("Native name-attachment selection, no anchor fallback on gaps, one-time probing, and legacy compatibility passed.")
