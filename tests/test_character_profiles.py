"""Existing saves win; inherited profiles are independent; copies retain backups."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "core.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; zNameplates=Z; addon="z_Nameplates"; ADDON=addon
name="Zabbu"; GetRealmName=function() return "Test realm" end
UnitName=function() return name end
function CopyTable(s)
  local d={}; for k,v in pairs(s) do d[k]=type(v)=="table" and CopyTable(v) or v end; return d
end
function MergeMissing(t,s)
  for k,v in pairs(s) do
    if type(v)=="table" then t[k]=t[k] or {}; MergeMissing(t[k],v)
    elseif t[k]==nil then t[k]=v end
  end
end
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
defaults={nameplates={width="120",distance_min_scale="58"},profiles={source="@default"}}
MigrateNameplateSettings=function() end; RebaseTable=function() end
ImportKnown=function() end; InitFlightPaths=function() end; UpdateFonts=function() end
Z.Refresh=function() end; Z.ApplyBlizzardXPText=function() end
function CreateFrame() return {RegisterEvent=function() end,UnregisterEvent=function() end,
  SetScript=function(self,k,v) self[k]=v end} end
''')
start=source.index("function Z.CharacterProfileKey()")
lua.execute(source[start:] + '\nZ.testLoader=loader')
lua.execute('''
function load(db)
  zNameplatesDB=db; this=Z.testLoader; arg1=ADDON; this.OnEvent()
end
original={nameplates={width="177",distance_min_scale="71",unknown="preserve"},custom={value="untouched"}}
zabbu={config=CopyTable(original),knownFlightPaths={A=true},arbitraryLegacy={keep=true}}
load(zabbu)
assert(Z.config==zabbu.config)
assert(Z.config.nameplates.width=="177" and Z.config.custom.value=="untouched")
assert(zabbu.knownFlightPaths.A and zabbu.arbitraryLegacy.keep)
assert(zabbu.profileMigrationSnapshot.nameplates.width=="177")
assert(zNameplatesProfiles.defaultConfig.nameplates.width=="177")
assert(zNameplatesProfiles.defaultConfig~=Z.config)
Z.config.nameplates.width="180"
assert(zNameplatesProfiles.defaultConfig.nameplates.width=="177")

-- New characters inherit an independent copy, not a shared live table.
name="Alt"; local alt={}; load(alt)
assert(alt.config.nameplates.width=="177" and alt.config~=zabbu.config)
alt.config.nameplates.width="201"
assert(zabbu.config.nameplates.width=="180")
assert(zNameplatesProfiles.defaultConfig.nameplates.width=="177")

-- Another existing character keeps its settings even when account defaults exist.
name="Bank"; bank={config={nameplates={width="95"}},knownFlightNPCs={B=true}}
load(bank)
assert(bank.config.nameplates.width=="95" and bank.knownFlightNPCs.B)
local choices=Z.GetCharacterProfileChoices(); assert(#choices==3)
local current=Z.config
assert(Z.CopyCharacterProfile("Test realm / Zabbu"))
assert(Z.config==current and bank.config==current) -- Runtime root references stay valid.
assert(bank.config.nameplates.width=="180")
assert(zabbu.config.nameplates.width=="180")
assert(bank.profileRestorePoints[1].config.nameplates.width=="95")
assert(bank.profileMigrationSnapshot.nameplates.width=="95")
assert(Z.RestoreOriginalCharacterProfile())
assert(bank.config.nameplates.width=="95" and #bank.profileRestorePoints==2)
Z.SetNewCharacterDefault()
assert(zNameplatesProfiles.defaultConfig.nameplates.width=="95")
assert(zNameplatesProfiles.defaultHistory[1].config.nameplates.width=="177")
assert(alt.config.nameplates.width=="201")

-- Relogging never replaces the original snapshot or character's edits.
bank.config.nameplates.width="99"; load(bank)
assert(bank.config.nameplates.width=="99")
assert(bank.profileMigrationSnapshot.nameplates.width=="95")
-- Recover an absent local config from its account copy, not the default.
name="Alt"; local recovered={}; load(recovered)
assert(recovered.config.nameplates.width=="201")
''')
print("Per-character migration, inherited defaults, isolation, restore points, and recovery passed.")
