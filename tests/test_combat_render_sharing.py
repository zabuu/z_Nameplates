"""Combat relation reads are shared per render, with live independent calls."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")
source = (ROOT / "nameplates.lua").read_text(encoding="utf-8-sig")
baseline = ROOT.parent / "_zSuiteMaintenance/combat-render-2026-10-24/before/z_Nameplates/nameplates.lua"
BOOT = r'''
Z={};zNameplates=Z;clock=1;reads=0;clockReads=0;playerCombat=true
GetTime=function() clockReads=clockReads+1;return clock end
states={};pack={};cfg={overlap_enemy=true,overlap_combat=true}
function state(u) return states[string.gsub(u,"target$","")] end
UnitExists=function(u) reads=reads+1;return state(u).exists end
UnitCanAssist=function(_,u) reads=reads+1;return state(u).assist end
UnitAffectingCombat=function(u) if u=="player" then return playerCombat end;reads=reads+1;return state(u).combat end
UnitThreatSituation=function(_,u) reads=reads+1;return state(u).threat end
UnitGUID=function(u) reads=reads+1;return state(u).target and "targetGuid" end
UnitIsUnit=function(u,_) reads=reads+1;return state(u).playerTarget end
for i=1,50 do
 local u="nameplate"..i;pack[i]={unit=u,cachedGuid="guid"..i,isNeutral=true}
 states[u]={exists=true,combat=true,threat=math.mod(i,2),target=true,playerTarget=math.mod(i,3)==0}
end
'''


def runtime(text):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute(BOOT)
    vm.execute("local Z=Z\n" + core[core.index("function Z.GetPlayerCombatState("):
                                       core.index("function Z.NextPlateDataRefresh(")])
    start = text.index("  local function IsCombatWithPlayer(")
    vm.execute(text[start:text.index("  local function ExactUnitDistance(", start)]
               + "\nrelation=IsCombatWithPlayer;overlap=ShouldOverlap")
    vm.execute(r'''
Z.plateRenderContext={now=1,serial=1,active=true}
for _,p in ipairs(pack) do
 local expected=states[p.unit].threat>0 or states[p.unit].playerTarget or nil
 assert(overlap(p)==(not expected))
 assert(relation(p)==expected);assert(relation(p)==expected)
end
''')
    return vm


new = runtime(source)
if baseline.is_file():
    old = runtime(baseline.read_text(encoding="utf-8-sig"))
    assert old.globals().reads == new.globals().reads * 3
    assert old.globals().clockReads == 150 and new.globals().clockReads == 0
    print("PASS 50 plates, three consumers: combat native reads %d -> %d; clock reads 150 -> 0"
          % (old.globals().reads, new.globals().reads))
new.execute(r'''
local p=pack[1];local s=states[p.unit];local render=Z.plateRenderContext
-- Same timestamp, fresh render: no throttling of combat/threat changes.
s.threat=0;s.target=false;render.serial=2
assert(not relation(p));local before=reads
assert(not relation(p) and reads==before) -- Nil/false answers are also shared.
s.target=true;s.playerTarget=true;render.serial=3;assert(relation(p))
-- Recycled identity and token invalidate in the same render.
p.cachedGuid="replacement";before=reads;assert(relation(p) and reads>before)
p.unit="nameplate2";states[p.unit].threat=0;states[p.unit].target=false
assert(not relation(p))
-- Every provider replacement invalidates without waiting for another frame.
for _,key in ipairs({"UnitExists","UnitCanAssist","UnitAffectingCombat","UnitThreatSituation","UnitGUID","UnitIsUnit"}) do
 local original=_G[key];_G[key]=function(a,b) return original(a,b) end
 before=reads;assert(not relation(p) and reads>before)
end
playerCombat=false;Z.playerCombatTime=nil;assert(not relation(p))
playerCombat=true;Z.playerCombatTime=nil
render.serial=4;states[p.unit].exists=false;before=reads
assert(not relation(p) and reads==before+1)
before=reads;assert(not relation(p) and reads==before)
states[p.unit].exists=true;render.serial=5;states[p.unit].assist=true
assert(not relation(p));states[p.unit].assist=false;states[p.unit].combat=false
render.serial=6;assert(not relation(p))
-- Outside a central render, relation changes are visible on every call.
render.active=false;states[p.unit].combat=true;states[p.unit].threat=1
assert(relation(p));states[p.unit].threat=0;states[p.unit].target=false
assert(not relation(p))
-- The relation is irrelevant when combat overlap is off for a non-neutral.
cfg.overlap_combat=false;p.isNeutral=false;before=reads
assert(overlap(p)==true and reads==before)
-- Neutral safety still requests a live combat relation.
p.isNeutral=true;states[p.unit].threat=1;assert(overlap(p)==false and reads>before)
''')
print("PASS threat/target changes, failed associations, false result reuse, same-time new renders, recycling, six API replacements, independent live calls and neutral/overlap policy")
