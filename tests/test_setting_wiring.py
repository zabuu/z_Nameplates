"""Previously ignored raid-marker placement and cast precision settings."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core=(root/"core.lua").read_text(encoding="utf-8-sig")
plates=(root/"nameplates.lua").read_text(encoding="utf-8-sig")
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={raidiconpos="LEFT",raidiconoffx="2",raidiconoffy="-3"}}}
plate={health={},raidicon={ClearAllPoints=function() end,SetPoint=function(self,...) self.point={...} end}}
C={unitframes={castbardecimals="2"}}; floor=math.floor
castbar={text={SetText=function(self,v) self.value=v end}}
''')
lua.execute(core[core.index("function Z.PositionRaidIcon("):core.index("function Z.GetDefaultSetting(")])
lua.execute(plates[plates.index("  local function SetCastbarText("):plates.index("  -- Shared castbar update logic")] + '''
Z.PositionRaidIcon(plate)
assert(plate.raidicon.point[1]=="RIGHT" and plate.raidicon.point[3]=="LEFT")
assert(plate.raidicon.point[4]==2 and plate.raidicon.point[5]==-3)
Z.config.nameplates.raidiconpos="BOTTOM"
Z.PositionRaidIcon(plate); assert(plate.raidicon.point[1]=="TOP")
for precision=0,3 do
  C.unitframes.castbardecimals=tostring(precision)
  SetCastbarText(castbar,1.234)
  assert(castbar.text.value==string.format("%."..precision.."f",math.floor(1.234*10^precision)/10^precision))
end
''')
print("Raid position and all four cast-time precision settings passed.")
