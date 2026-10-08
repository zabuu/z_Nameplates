"""Simulate native parent layer cascades, strata resets, and drift repair."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
zNameplates={}; SlashCmdList={}; writes=0
local methods={}
function methods:GetFrameStrata() return self.strata end
function methods:GetFrameLevel() return self.layerLevel end
function methods:SetFrameStrata(s)
  writes=writes+1; self.strata=s
  -- Client behaviour: strata changes reset nested levels.
  for _,child in ipairs(self.children) do child:SetFrameStrata(s); child.layerLevel=0 end
end
function methods:SetFrameLevel(n)
  writes=writes+1; local delta=n-self.layerLevel; self.layerLevel=n
  for _,child in ipairs(self.children) do child:SetFrameLevel(child.layerLevel+delta) end
end
function methods:IsShown() return true end
function methods:IsVisible() return true end
function methods:GetAlpha() return 1 end
function methods:GetWidth() return 100 end
function methods:GetHeight() return 10 end
function methods:GetMinMaxValues() return 0,100 end
function methods:GetValue() return 45 end
function frame(parent)
  local f=setmetatable({strata="BACKGROUND",layerLevel=0,children={}},{__index=methods})
  if parent then parent.children[#parent.children+1]=f end
  return f
end
native=frame(); plate=frame(native); plate.parent=native
plate.health=frame(plate); plate.health.backdrop=frame(plate.health)
plate.textframe=frame(plate)
plate.name={zSmoothFrame=frame(plate.textframe)}
plate.guild={zSmoothFrame=frame(plate.textframe)}
plate.level={zSmoothFrame=frame(plate.textframe)}
plate.castbar=frame(plate.health); plate.castbar.backdrop=frame(plate.castbar)
plate.castbar.icon=frame(plate.castbar); plate.castbar.icon.backdrop=frame(plate.castbar.icon)
plate.debuffs={frame(plate)}; plate.debuffs[1].cd=frame(plate.debuffs[1])
plate.debuffs[1].backdrop=frame(plate.debuffs[1])
plate.combopoints={frame(plate)}; plate.raidiconframe=frame(plate)
plate.clusterCountFrame=frame(native)
''')
lua.execute((root / "layers.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
Z=zNameplates
function check(s,b)
  assert(plate.health.strata==s and plate.health.layerLevel==b+3)
  assert(plate.health.backdrop.strata==s and plate.health.backdrop.layerLevel==b+2)
  assert(plate.castbar.layerLevel==b+4 and plate.castbar.backdrop.layerLevel==b+3)
  assert(plate.castbar.icon.layerLevel==b+5 and plate.castbar.icon.backdrop.layerLevel==b+4)
  assert(plate.debuffs[1].layerLevel==b+4 and plate.debuffs[1].cd.layerLevel==b+5)
  assert(plate.combopoints[1].layerLevel==b+6 and plate.raidiconframe.layerLevel==b+7)
  assert(plate.textframe.strata==s and plate.textframe.layerLevel==b+8)
  assert(plate.name.zSmoothFrame.strata==s and plate.name.zSmoothFrame.layerLevel==b+9)
  assert(plate.clusterCountFrame.layerLevel==b+10)
end
Z.ApplyPlateLayers(plate,"LOW",10); check("LOW",10)
local before=writes
Z.ApplyPlateLayers(plate,"LOW",10); Z.RepairPlateTextLayers(plate)
assert(writes==before) -- Healthy layers do not generate setters every frame.
Z.ApplyPlateLayers(plate,"HIGH",10); check("HIGH",10) -- Same base, different strata.
Z.ApplyPlateLayers(plate,"MEDIUM",20); check("MEDIUM",20)
plate.health.backdrop.layerLevel=100
plate.textframe.strata="BACKGROUND"; plate.textframe.layerLevel=0
plate.name.zSmoothFrame.layerLevel=0
Z.RepairPlateTextLayers(plate); check("MEDIUM",20)
-- A newly created aura with a backdrop is fixed even if cached depth is unchanged.
plate.debuffs[2]=frame(plate); plate.debuffs[2].backdrop=frame(plate.debuffs[2])
Z.ApplyPlateLayers(plate,"MEDIUM",20)
assert(plate.debuffs[2].layerLevel==24 and plate.debuffs[2].backdrop.layerLevel==23)
-- Diagnostics tolerate optional regions and resolve via the exact GUID.
messages={}; DEFAULT_CHAT_FRAME={AddMessage=function(self,m) messages[#messages+1]=m end}
UnitExists=function(u) return u=="target" end
UnitGUID=function() return "guid" end
UnitName=function() return "Test Mob" end
C_NamePlate={GetNamePlateForUnit=function() return nil end}
plate.cachedGuid="guid"; native.nameplate=plate
Z.nameplates={visiblePlates={[native]=native}}
SlashCmdList.ZNPDUMP()
assert(#messages>5 and string.find(messages[1],"Test Mob"))
''')
print("Explicit layer ordering, strata resets, no-op repairs, and znpdump checks passed.")
