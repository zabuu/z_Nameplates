"""Share player reads across real colour paths, without caching across events."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; zNameplates=Z; now=1; playerCombat=true; playerReads=0; unitReads=0
GetTime=function() return now end
UnitAffectingCombat=function(unit)
 if unit=="player" then playerReads=playerReads+1; return playerCombat end
 unitReads=unitReads+1; return true
end
UnitExists=function() return true end
UnitCanAttack=function() return true end
UnitCanAssist=function() return false end
UnitGUID=function() return nil end
UnitName=function() return "enemy" end
UnitIsUnit=function() return false end
GetCastInfo=function() return nil end
frameState={now=now}; combatColorCache={}; threatMemory={}; raidGuidCache={}; cfg={}
NULL_GUID="0x0000000000000000"
nameplates={SetScript=function(self,key,handler) self[key]=handler end}
''')
lua.execute("local Z=zNameplates\n" + core[core.index("function Z.ShouldUseCombatNameColor("):
                                           core.index("local function PlateMouseFocusKind(")])
lua.execute("local Z=zNameplates\n" + core[core.index("function Z.GetPlayerCombatState("):
                                           core.index("function Z.NextPlateDataRefresh(")])
colors = plates[plates.index("  local function GetCombatStateColor("):
                plates.index("  local function ShouldOverlap(")]
lua.execute(colors + "\ngetCombatColor=GetCombatStateColor; inCombatWithPlayer=IsCombatWithPlayer")
start = plates.index('  nameplates:SetScript("OnEvent", function()')
lua.execute(plates[start:plates.index("    -- Stop event handling", start)] + "end)")
assert 'nameplates:RegisterEvent("PLAYER_REGEN_DISABLED")' in plates
assert 'nameplates:RegisterEvent("PLAYER_REGEN_ENABLED")' in plates
lua.execute('''
for i=1,50 do
 assert(Z.ShouldUseCombatNameColor({unit="nameplate"..i},true,now))
 assert(getCombatColor("guid"..i,"nameplate"..i)==false)
end
assert(playerReads==1 and unitReads==100)
-- Friendly/neutral/other-tapped names never become combat red or add queries.
local before=unitReads
assert(not Z.ShouldUseCombatNameColor({unit="friendly",isFriendly=true},true,now))
assert(not Z.ShouldUseCombatNameColor({unit="neutral",isNeutral=true},true,now))
assert(not Z.ShouldUseCombatNameColor({unit="tapped",taggedByOther=true},true,now))
assert(not Z.ShouldUseCombatNameColor({unit="disabled"},false,now))
assert(unitReads==before and playerReads==1)
-- An actual transition between callers at the same timestamp invalidates the
-- shared sample; it is never held until the next .1/.2/.5 second data tick.
playerCombat=false; event="PLAYER_REGEN_ENABLED"; nameplates.OnEvent()
assert(not Z.ShouldUseCombatNameColor({unit="enemy"},true,now) and playerReads==2)
assert(getCombatColor("guid1","nameplate1")==false and playerReads==2)
playerCombat=true; event="PLAYER_REGEN_DISABLED"; nameplates.OnEvent()
assert(Z.ShouldUseCombatNameColor({unit="enemy"},true,now) and playerReads==3)
event="UNIT_FLAGS"; arg1="nameplate1"; nameplates.OnEvent()
assert(Z.GetPlayerCombatState(now) and playerReads==3)
arg1="player"; playerCombat=false; nameplates.OnEvent()
assert(not Z.GetPlayerCombatState(now) and playerReads==4)
event="PLAYER_ENTERING_WORLD"; playerCombat=true; nameplates.OnEvent()
assert(Z.GetPlayerCombatState(now) and playerReads==5)
now=1.001; assert(Z.GetPlayerCombatState(now) and playerReads==6)
-- Replacing the extension's API also refreshes the cached result immediately.
UnitAffectingCombat=function(unit) if unit=="player" then playerReads=playerReads+1; return false end; return true end
assert(not Z.GetPlayerCombatState(now) and playerReads==7)
''')
print("Player combat cache: 100 real colour consumers use one player read; event/API invalidation and colour exclusions passed.")
