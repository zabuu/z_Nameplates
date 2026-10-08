"""Keep pooled native visuals invisible without destroying their live data."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
helper = core[core.index("function Z.SuppressNativePlateVisuals("):core.index("function Z.UpdatePlateTransition(")]
start = plates.index('    parent:SetScript("OnUpdate", function()', plates.index("parent.nameplate = nameplate"))
end = plates.index('\n    SetPlateDepthLayer(nameplate, "BACKGROUND", 4)', start)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; zNameplates=Z
function native(kind)
  return {alpha=1,shown=true,value=42,text="Mob",kind=kind,
    GetAlpha=function(self) return self.alpha end,
    SetAlpha=function(self,a) self.alpha=a; self.writes=(self.writes or 0)+1 end}
end
bar=native("StatusBar"); name=native("FontString"); elite=native("Texture")
raid=native("Texture")
nameplate={original={healthbar=bar,name=name,levelicon=elite},raidicon=raid,alpha=1,
  cachedAlpha=.8,positionTransition={identity="old"},
  SetAlpha=function(self,a) self.alpha=a end}
parent={nameplate=nameplate,scripts={}}
function parent:GetScript(k) return self.scripts[k] end
function parent:SetScript(k,v) self.scripts[k]=v end
parent.scripts.OnShow=function(self)
  assert(self==parent); originalCalled=true
  bar.alpha=1; name.alpha=1; elite.alpha=1
end
''')
lua.execute(helper)
lua.execute(plates[start:end])
lua.execute('''
assert(bar.alpha==0 and name.alpha==0 and elite.alpha==0)
local writes=bar.writes
parent.scripts.OnUpdate()
assert(bar.writes==writes) -- No redundant native opacity writes.
-- The native pool resets visual values when assigned a new occupant.
bar.alpha=1; name.alpha=1; elite.alpha=1
parent.scripts.OnShow()
assert(originalCalled)
assert(bar.alpha==0 and name.alpha==0 and elite.alpha==0)
assert(nameplate.alpha==0 and nameplate.cachedAlpha==nil)
assert(nameplate.positionTransition==nil)
-- Later native writes are suppressed independently of central throttling.
bar.alpha=1; name.alpha=1; parent.scripts.OnUpdate()
assert(bar.alpha==0 and name.alpha==0)
-- These regions still provide data, including visibility-based elite detection.
assert(bar.shown and name.shown and elite.shown)
assert(bar.value==42 and name.text=="Mob")
assert(raid.alpha==1) -- Raid markers are intentionally reused by zNP.
Z.SuppressNativePlateVisuals(nil)
Z.SuppressNativePlateVisuals({})
''')
print("Native plate suppression checks passed (Lua 5.1).")
