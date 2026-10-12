"""Bounded local placement, hover protection, damping, home return and identity."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={sticky_placement="1",sticky_delay=".15",sticky_max_displacement="96",
 sticky_motion_speed="140",sticky_motion_duration=".22",sticky_hover_protection="1"}}}
zNameplates=Z; zAPI=function() end
UIParent={GetEffectiveScale=function() return 1 end,
 GetWidth=function() return 1000 end,GetHeight=function() return 800 end}
clock=0; GetTime=function() return clock end
visible={}
function add(id,x,y)
 local f={x=x,y=y}
 function f:GetCenter() return self.x,self.y-self:GetHeight()*.5 end
 function f:GetHeight() return self.height or 20 end
 function f:GetWidth() return self.width or 1 end
 function f:GetEffectiveScale() return 1 end
 function f:IsVisible() return true end
 local p={parent=f,cachedGuid=id,px=x,py=y,depth=10}
 function p:GetEffectiveScale() return 1 end
 function p:GetWidth() return 80 end
 function p:GetHeight() return 20 end
 f.nameplate=p; visible[f]=f
 return p
end
Z.GetPlateProjection=function(p) if p.px then return p.px/1000,p.py/800,p.depth end end
overlap=false
function update(t)
 clock=t; Z.UpdateStickyPlacements(t,visible,function() return overlap end)
end
function render(p,t)
 clock=t
 return Z.ApplyStickyPlacement(p,t,p.parent.x,p.parent.y,1,1)
end
function near(a,b) assert(math.abs(a-b)<.001,tostring(a).." != "..tostring(b)) end
a=add("a",100,100)
''')
lua.execute((root / "sticky.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
update(0); local order=a.stickyPlacement.order
a.parent.y=130; update(.05)
local x,y=render(a,.05); near(x,100); near(y,100)
a.px=120; a.py=120; a.parent.x=180; a.parent.y=150; update(.1)
x,y=render(a,.1); near(x,120); near(y,120)
-- Missing data gets short grace, never a native-frame flyaway.
local saved=a.stickyPlacement
a.px=nil; update(.11); assert(a.stickyPlacement==saved)
a.px=120; update(.12); assert(a.stickyPlacement==saved)
a.px=nil; update(.30); assert(not a.stickyPlacement)
a.px=120; update(.35)
-- Never capture an expanded hitbox or a one-frame resize shift as home.
overlap=true; a.parent.width=120; a.parent.x=60; update(.36)
assert(not a.stickyAnchorCalibration)
a.parent.width=1; a.parent.height=1; update(.37)
assert(not a.stickyAnchorCalibration)
-- A stable, released pre-combat correction is preserved, including home height.
a.parent.x=180; a.parent.y=120; update(.4)
assert(not a.stickyAnchorCalibration)
update(.46)
assert(not a.stickyPlacement and a.stickyAnchorCalibration.x==60)
-- Later native resize/position noise must not overwrite the trusted correction.
a.parent.width=120; a.parent.x=60; update(.47)
a.parent.width=1; update(.48)
assert(a.stickyAnchorCalibration.x==60)
a.parent.x=600; a.parent.y=300; overlap=false; update(.5)
near(a.stickyPlacement.baseX,180); near(a.stickyPlacement.baseY,120)
a.cachedGuid="replacement"; update(.55)
near(a.stickyPlacement.baseX,120); assert(a.stickyPlacement.order>order)
-- Combat before calibration settles cannot retain the transient left offset.
visible={}; local sudden=add("sudden",300,200)
sudden.parent.height=1; sudden.parent.x=240; overlap=true; update(.6)
overlap=false; sudden.parent.width=160; update(.61)
near(sudden.stickyPlacement.baseX,300)
assert(not sudden.stickyCalibrationCandidate)
-- A hovered plate holds its displacement; the neighbour makes room.
visible={}; a=add("hover",100,100); b=add("peer",100,100)
Z.SetPlateLayoutHover(a,a.parent,true)
update(1); render(a,1); render(b,1)
update(1.1); assert(b.stickyPlacement.dy==0)
for i=11,40 do
 local t=1+i*.01; update(t); render(a,t); render(b,t)
end
assert(a.stickyPlacement.dx==0 and a.stickyPlacement.dy==0)
assert(b.stickyPlacement.dy>0 or b.stickyPlacement.dx~=0)
local s=b.stickyPlacement
assert(math.abs(s.dx)<=57.6 and s.dy<=96 and s.dy>=0)
-- Relocation speed is bounded per frame, not snapped to a new slot.
local oldX,oldY=s.displayX,s.displayY
render(b,1.41)
assert(math.abs(s.displayX-oldX)<=1.401 and math.abs(s.displayY-oldY)<=1.401)
Z.SetPlateLayoutHover(b,b.parent,true)
update(1.42); oldX,oldY=s.displayX,s.displayY
for i=43,60 do local t=1+i*.01; update(t); render(b,t) end
near(s.displayX,oldX); near(s.displayY,oldY)
-- Hover protection does not lag genuine world/camera movement.
b.px=125; b.parent.x=125; update(1.61)
x=render(b,1.61); near(x,125+oldX)
Z.SetPlateLayoutHover(b,b.parent,false)
update(1.7); assert(s.hovered)
visible={[b.parent]=b.parent}
for i=81,320 do local t=1+i*.01; update(t); render(b,t) end
near(s.dx,0); near(s.dy,0)
assert(math.abs(s.displayX)<.01 and math.abs(s.displayY)<.01)
-- Hover transfer between overlay/native receivers does not lose protection.
Z.SetPlateLayoutHover(b,b.parent,true); Z.SetPlateLayoutHover(b,b,true)
Z.SetPlateLayoutHover(b,b.parent,false); assert(b.layoutHoverReceiver==b)
Z.SetPlateLayoutHover(b,b,false,true); assert(not b.layoutHoverReceiver)
-- Dense layouts remain bounded instead of building detached towers/columns.
visible={}; pack={}
for i=1,18 do pack[i]=add("pack"..i,200,100) end
for i=0,80 do
 local t=5+i*.01; update(t)
 for _,p in ipairs(pack) do render(p,t) end
end
for _,p in ipairs(pack) do
 local state=p.stickyPlacement
 assert(not state.column and math.abs(state.dx)<=57.6 and state.dy<=96)
 assert(state.displayY<=96.01 and math.abs(state.displayX)<=57.61)
end
-- Overlap, missing API, or toggling off restores native behaviour.
overlap=true; update(6); for _,p in ipairs(pack) do assert(not p.stickyPlacement) end
overlap=false; zAPI=nil; update(6.1); assert(not pack[1].stickyPlacement)
zAPI=function() end; Z.config.nameplates.sticky_placement="0"
update(6.2); assert(not pack[1].stickyPlacement)
-- Preview scenes cannot overwrite the live array or share its solve cadence.
Z.config.nameplates.sticky_placement="1"
visible={}; live=add("live",100,100); update(7)
local original=live.stickyPlacement
local isolated={}; preview=add("preview",400,300)
local demoVisible={[preview.parent]=preview.parent}
Z.UpdateStickyPlacements(7.01,demoVisible,function() return false end,nil,nil,isolated)
assert(live.stickyPlacement==original and #isolated.entries==1)
assert(isolated.entries[1].plate==preview and isolated.nextSolve>7.01)
visible={[live.parent]=live.parent}; update(7.02)
assert(live.stickyPlacement==original and live.stickyPlacement.baseX==100)
local ok=pcall(Z.UpdateStickyPlacements,7.03,demoVisible,function() error("test") end,nil,nil,isolated)
assert(not ok)
update(7.1); assert(live.stickyPlacement.baseX==100) -- Restored even on error.
''')
print("Bounded local placement, hover protection, damping and home-return checks passed")
