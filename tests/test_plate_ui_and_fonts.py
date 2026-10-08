"""Combat-colour exclusions, UI click blocking, and scaled font surfaces."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "core.lua").read_text(encoding="utf-8-sig")
helper = source[source.index("function Z.SetSmoothFontString("):source.index("function Z.GetPlateProjection(")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; clock=0; GetTime=function() return clock end
local methods={}
function methods:GetParent() return self.owner end
function methods:SetParent(p) self.owner=p end
function methods:SetAllPoints(p) self.allPoints=p end
function methods:SetScale(v) self.scale=v end
function methods:EnableMouse(v) self.mouse=v end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(i) return unpack(self.points[i]) end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetFont(f,s,o) self.font=f; self.fontSize=s; self.fontStyle=o end
function methods:IsVisible() return self.visible~=false end
function CreateFrame(kind,name,parent) return setmetatable({owner=parent,points={}},{__index=methods}) end
UIParent=CreateFrame("Frame"); WorldFrame=CreateFrame("Frame")
owner=CreateFrame("Frame",nil,WorldFrame)
owner.nameplate={}
font=CreateFrame("FontString",nil,owner)
font:SetPoint("LEFT",owner,"RIGHT",3,-2)
UnitExists=function() return true end
UnitCanAttack=function() return attackable end
UnitAffectingCombat=function() return combat end
''')
lua.execute(helper)
lua.execute('''
attackable=true; combat=true
assert(Z.ShouldUseCombatNameColor({unit="enemy"},true))
assert(not Z.ShouldUseCombatNameColor({unit="friend",isFriendly=true},true))
assert(not Z.ShouldUseCombatNameColor({unit="neutral",isNeutral=true},true))
assert(not Z.ShouldUseCombatNameColor({unit="enemy",taggedByOther=true},true))
attackable=false; assert(not Z.ShouldUseCombatNameColor({unit="enemy"},true))

panel=CreateFrame("Frame",nil,UIParent)
button=CreateFrame("Button",nil,panel)
plateButton=CreateFrame("Button",nil,owner)
foci={plateButton,button}
GetMouseFoci=function() return foci end
assert(Z.IsPlateClickBlocked(1)) -- Plate on top does not steal the window click.
foci={plateButton}; assert(not Z.IsPlateClickBlocked(2))
foci={UIParent,WorldFrame}; assert(not Z.IsPlateClickBlocked(3))
GetMouseFoci=nil; GetMouseFocus=function() return plateButton end
UIPanelWindows={TestPanel={}}; TestPanel=panel
MouseIsOver=function(f) return f==panel end
assert(Z.IsPlateClickBlocked(4))
panel.visible=false; assert(not Z.IsPlateClickBlocked(5))

Z.SetSmoothFontString(font,"test.ttf",12,"OUTLINE")
local surface=font.zSmoothFrame
assert(surface and surface.scale==.25 and surface.mouse==false)
assert(font:GetParent()==surface and font.fontSize==48)
assert(font.points[1][4]==12 and font.points[1][5]==-8)
font:ClearAllPoints(); font:SetPoint("RIGHT",owner,"LEFT",-5,1)
assert(font.points[1][4]==-20 and font.points[1][5]==4)
newOwner=CreateFrame("Frame",nil,owner)
font:SetParent(newOwner)
assert(font:GetParent()==surface and surface:GetParent()==newOwner)
Z.SetSmoothFontString(font,"test.ttf",12.25,"THICKOUTLINE")
assert(font.zSmoothFrame==surface and font.fontSize==49)
assert(font.fontStyle=="THICKOUTLINE")
''')
print("Combat-name exclusions, interface click blocking, and float font-surface checks passed.")
