"""Lua 5.1 regression checks for plate appearance and position transitions."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "core.lua").read_text(encoding="utf-8-sig")
helper = source[source.index("function Z.GetPlateProjection("):source.index("Z.throttle = {}")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z = {config={nameplates={smooth_transitions="1",transition_duration=".12",vertical_offset="4"}}}
UIParent = {GetWidth=function() return 1000 end,GetHeight=function() return 800 end,
  GetEffectiveScale=function() return 1 end}
parent = {x=100,y=100,height=20}
function parent:GetCenter() return self.x,self.y end
function parent:GetHeight() return self.height end
function parent:GetEffectiveScale() return 1 end
plate = {parent=parent,cachedGuid="A",scale=1}
function plate:GetEffectiveScale() return self.scale end
function plate:ClearAllPoints() end
function plate:SetPoint(a,b,c,x,y) self.anchorX=x; self.anchorY=y end
projection = {x=100,y=100}
zAPI = function() return projection.x/1000,projection.y/800,10 end
function reset()
  plate.positionTransition=nil; plate.cachedGuid="A"; plate.scale=1
  parent.x=100; parent.y=100; projection.x=100; projection.y=100
end
function near(a,b) assert(math.abs(a-b)<.0001,tostring(a).." ~= "..tostring(b)) end
''')
lua.execute(helper)
lua.execute('''
-- Appearance fades in, while the configured offset is preserved.
Z.UpdatePlateTransition(plate,0)
near(plate.appearanceAlpha,0); near(plate.anchorY,4)
Z.UpdatePlateTransition(plate,.06); near(plate.appearanceAlpha,.5)
Z.UpdatePlateTransition(plate,.12); near(plate.appearanceAlpha,1)

-- A stack correction moves only part of the way on its first frame.
parent.y=130
Z.UpdatePlateTransition(plate,.13)
assert(plate.positionTransition.offsetY < -20)
assert(plate.positionTransition.offsetY > -30)
for i=14,50 do Z.UpdatePlateTransition(plate,i/100) end
assert(math.abs(plate.positionTransition.offsetY)<.01)

-- Camera/unit motion is not smoothed when the native anchor and projection agree.
reset(); Z.UpdatePlateTransition(plate,0)
parent.x=150; parent.y=130; projection.x=150; projection.y=130
Z.UpdatePlateTransition(plate,.01)
near(plate.anchorX,0); near(plate.anchorY,4)

-- Scaled plates convert screen-space correction back to local coordinates.
reset(); plate.scale=.5; Z.UpdatePlateTransition(plate,0)
parent.y=130; Z.UpdatePlateTransition(plate,.01)
near(plate.anchorY-4,plate.positionTransition.offsetY*2)

-- Reused frames never travel from the previous unit's position.
plate.cachedGuid="B"; parent.x=400; parent.y=300
Z.UpdatePlateTransition(plate,.02)
near(plate.anchorX,0); near(plate.anchorY,4); near(plate.appearanceAlpha,0)

-- Large teleports and long pauses drop residual offsets.
reset(); Z.UpdatePlateTransition(plate,0)
parent.x=400; Z.UpdatePlateTransition(plate,.01); near(plate.anchorX,0)
parent.y=130; Z.UpdatePlateTransition(plate,.02)
assert(plate.anchorY<4)
Z.UpdatePlateTransition(plate,1); near(plate.anchorY,4)

-- Disabling smoothing restores unmodified placement and opacity immediately.
parent.y=160; Z.UpdatePlateTransition(plate,1.01)
Z.config.nameplates.smooth_transitions="0"
Z.UpdatePlateTransition(plate,1.02)
near(plate.anchorY,4); near(plate.appearanceAlpha,1)

-- Without zAPI, ordinary small camera motions remain unmodified.
Z.config.nameplates.smooth_transitions="1"; zAPI=nil
reset(); Z.UpdatePlateTransition(plate,0)
parent.x=110; parent.y=110; Z.UpdatePlateTransition(plate,.01)
near(plate.anchorX,0); near(plate.anchorY,4)
parent.y=150; Z.UpdatePlateTransition(plate,.02)
assert(plate.anchorY<4)

-- Settings re-anchor a plate; invalidating the applied anchor reinstates correction.
plate.anchorY=4; plate.positionTransition.appliedX=nil
Z.UpdatePlateTransition(plate,.03); assert(plate.anchorY<4)
''')
print("Plate transition regression checks passed (Lua 5.1).")
