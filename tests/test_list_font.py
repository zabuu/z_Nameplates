"""List copies logical font size without changing the world-plate surface."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "options.lua").read_text(encoding="utf-8-sig")
helper = source[source.index("  local function SetListFont("):source.index("  local function SetListTextColor(")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={use_unitfonts="1",name={fontstyle="OUTLINE"}},
  global={font_unit_size="10"}},font_unit="unit.ttf"}
destination={SetFont=function(self,f,s,o) self.font=f; self.size=s; self.flags=o end}
plateFont={zSmoothFrame={},GetFont=function() return "unit.ttf",48,"OUTLINE" end}
regularFont={GetFont=function() return "unit.ttf",10,"OUTLINE" end}
''')
lua.execute(helper + '''
SetListFont(destination,plateFont,11)
assert(destination.size==12 and destination.flags=="OUTLINE")
assert(select(2,plateFont:GetFont())==48) -- World plate is unchanged.
SetListFont(destination,regularFont,9)
assert(destination.size==10)
SetListFont(destination,nil,11)
assert(destination.size==10 and destination.font=="unit.ttf")
''')
print("List font sizing checks passed; world-plate fonts are unchanged.")
