"""Sticky slots, collision patience, camera tracking, release and pool safety."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={sticky_placement="1",sticky_delay=".15",sticky_return="1"}}}
zNameplates=Z; zAPI=function() end
UIParent={GetEffectiveScale=function() return 1 end,
 GetWidth=function() return 1000 end,GetHeight=function() return 800 end}
visible={}
function add(id,x,y)
 local f={x=x,y=y}
 function f:GetCenter() return self.x,self.y-10 end
 function f:GetHeight() return 20 end
 function f:GetEffectiveScale() return 1 end
 function f:IsVisible() return true end
 local p={parent=f,cachedGuid=id,px=x,py=y,depth=10}
 function p:GetEffectiveScale() return 1 end
 function p:GetWidth() return 80 end
 function p:GetHeight() return 20 end
 f.nameplate=p; visible[f]=f
 return p
end
Z.GetPlateProjection=function(p) return p.px/1000,p.py/800,p.depth end
overlap=false
function update(t) Z.UpdateStickyPlacements(t,visible,function() return overlap end) end
a=add("a",100,100)
''')
lua.execute((root / "sticky.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
update(0); local order=a.stickyPlacement.order
a.parent.y=130; update(.05)
assert(a.stickyPlacement.baseY==100 and a.stickyPlacement.dy==0)
-- Native stack shuffle is cancelled, whereas matching camera motion is immediate.
local x,y=Z.ApplyStickyPlacement(a,.05,100,130,1,1)
assert(y==-30)
a.px=120; a.py=120; a.parent.x=120; a.parent.y=150; update(.10)
assert(a.stickyPlacement.baseX==120 and a.stickyPlacement.baseY==120)
-- Isolated native position must remain stable for the full release delay.
for i=3,22 do update(i*.05) end
assert(a.stickyPlacement.dy==30)
-- Recycled plate cannot inherit another unit's displacement or ordering.
a.cachedGuid="new"; update(1.15)
assert(a.stickyPlacement.order>order and a.stickyPlacement.dy==0)
-- Start a separate, initially clear scene. Existing plate wins ties.
visible={}; a=add("first",100,100); b=add("second",100,130)
update(2); b.py=110; b.parent.y=110
update(2.05); assert(b.stickyPlacement.dy==0)
update(2.10); assert(b.stickyPlacement.dy==0)
update(2.25)
assert(a.stickyPlacement.dy==0)
assert(math.abs(b.stickyPlacement.baseY+b.stickyPlacement.dy-100)>=22)
-- Slot slide starts smoothly, not an instant full-row jump.
Z.ApplyStickyPlacement(b,2.25,100,110,1,1)
local before=b.stickyPlacement.displayY
Z.ApplyStickyPlacement(b,2.26,100,110,1,1)
assert(math.abs(b.stickyPlacement.displayY-before)>0)
assert(math.abs(b.stickyPlacement.displayY)<math.abs(b.stickyPlacement.dy))
-- Camera/world jumps reset instead of leaving labels over unrelated units.
b.px=500; b.parent.x=500; update(2.30)
assert(b.stickyPlacement.dy==0 and b.stickyPlacement.baseX==500)
overlap=true; update(2.35); assert(not a.stickyPlacement and not b.stickyPlacement)
overlap=false; zAPI=nil; update(2.4); assert(not a.stickyPlacement)
zAPI=function() end; Z.config.nameplates.sticky_placement="0"
update(2.45); assert(not b.stickyPlacement)
Z.config.nameplates.sticky_placement="1"
Z.config.nameplates.collision_buffer_x="5"; Z.config.nameplates.collision_buffer_y="7"
update(2.5); assert(b.stickyPlacement.w==90 and b.stickyPlacement.h==34)
''')
print("Sticky placement checks passed (Lua 5.1)")
