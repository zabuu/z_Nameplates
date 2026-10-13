"""Live dummy combat switch, brightness, foreground layers and scene isolation."""
from pathlib import Path
import runpy

root=Path(__file__).resolve().parents[1]
runtime=runpy.run_path(str(root / "tests/test_settings_ui.py"))
lua=runtime["lua"]
core=(root / "core.lua").read_text(encoding="utf-8-sig")
lua.execute('local Z=zNameplates\n'+core[core.index("function Z.NormalizeWorldProjection("):core.index("function Z.GetPlayerWorldPosition(")])
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetFont(f,s,o) self.font=f; self.fontSize=s; self.fontStyle=o end
function methods:GetFont() return self.font,self.fontSize,self.fontStyle end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetBackdropBorderColor(...) self.borderColor={...} end
function methods:SetStatusBarColor(...) self.barColor={...} end
function methods:SetFrameLevel(v) self.frameLevelValue=v end
function methods:GetFrameLevel() return self.frameLevelValue or 4 end
function methods:GetCenter() return self.x or 100,self.y or 100 end
function methods:EnableMouse(v) self.mouse=v end
table.wipe=function(t) for k in pairs(t) do t[k]=nil end end
Z.media={}; Z.classColors={}; for _,class in ipairs({"WARRIOR","MAGE","ROGUE","HUNTER","WARLOCK"}) do
 Z.classColors[class]={r=1,g=1,b=1,a=1}
end
Z.GetBorderSize=function() return 1,1 end
Z.CreateBackdrop=function(bar) bar.backdrop=bar.backdrop or CreateFrame("Frame",nil,bar) end
Z.PositionLevelText=function() end
Z.ApplyPlateLayers=function(plate,strata,level)
 plate.parent:SetFrameStrata(strata); plate:SetFrameStrata(strata)
 plate.health:SetFrameStrata(strata); plate.castbar:SetFrameStrata(strata)
 plate.parent:SetFrameLevel(level); plate:SetFrameLevel(level+1)
end
TargetUnit=function() error("Preview must never target a unit") end
AttackTarget=function() error("Preview must never start combat") end
local C=Z.config.nameplates
C.dummy_preview="1"; C.dummy_count="5"; C.dummy_in_combat="0"
C.dummy_full_opacity="1"; C.dummy_foreground="1"
C.overlap_enemy="1"; C.overlap_combat="1"
C.name.fontstyle="OUTLINE"; C.name.fontstyle_combat_enabled="1"; C.name.fontstyle_combat="THICKOUTLINE"
C.namefightcolor="1"; C.showcastbar="1"; C.targetcastbar="0"
Z.options.activePage="Preview"; Z.options:Show()
zAPI=nil
''')
lua.execute((root / "dummy.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
Z.StartDummyCluster()
local pack=Z.dummyCluster
local function members()
 local found={}
 for _,f in ipairs(frames) do if f.nameplate and f.nameplate.isDummy then found[#found+1]=f end end
 return found
end
local dummies=members(); assert(#dummies==5)
local first=dummies[1].nameplate; local caster=dummies[2].nameplate
assert(first.dummyInCombat==false and first.overlapEnabled)
assert(first.name.fontStyle=="OUTLINE" and first.name.textColor[2]==1)
assert(not caster.castbar:IsShown())
assert(pack:GetFrameStrata()=="FULLSCREEN" and caster:GetFrameStrata()=="FULLSCREEN")
for _,base in ipairs(dummies) do assert(base.alpha==1) end
local C=Z.config.nameplates
C.dummy_in_combat="1"; Z.StartDummyCluster()
assert(first.dummyInCombat==true and not first.overlapEnabled)
assert(first.name.fontStyle=="THICKOUTLINE" and first.name.textColor[2]==.4)
assert(caster.castbar:IsShown())
assert(caster.health.barColor[2]==.2)
C.dummy_full_opacity="0"; Z.StartDummyCluster()
assert(dummies[2].alpha<1)
C.dummy_full_opacity="1"; Z.StartDummyCluster(); assert(dummies[2].alpha==1)
Z.options.activePage="Health"; invoke(pack,"OnUpdate",.02)
assert(pack:GetFrameStrata()=="BACKGROUND")
Z.options.activePage="Preview"; invoke(pack,"OnUpdate",.02)
assert(pack:GetFrameStrata()=="FULLSCREEN")
C.dummy_foreground="0"; invoke(pack,"OnUpdate",.02)
assert(pack:GetFrameStrata()=="BACKGROUND")
C.dummy_in_combat="0"; Z.StartDummyCluster()
assert(first.name.fontStyle=="OUTLINE" and not caster.castbar:IsShown())
-- Camera-aware dummy samples enter a separate scene, not the live registry.
local reads=0; local solves=0
zAPI=function(command,...)
 reads=reads+1
 if command=="camera" then return 0,0,0,1,0,0,0,1,0 end
 if command=="unitPosition" then return 0,0,0 end
 if command=="worldToScreen" then return .5,.5,25 end
 error("Unexpected native unit lookup for a dummy: "..command)
end
Z.UpdateStickyPlacements=function(now,visible,overlap,target,hover,scene)
 assert(scene and scene~=Z.nameplates); solves=solves+1
 for parent in pairs(visible) do
  assert(parent.nameplate.isDummy and parent.nameplate.dummyProjection)
  assert(overlap(parent.nameplate)==parent.nameplate.overlapEnabled)
 end
end
Z.UpdatePlateTransition=function(plate,now) assert(plate.isDummy); plate.appearanceAlpha=1 end
C.dummy_in_combat="1"; Z.StartDummyCluster()
assert(reads>0 and solves>0 and pack.layoutScene)
C.dummy_preview="0"; Z.StartDummyCluster(); assert(not pack:IsShown())
''')
print("Dummy combat, opacity, foreground layers, native isolation and live toggling passed")
