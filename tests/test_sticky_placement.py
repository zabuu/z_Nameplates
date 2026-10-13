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
-- A single plate cannot stay pinned at the sideways cap by lingering hover.
visible={}; local lone=add("lone",500,300)
update(9.3)
local stuck=lone.stickyPlacement
stuck.dx=-57.6; stuck.displayX=-57.6; stuck.dy=0; stuck.displayY=0
Z.SetPlateLayoutHover(lone,lone.parent,true)
update(9.31); render(lone,9.31)
near(stuck.displayX,-57.6) -- Brief click grace; never snap on isolation.
for i=32,400 do local t=9+i*.01; update(t); render(lone,t) end
assert(stuck.hovered and stuck.returningHome and #stuck.neighbors==0)
near(stuck.dx,0); near(stuck.dy,0)
assert(math.abs(stuck.displayX)<.01 and math.abs(stuck.displayY)<.01)
-- Renewed crowding restores normal hover protection immediately.
local newPeer=add("newPeer",500,300); update(13.1)
assert(not stuck.returningHome and stuck.hovered)
-- Real 1.12 FontStrings lack GetEffectiveScale. Their coordinate space is
-- the quarter-scale font surface, not the full plate. Distant text must not
-- inflate the collision box across the screen and trigger sideways avoidance.
visible={}
local function measured(id,x,y)
 local p=add(id,x,y)
 function p:GetEffectiveScale() return .9 end
 function p:GetCenter() return self.px/.9,(self.py-10)/.9 end
 function p:GetTop() return self.py/.9 end
 local surface={GetEffectiveScale=function() return .225 end}
 local function region(owner,scale,left,right,top,bottom,text)
  return {
   GetParent=function() return owner end,
   IsShown=function() return true end,
   GetLeft=function() return (p.px+left)/scale end,
   GetRight=function() return (p.px+right)/scale end,
   GetTop=function() return (p.py+top)/scale end,
   GetBottom=function() return (p.py+bottom)/scale end,
   GetText=text and function() return text end or nil,
  }
 end
 p.health=region(p,.9,-40,40,0,-20)
 p.name=region(surface,.225,-40,40,14,2,"Visible name")
 return p
end
local leftPlate=measured("leftText",350,450)
local rightPlate=measured("rightText",800,450)
assert(not leftPlate.name.GetEffectiveScale)
for i=0,100 do
 local t=14+i*.01; update(t); render(leftPlate,t); render(rightPlate,t)
end
near(leftPlate.stickyPlacement.contentW,80)
near(leftPlate.stickyPlacement.contentH,34)
near(leftPlate.stickyPlacement.cx,0)
assert(#leftPlate.stickyPlacement.neighbors==0)
near(leftPlate.stickyPlacement.displayX,0)
near(rightPlate.stickyPlacement.displayX,0)
-- Correctly measured names still participate in genuine close collisions.
rightPlate.px=350; rightPlate.parent.x=350
for i=0,100 do local t=16+i*.01; update(t); render(leftPlate,t); render(rightPlate,t) end
assert(#leftPlate.stickyPlacement.neighbors==1)
assert(leftPlate.stickyPlacement.dx~=rightPlate.stickyPlacement.dx or leftPlate.stickyPlacement.dy~=rightPlate.stickyPlacement.dy)
''')
print("Bounded local placement, hover protection, damping and home-return checks passed")
