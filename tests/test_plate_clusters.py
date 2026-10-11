"""Range clusters, debuff subgroups, reuse safety, preview, and exact clicks."""
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
function methods:GetHeight() return self.height or 8 end
function methods:GetValue() return self.value end
function methods:GetText() return self.textValue end
function methods:ClearAllPoints() self.point=nil end
function methods:CreateTexture() return widget() end
function methods:SetTexture(v) self.texture=v end
function methods:GetTexture() return self.texture end
function methods:SetVertexColor(...) self.vertex={...} end
function methods:GetStatusBarColor() return .7,.1,.1,1 end
function methods:GetStatusBarTexture() return widget() end
function methods:SetAllPoints() end
function methods:SetShown(v) self.shown=v end
function methods:SetJustifyH(v) self.justify=v end
function methods:SetOrientation(v) self.orientation=v end
function methods:SetStatusBarTexture(v) self.texture=v end
function methods:SetStatusBarColor(...) self.barColor={...} end
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
assert(group.count==10 and group.average==55.3)
assert(plates[8].clusterGroup==group and plates[10].clusterGroup==group)
assert(group.minimum==42 and group.maximum==90)
assert(plates[11].clusterGroup.count==2 and plates[11].clusterGroup~=group)
for i=13,19 do assert(plates[i].clusterGroup==nil) end
hidden=0
for i=1,10 do if plates[i].clusterHidden then hidden=hidden+1 end end
assert(hidden==9)
anchor=group.anchor
Z.RenderPlateCluster(anchor)
assert(anchor.name.textValue=="Lasher" and anchor.health.value==42)
assert(anchor.clusterCountFrame.text.textValue=="x10")
assert(anchor.clusterCountFrame.text.fontSize>=14)
assert(anchor.clusterCountFrame.text.fontStyle=="THICKOUTLINE")
assert(anchor.clusterCountFrame.text.color[1]==1)
assert(anchor.health.text.textValue=="42–90%")
assert(anchor.clusterRangeTexture.shown)
assert(math.abs(anchor.clusterRangeTexture.width-150*.48)<.001)
assert(anchor.clusterRangeTexture.vertex[4]==.4)
assert(not anchor.castbar.shown and not anchor.debuffs[1].shown)
Z.ClickPlate(anchor); assert(clicked=="n1")

-- Click uses live health, not the ranking saved on the previous sample.
units.n7.hp=1; Z.ClickPlate(anchor); assert(clicked=="n7")
units.n7.guid="reused"; Z.ClickPlate(anchor); assert(clicked=="n1")
units.n7.guid="g7"; units.n7.hp=77
Z.UpdatePlateClusters(.02,visible,31,false) -- Cadence does not reshuffle mid-frame.
assert(plates[7].clusterGroup==group)
Z.UpdatePlateClusters(.12,visible,31,false)
assert(plates[7].clusterGroup==group and plates[8].clusterGroup==group)
assert(group.count==10 and group.average==58.2)
-- Whitelist order chooses a unique subgroup, independent of HP.
C_UnitAuras={GetUnitAuras=function(u,filter)
 assert(filter=="HARMFUL")
 return units[u].auras or {}
end}
units.n1.auras={{name="Polymorph"}}; units.n2.auras={{name="Polymorph"}}
units.n3.auras={{name="Fear"}}; units.n5.auras={{name="Fear"}}
units.n4.auras={{name="Fear"},{name="Polymorph"}}
Z.config.nameplates.cluster_debuff_whitelist=" Polymorph #Fear "
Z.UpdatePlateClusters(.121,visible,31,true)
assert(plates[1].clusterGroup.count==3 and plates[1].clusterGroup.debuff=="Polymorph")
assert(plates[4].clusterGroup==plates[1].clusterGroup)
assert(plates[3].clusterGroup.count==2 and plates[3].clusterGroup.debuff=="Fear")
assert(plates[6].clusterGroup.count==5 and plates[6].clusterGroup.debuff=="")
units.n2.auras={} -- Aura removal moves the member back to the normal group.
Z.UpdatePlateClusters(.122,visible,31,true)
assert(plates[2].clusterGroup==plates[6].clusterGroup)
C_UnitAuras=nil; Z.UpdatePlateClusters(.123,visible,31,true)
assert(plates[1].clusterGroup.count==10) -- Safe fallback without the aura API.
Z.config.nameplates.cluster_debuff_whitelist=""

-- Target changes instantly remove the target from an aggregate.
target="g2"; Z.UpdatePlateClusters(.13,visible,31,true)
assert(not plates[2].clusterHidden and plates[2].clusterGroup==nil)

-- Disabling or dropping below the threshold immediately restores every overlay.
Z.UpdatePlateClusters(.14,visible,30,false)
for _,p in pairs(plates) do
  assert(p.shown and not p.clusterHidden and not p.clusterGroup)
  if p.clusterCountFrame then assert(not p.clusterCountFrame.shown) end
  if p.clusterRangeTexture then assert(not p.clusterRangeTexture.shown) end
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
-- Settings preview uses the same renderer and never scans fabricated units.
Z.config.nameplates.cluster_debuff_whitelist="Polymorph#Fear"
Z.config.nameplates.name={fontsize="10"}
Z.config.nameplates.dummy_cluster_min="25"; Z.config.nameplates.dummy_cluster_max="85"
local preview=widget(); Z.RefreshClusterPreview(preview)
assert(#preview.samples==3)
assert(preview.samples[1].health.value==25)
assert(preview.samples[1].health.text.textValue=="25–85%")
assert(preview.samples[2].clusterGroup.debuff=="Polymorph")
assert(preview.samples[3].clusterDebuffLabel.textValue=="Fear")
Z.config.nameplates.dummy_cluster_max="25"; Z.RefreshClusterPreview(preview)
assert(not preview.samples[1].clusterRangeTexture.shown)
''')
print("Nameplate cluster grouping, migration, health display, and click checks passed.")
