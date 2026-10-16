"""Both native/overlay receivers respect friendly click-through, including spells."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
start = source.index("    local overlapEnabled = ShouldOverlap(nameplate)", source.index("-- OVERLAP/CLICKTHROUGH HANDLING"))
end = source.index("    -- Target styling", start)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
C={nameplates={clickthrough="0",clickthrough_friendly="1",vertical_offset="0"}}
floor=math.floor
abs=math.abs
ShouldOverlap=function() return overlap end
ReleaseAtScreenEdge=function() return false end
SpellIsTargeting=function() return targeting end
mouseWrites=0
function widget()
 local w={mouse=false,width=80,height=20,dwidth=1}
 function w:EnableMouse(v) self.mouse=v; mouseWrites=mouseWrites+1 end
 function w:IsMouseEnabled() if legacyBooleans then return self.mouse and 1 or nil end return self.mouse end
 function w:GetWidth() return self.width end
 function w:GetHeight() return self.height end
 function w:GetSize() return self.width,self.height end
 function w:GetScale() return 1 end
 function w:SetSize(a,b) self.width=a; self.height=b end
 return w
end
frame=widget(); nameplate=widget()
''')
lua.execute("function update()\n" + source[start:end] + "\nend")
lua.execute('''
for _, stacked in ipairs({false,true}) do
 for _, spell in ipairs({false,true}) do
  overlap=stacked; targeting=spell
  nameplate.isFriendly=true; update()
  assert(not frame.mouse and not nameplate.mouse)
  nameplate.isFriendly=false; update()
  if not stacked then assert(frame.mouse and not nameplate.mouse)
  else assert(not frame.mouse and nameplate.mouse==not spell) end
 end
end
overlap=false; targeting=false; nameplate.isNeutral=true; update(); assert(frame.mouse)
C.nameplates.clickthrough="1"; update(); assert(not frame.mouse and not nameplate.mouse)
C.nameplates.clickthrough_friendly="0"; C.nameplates.clickthrough="0"
nameplate.isFriendly=true; update(); assert(frame.mouse)
C.nameplates.collision_buffer_x="5"; C.nameplates.collision_buffer_y="7"
update(); assert(frame.width==90 and frame.height==34)
assert(nameplate.width==80 and nameplate.height==20)
-- World-owned mode releases the native collision rectangle even with overlap
-- disabled; its overlay keeps the established friendly/spell click-through rules.
nameplate.worldPlacementOwned=true; overlap=false
for _,spell in ipairs({false,true}) do
 targeting=spell
 nameplate.isFriendly=true; C.nameplates.clickthrough_friendly="1"; update()
 assert(frame.width==1 and frame.height==1 and not frame.mouse and not nameplate.mouse)
 nameplate.isFriendly=false; update()
 assert(not frame.mouse and nameplate.mouse==not spell)
end
targeting=false; nameplate.worldPlacementHidden=true; update()
assert(not frame.mouse and not nameplate.mouse)
nameplate.worldPlacementHidden=nil; nameplate.worldPlacementOwned=false
update(); assert(frame.mouse and frame.width==90 and frame.height==34)
-- Stable ownership must not rewrite mouse focus, including 1/nil clients.
for _,legacy in ipairs({false,true}) do
 legacyBooleans=legacy
 for _,spell in ipairs({false,true}) do
  targeting=spell; nameplate.worldPlacementOwned=true; update()
  local before=mouseWrites
  for i=1,120 do update() end
  assert(mouseWrites==before)
  assert(nameplate.mouse==not spell and not frame.mouse)
 end
end
nameplate.uiClickBlocked=true; update()
assert(not frame.mouse and not nameplate.mouse)
local before=mouseWrites
for i=1,120 do update() end
assert(mouseWrites==before)
nameplate.uiClickBlocked=nil; targeting=false; update()
assert(nameplate.mouse and not frame.mouse)
''')
print("Friendly click-through checks passed")
