"""Crowd threshold, health bands, average HP, reuse safety, and exact clicks."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
zNameplates={config={nameplates={cluster_enabled="1",cluster_health_band="20"}}}
zNameplates.GetStringColor=function() return 1,.92,.15,1 end
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
units={}; visible={}; plates={}
UnitExists=function(u) return units[u]~=nil end
UnitGUID=function(u) return u=="target" and target or units[u] and units[u].guid end
UnitHealth=function(u) return units[u].hp end
UnitHealthMax=function(u) return units[u].maximum end
UnitName=function(u) return units[u].name end
UnitLevel=function(u) return units[u].level end
UnitCanAttack=function(p,u) return not units[u].friendly end
UnitIsPlayer=function(u) return units[u].player end
UnitReaction=function(u) return units[u].reaction or 2 end
GetRaidTargetIndex=function(u) return units[u].mark end
local methods={}
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true end
function methods:IsVisible() return self.shown end
function methods:EnableMouse(v) self.mouse=v end
function methods:SetSize(w,h) self.width=w end
function methods:GetWidth() return self.width or 150 end
function methods:SetText(v) self.textValue=v end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetPoint(...) self.point={...} end
function methods:GetEffectiveScale() return 1 end
function methods:SetScale(v) self.scale=v end
function methods:GetFrameStrata() return "LOW" end
function methods:SetFrameStrata(v) self.strata=v end
function methods:GetFrameLevel() return 4 end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetFont() return "font.ttf",12,"OUTLINE" end
function methods:SetFont(f,s,o) self.font=f; self.fontSize=s; self.fontStyle=o end
function methods:SetTextColor(...) self.color={...} end
function methods:SetShadowColor(...) end
function methods:SetShadowOffset(...) end
function methods:CreateFontString() return widget() end
function methods:SetValue(v) self.value=v end
function methods:SetMinMaxValues(a,b) self.minimum=a; self.maximum=b end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetAlpha(a) self.alpha=a end
function methods:Click() clicked=self.nameplate.unit end
function widget() return setmetatable({shown=true},{__index=methods}) end
CreateFrame=function() return widget() end
UIParent=widget()
function add(i,hp,name)
  local u="n"..i
  units[u]={name=name or "Lasher",hp=hp,maximum=100,level=60,guid="g"..i}
  local p=widget(); local f=widget(); f.nameplate=p; p.parent=f
  p.unit=u; p.cachedGuid=units[u].guid; p.platename=u; p.cache={}
  p.name=widget(); p.health=widget(); p.health.text=widget()
  p.raidicon=widget(); p.castbar=widget(); p.debuffs={widget()}
  visible[f]=f; plates[i]=p
end
for i=1,7 do add(i,41+i) end
add(8,70); add(9,78); add(10,90)
add(11,45,"Treant"); add(12,50,"Treant")
add(13,45); units.n13.friendly=true
add(14,45); units.n14.player=true
add(15,45); units.n15.mark=8
add(16,45); target="g16"
add(17,45); plates[17].isCritter=true
add(18,45); units.n18.reaction=4
add(19,45); plates[19].taggedByOther=true
''')
lua.execute((root / "clusters.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
Z=zNameplates
Z.UpdatePlateClusters(0,visible,30,true)
assert(plates[1].clusterGroup==nil) -- Strictly more than 30.
Z.UpdatePlateClusters(.01,visible,31,true)
group=plates[1].clusterGroup
assert(group.count==7 and group.average==45)
assert(plates[8].clusterGroup.count==2)
assert(plates[10].clusterGroup==nil) -- Singleton stays individual.
assert(plates[11].clusterGroup.count==2 and plates[11].clusterGroup~=group)
for i=13,19 do assert(plates[i].clusterGroup==nil) end
hidden=0
for i=1,7 do if plates[i].clusterHidden then hidden=hidden+1 end end
assert(hidden==6)
anchor=group.anchor
Z.RenderPlateCluster(anchor)
assert(anchor.name.textValue=="Lasher" and anchor.health.value==45)
assert(anchor.clusterCountFrame.text.textValue=="x7")
assert(anchor.clusterCountFrame.text.fontSize>=14)
assert(anchor.clusterCountFrame.text.fontStyle=="THICKOUTLINE")
assert(anchor.clusterCountFrame.text.color[1]==1)
assert(anchor.health.text.textValue=="45%")
assert(not anchor.castbar.shown and not anchor.debuffs[1].shown)
Z.ClickPlate(anchor); assert(clicked=="n1")

-- Click uses live health, not the ranking saved on the previous sample.
units.n7.hp=1; Z.ClickPlate(anchor); assert(clicked=="n7")
units.n7.guid="reused"; Z.ClickPlate(anchor); assert(clicked=="n1")
units.n7.guid="g7"; units.n7.hp=77
Z.UpdatePlateClusters(.02,visible,31,false) -- Cadence does not reshuffle mid-frame.
assert(plates[7].clusterGroup==group)
Z.UpdatePlateClusters(.12,visible,31,false)
assert(plates[7].clusterGroup==plates[8].clusterGroup)
assert(plates[1].clusterGroup.count==6)
assert(plates[1].clusterGroup.average==44.5)

-- Target changes instantly remove the target from an aggregate.
target="g2"; Z.UpdatePlateClusters(.13,visible,31,true)
assert(not plates[2].clusterHidden and plates[2].clusterGroup==nil)

-- Disabling or dropping below the threshold immediately restores every overlay.
Z.UpdatePlateClusters(.14,visible,30,false)
for _,p in pairs(plates) do
  assert(p.shown and not p.clusterHidden and not p.clusterGroup)
  if p.clusterCountFrame then assert(not p.clusterCountFrame.shown) end
end
target=nil
Z.UpdatePlateClusters(.15,visible,31,true)
assert(plates[1].clusterGroup)
Z.config.nameplates.cluster_enabled="0"; Z.UpdatePlateClusters(.16,visible,31,false)
for _,p in pairs(plates) do assert(p.shown and not p.clusterGroup) end

-- A new occupant is not left hidden or associated with the old aggregate.
Z.config.nameplates.cluster_enabled="1"; Z.UpdatePlateClusters(.17,visible,31,true)
local member=plates[1].clusterGroup.members[2]
Z.ResetPlateCluster(member)
assert(member.shown and not member.clusterHidden and not member.clusterGroup)
Z.config.nameplates.cluster_threshold="60"
Z.UpdatePlateClusters(.18,visible,51,true)
for _,p in pairs(plates) do assert(not p.clusterGroup) end
''')
print("Nameplate cluster grouping, migration, health display, and click checks passed.")
