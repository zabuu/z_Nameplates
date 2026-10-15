"""Bound full-UI scans using real guards; keep fresh window/click/hover safety."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
clusters = (root / "clusters.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={mouseover_unit="1"}}}; zNameplates=Z; clock=0
GetTime=function() return clock end
function widget(owner)
 local f={owner=owner,scripts={},mouse=false}
 function f:GetParent() return self.owner end
 function f:IsVisible() return self.visible~=false end
 function f:GetScript(k) return self.scripts[k] end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:IsMouseEnabled() return self.mouse end
 function f:EnableMouse(v) self.mouse=v; mouseWrites=mouseWrites+1 end
 function f:Click(button) clicks=clicks+1; clicked=(self.nameplate or self).unit; clickedButton=button end
 function f:fire(k) this=self; if self.scripts[k] then self.scripts[k]() end end
 return f
end
mouseWrites=0; clicks=0; scans=0; focusReads=0; underWindow=false; spans=0
UIParent=widget(); WorldFrame=widget()
native=widget(WorldFrame); plate=widget(native); plate.parent=native; native.nameplate=plate
plate.unit="nameplate1"; plate.cachedGuid="g1"
otherNative=widget(WorldFrame); otherPlate=widget(otherNative)
otherNative.nameplate=otherPlate; otherPlate.parent=otherNative
otherPlate.unit="nameplate2"; otherPlate.cachedGuid="g2"
panel=widget(UIParent); button=widget(panel)
focus=WorldFrame
GetMouseFocus=function() focusReads=focusReads+1; return focus end
stackAPI=function()
 scans=scans+1
 return underWindow and {focus,button,WorldFrame} or {focus,WorldFrame}
end
GetMouseFoci=stackAPI
UnitExists=function(u) return u=="g1" or u=="g2" or u=="nameplate1" or u=="nameplate2" end
UnitGUID=function(u) return u=="nameplate1" and "g1" or u=="nameplate2" and "g2" end
UnitHealth=function(u) return u=="nameplate1" and 60 or 20 end
UnitHealthMax=function() return 100 end
hoverWrites={}; SetMouseoverUnit=function(u) hoverWrites[#hoverWrites+1]=u end
Z.BeginPlateCost=function() spans=spans+1; return clock,1 end
Z.EndPlateCost=function(label) assert(label=="zNP interface input guard") end
''')
lua.execute("local Z=zNameplates\n" + core[core.index("local function PlateMouseFocusKind("):
                                          core.index("-- Narrow opt-in spans")])
lua.execute(clusters)
lua.execute('''
-- 50 plates at 120 FPS: no frame-list walks, one cheap focus read per frame.
for tick=1,120 do
 clock=tick/120
 for i=1,50 do assert(not Z.IsPlateClickBlocked(clock)) end
end
assert(scans==0 and focusReads==120 and spans==0)
focus=button; clock=2
for i=1,50 do assert(Z.IsPlateClickBlocked(clock)) end
assert(scans==0 and focusReads==121) -- Interface on top needs no deep scan.
focus=UIParent; clock=3; assert(not Z.IsPlateClickBlocked(clock))
focus=nil; clock=4; assert(not Z.IsPlateClickBlocked(clock))
assert(scans==0)
-- A plate can cover a UI frame; background monitoring is bounded to 10 Hz.
focus=plate; local before=scans
for tick=0,119 do
 clock=5+tick/120
 for i=1,50 do assert(not Z.IsPlateClickBlocked(clock)) end
end
assert(scans-before<=10 and scans-before>=9,scans-before)
-- A window opens in the same frame: click bypasses BOTH caches and is denied.
underWindow=true; before=scans
Z.ClickPlate(plate,"LeftButton")
assert(scans==before+1 and clicks==0 and Z.clickBlocked)
-- Closing in that frame must not leave a stale cached block either.
underWindow=false; before=scans
Z.ClickPlate(plate,"RightButton")
assert(scans==before+1 and clicks==1 and clicked=="nameplate1" and clickedButton=="RightButton")
-- The same forced path still chooses the live lowest-health cluster member.
plate.clusterGroup={members={plate,otherPlate}}
Z.ClickPlate(plate,"LeftButton"); assert(clicks==2 and clicked=="nameplate2")
plate.clusterGroup=nil
-- Hover entry also forces a fresh check; a window must not acquire mouseover.
Z.InstallPlateMouseover(plate,plate)
plate:fire("OnEnter"); assert(hoverWrites[#hoverWrites]=="g1")
underWindow=true; before=scans; plate:fire("OnEnter")
assert(scans==before+1 and hoverWrites[#hoverWrites]=="")
underWindow=false
-- Check arbitrary windows below a plate, stock panel backgrounds, API swaps,
-- and all-frame API-only / old single-focus-only clients.
clock=7; assert(not Z.IsPlateClickBlocked(clock))
underWindow=true; clock=7.11; assert(Z.IsPlateClickBlocked(clock))
underWindow=false; clock=7.22; assert(not Z.IsPlateClickBlocked(clock))
focus=otherPlate; underWindow=true; clock=7.23
assert(Z.IsPlateClickBlocked(clock)) -- Changed focus is never given stale data.
underWindow=false; focus=plate; clock=8
assert(not Z.IsPlateClickBlocked(clock))
GetMouseFoci=function() scans=scans+1; return {plate,button} end
assert(Z.IsPlateClickBlocked(clock)) -- Replaced API in the same tick.
GetMouseFoci=stackAPI; GetMouseFocus=nil; underWindow=true; clock=9
assert(Z.IsPlateClickBlocked(clock))
underWindow=false; clock=9.11; assert(not Z.IsPlateClickBlocked(clock))
GetMouseFoci=nil; GetMouseFocus=function() return focus end
UIPanelWindows={TestPanel={}}; TestPanel=panel
MouseIsOver=function(f) return f==panel end
clock=10; assert(Z.IsPlateClickBlocked(clock))
panel.visible=false; clock=10.01; assert(not Z.IsPlateClickBlocked(clock))
GetMouseFocus=nil; clock=11; assert(not Z.IsPlateClickBlocked(clock))
GetMouseFocus=function() return focus end; GetMouseFoci=stackAPI
panel.visible=true; clock=12; before=scans
assert(Z.IsPlateClickBlocked(clock) and scans==before) -- Stock-panel fast path.
-- Optional profiling covers this former blind spot, once per rendered frame.
panel.visible=false; Z.platePerfActive=true; clock=13
before=spans
for i=1,50 do Z.IsPlateClickBlocked(clock) end
assert(spans==before+1)
Z.platePerfActive=nil
''')

# Run the real outer update/input guard, without executing visual geometry.
start = plates.index("  local updatePlate = nameplates.OnUpdate")
end = plates.index("  nameplates.IsCombatWithPlayer =", start)
lua.execute('''
nameplates={OnUpdate=function(frame,state,visualOnly)
 -- Equivalent final ownership for an ordinary overlay in world-owned mode.
 if not visualOnly then
  if frame.nameplate.uiClickBlocked then
   if frame:IsMouseEnabled() then frame:EnableMouse(false) end
   if frame.nameplate:IsMouseEnabled() then frame.nameplate:EnableMouse(false) end
  elseif not frame.nameplate:IsMouseEnabled() then frame.nameplate:EnableMouse(true) end
  frame.nameplate.lasttick=state.now
 end
end}
Z.RenderPlateCluster=function() end
MouseIsOver=nil; UIPanelWindows=nil
''')
lua.execute(plates[start:end])
lua.execute('''
clock=20; focus=plate; underWindow=false
nameplates.OnUpdate(native,{now=clock})
assert(plate.mouse and not plate.uiClickBlocked)
plate:fire("OnEnter"); assert(hoverWrites[#hoverWrites]=="g1")
clock=21; focus=button; underWindow=true
nameplates.OnUpdate(native,{now=clock},true)
assert(not plate.mouse and plate.uiClickBlocked and hoverWrites[#hoverWrites]=="")
local before=mouseWrites
for tick=1,120 do nameplates.OnUpdate(native,{now=21+tick/120}) end
assert(mouseWrites==before) -- No repeated re-enable/disable/hover churn.
clock=23; focus=WorldFrame; underWindow=false
nameplates.OnUpdate(native,{now=clock})
assert(plate.mouse and not plate.uiClickBlocked and plate.lasttick==23)
''')

# Mouse-down and delayed right-click emulation both require a fresh guard.
start = plates.index("  nameplates.mouselook.OnMouseDown = function()")
end = plates.index("  -- The combat-list panel", start)
lua.execute('''
lookStarts=0; attacks=0; looking=false
MouselookStart=function() lookStarts=lookStarts+1 end
IsMouselooking=function() return looking end
UnitCanAttack=function() return true end
AttackTarget=function() attacks=attacks+1 end
nameplates.combat={}; nameplates.mouselook=widget(UIParent)
function nameplates.mouselook:Show() self.shown=true end
function nameplates.mouselook:Hide() self.shown=false end
C={nameplates={clickthreshold=".5"}}
''')
lua.execute(plates[start:end])
lua.execute('''
clock=30; focus=button; arg1="RightButton"; this=plate
nameplates.mouselook.OnMouseDown(); assert(lookStarts==0)
focus=plate; underWindow=false; nameplates.mouselook.OnMouseDown()
assert(lookStarts==1 and nameplates.mouselook.shown)
underWindow=true; nameplates.mouselook:fire("OnUpdate")
assert(not nameplates.mouselook.shown and attacks==0 and clicks==2)
underWindow=false; this=plate; nameplates.mouselook.OnMouseDown()
nameplates.mouselook:fire("OnUpdate")
assert(not nameplates.mouselook.shown and attacks==1 and clicks==3)
''')

# Exercise target detection as shipped: opaque native frames with different
# GUIDs must not all enter the target's 50 Hz data path / target styling.
start = plates.index("    local targetGuid = state and state.targetGuid", plates.index("  nameplates.OnUpdate = function(frame, state, visualOnly)"))
end = plates.index("    local configAlpha =", start)
lua.execute("function detectTarget(frame,nameplate,state)\n" + plates[start:end] + "\nreturn target\nend")
lua.execute('''
alphaReads=0
local f={GetAlpha=function() alphaReads=alphaReads+1; return 1 end}
local count=0
for i=1,50 do
 if detectTarget(f,{cachedGuid="g"..i},{targetGuid="g7"}) then count=count+1 end
end
assert(count==1 and alphaReads==0)
assert(not detectTarget(f,{cachedGuid="g7"},{}))
assert(detectTarget(f,{}, {targetGuid="legacy"}) and alphaReads==1)
''')
print("Input guard: 50 plates/120 FPS with zero global scans over world/UI; bounded hover scans; fresh click/hover/right-click blocking; stable mouse ownership; GUID-only target fast path passed.")
