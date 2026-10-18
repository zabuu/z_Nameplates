"""Count actual chat writes; exercise motion, reuse and cache invalidation."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "chat.lua").read_text(encoding="utf-8-sig")
tree = ast.parse((root / "tests/test_plate_chat.py").read_text(encoding="utf-8-sig"))
bootstrap = next(ast.literal_eval(n.value.args[0]) for n in tree.body
                 if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
                 and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")


def runtime(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(bootstrap)
    lua.execute(r'''
local methods=getmetatable(UIParent).__index
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent=parent end
function methods:GetPoint() if self.point then return unpack(self.point) end end
function methods:GetNumPoints() return self.point and 1 or 0 end
function methods:GetFont() if self.font then return unpack(self.font) end end
function methods:GetText() return self.value end
function methods:GetTextColor() if self.color then return unpack(self.color) end end
calls={}; metrics={}
for _,name in ipairs({"SetText","SetFont","SetWidth","SetHeight","SetPoint","ClearAllPoints",
    "SetFrameStrata","SetFrameLevel","SetScale","SetAlpha","SetTextColor","SetVertexColor",
    "SetJustifyH","SetJustifyV","Show","Hide","SetParent"}) do
  local operation,original=name,methods[name]
  methods[operation]=function(self,...)
    calls[operation]=(calls[operation] or 0)+1
    return original(self,...)
  end
end
for _,name in ipairs({"GetStringWidth","GetStringHeight"}) do
  local operation,original=name,methods[name]
  methods[operation]=function(self,...)
    metrics[operation]=(metrics[operation] or 0)+1
    return original(self,...)
  end
end
function resetCalls() calls={}; metrics={} end
function totalCalls() local n=0; for _,v in pairs(calls) do n=n+v end; return n end
zNameplates.config.platechat.enabled="1"
zNameplates.config.nameplates.name={fontsize="10",fontsize_friendly="11"}
''')
    lua.execute(code)
    lua.execute("zNameplates.RefreshPlateChat()")
    return lua


def measure_static_chat(code, projected=False):
    lua = runtime(code)
    lua.execute('''
projectionCalls=0; projectedX=.5
zAPI=function(command)
  if command=="projectNameplate" or command=="projectUnit" then
    projectionCalls=projectionCalls+1; return projectedX,.6,10,0,0,2
  end
end
''')
    if projected:
        lua.execute('zNameplates.config.platechat.show_without_plate="1"; fire("CHAT_MSG_SAY","Hello","Me")')
    else:
        lua.execute('fire("CHAT_MSG_SAY","Hello","Bob")')
    lua.execute('''
tick(0); resetCalls(); projectionCalls=0
for i=1,25 do tick(i*.04) end
''')
    return {"writes": lua.eval("totalCalls()"), "metrics": sum(lua.globals().metrics.values()),
            "projections": lua.globals().projectionCalls}


def chat_visual_trace(code):
    """Deterministic visual snapshots, also usable against a pre-change source."""
    lua = runtime(code)
    lua.execute(r'''
snapshots={}
local function snapshot(label)
  local p,r,rp,x,y=label:GetPoint()
  local row={label:IsShown(),label.text.value,label:GetWidth(),label:GetHeight(),
    label:GetFrameStrata(),label:GetFrameLevel(),label:GetEffectiveScale(),label:GetAlpha(),
    p,r==label.chatOwner.name,rp,x,y,label.text.font[1],label.text.font[2],label.text.font[3],
    label.text.align,label.text.color[1],label.text.color[2],label.text.color[3],label.text.color[4]}
  for _,piece in ipairs(label.background) do
    for _,v in ipairs({piece.point[4],piece.point[5],piece.width,piece.height,
        piece.color[1],piece.color[2],piece.color[3],piece.color[4]}) do row[#row+1]=v end
  end
  snapshots[#snapshots+1]=row
end
local C=zNameplates.config.platechat
fire("CHAT_MSG_GUILD","Visual parity","Bob"); tick(0); local label=plate.chatLabel; snapshot(label)
for i,position in ipairs({"LEFT","RIGHT","TOP","BOTTOM"}) do
  C.position=position; C.x=tostring(i*3); C.y=tostring(-i)
  C.width=tostring(80+i*10); C.fontsize=tostring(10+i)
  C.background_color=".2,.3,.4,1"; C.background_opacity=".15"
  tick(i*.1); snapshot(label)
end
C.opacity=".7"; plate:SetScale(.53217); base:SetAlpha(.2); plate:SetAlpha(0)
tick(.5); snapshot(label)
plate:SetScale(.495321); visual(label); snapshot(label)
tick(7.5); snapshot(label); tick(8.1); snapshot(label)
C.show_without_plate="1"; projectedX=.5; behind=false
zAPI=function(command)
  if command=="projectNameplate" or command=="projectUnit" then return projectedX,.6,behind and -1 or 10,0,0,2 end
end
fire("CHAT_MSG_SAY","Own parity","Me"); tick(8.2)
local projected
for _,child in ipairs(UIParent.children) do if child.chatProjectionAnchor then projected=child end end
snapshot(projected.chatLabel)
projectedX=.6; tick(8.3); snapshot(projected.chatLabel)
behind=true; tick(8.4); snapshot(projected.chatLabel)
behind=false; tick(8.5); snapshot(projected.chatLabel)
''')
    return [tuple(row[i] for i in range(1, len(row) + 1)) for row in lua.globals().snapshots.values()]


steady = measure_static_chat(source)
forced = measure_static_chat(source, True)
assert steady == {"writes": 0, "metrics": 0, "projections": 0}, steady
assert forced == {"writes": 0, "metrics": 0, "projections": 25}, forced
assert len(chat_visual_trace(source)) == 13

lua = runtime(source)
lua.execute(r'''
local C=zNameplates.config.platechat
fire("CHAT_MSG_GUILD","Hello","Bob"); tick(0)
local label=plate.chatLabel
-- Camera/owner scale continues on every visual frame, even inside the .03s tick.
resetCalls(); plate:SetScale(.53217); visual(label)
assert(math.abs(label:GetEffectiveScale()-.53217)<.000001)
assert(calls.SetScale==2 and not calls.SetFont and not calls.SetPoint)
-- Changing placement/offsets repairs only the relationship/position, not text.
resetCalls(); C.x="17"; tick(.04)
assert(label.point[4]==17 and calls.SetPoint==1 and not calls.ClearAllPoints)
assert(not calls.SetText and not calls.SetFont and not next(metrics))
resetCalls(); C.position="LEFT"; tick(.08)
assert(label.point[1]=="RIGHT" and label.text.align=="RIGHT")
assert(calls.SetPoint==1 and calls.ClearAllPoints==1 and not calls.SetText)
-- External anchor/font/colour resets must not be concealed by cached config.
label:ClearAllPoints(); resetCalls(); tick(.12)
assert(label.point and calls.SetPoint==1 and not calls.SetFont)
label.text:SetFont("reset.ttf",8,""); resetCalls(); tick(.16)
assert(label.text.font[1]=="unit.ttf" and calls.SetFont==1 and next(metrics))
label.text:SetTextColor(0,0,0,0); tick(.20)
assert(label.text.color[1]==.25 and label.text.color[4]==1)
C.fontsize="18"; C.fontstyle="THICKOUTLINE"; C.width="90"; tick(.24)
assert(label.text.font[2]==18 and label.text.font[3]=="THICKOUTLINE" and label.height==26)
zNameplates.font_unit="changed.ttf"; tick(.28)
assert(label.text.font[1]=="changed.ttf")
-- Background changes must not redo text measurements or positioning.
resetCalls(); C.background_color=".2,.3,.4,1"; C.background_opacity=".15"; tick(.32)
assert(calls.SetVertexColor==9 and not calls.SetPoint and not next(metrics))
assert(label.background[1].color[1]==.2 and label.background[1].color[4]==.15)
ChatTypeInfo.GUILD.r=.8; resetCalls(); tick(.36)
assert(calls.SetTextColor==1 and not next(metrics) and label.text.color[1]==.8)
-- The text anchor can be replaced/reparented by the name-only/font surfaces.
local previousName=plate.name; plate.name=plate:CreateFontString()
resetCalls(); tick(.40)
assert(label.point[2]==plate.name and calls.ClearAllPoints==1)
-- Follow a new native owner; the old parent's later Hide cannot hide this label.
local previousParent=plate.parent
local newParent=CreateFrame("Frame"); plate:SetParent(newParent)
plate.parent=newParent; newParent.nameplate=plate
zNameplates.nameplates.visiblePlates[base]=nil
zNameplates.nameplates.visiblePlates[newParent]=newParent
tick(.44); previousParent:Hide(); assert(label:IsShown())
newParent:Hide(); assert(not label:IsShown())
newParent:Show(); tick(.48); assert(label:IsShown())
-- Independent label parent/alpha is restored, never inherited from the plate.
label:SetParent(plate); tick(.52); assert(label:GetParent()==UIParent)
label:SetAlpha(.1); tick(.56); assert(label:GetAlpha()==1)
newParent:SetAlpha(.2); plate:SetAlpha(0); visual(label)
assert(label:GetEffectiveAlpha()==1)
-- Sender reuse and a newly received identical string still restart lifetime.
fire("CHAT_MSG_SAY","New message","Bob","0x02"); tick(.60)
assert(label.text.value=="New message" and label.text.color[1]==1)
units.enemy.guid="0x03"; tick(.64); assert(not label:IsShown())
fire("CHAT_MSG_SAY","Recycled","Bob","0x03"); tick(.68)
assert(label:IsShown() and label.text.value=="Recycled")
-- Both content and requested settings can change while hidden/disabled.
C.enabled="0"; zNameplates.RefreshPlateChat(); assert(not label:IsShown())
C.fontsize="14"; C.enabled="1"; zNameplates.RefreshPlateChat()
fire("CHAT_MSG_SAY","Back","Bob","0x03"); tick(.72)
assert(label:IsShown() and label.text.font[2]==14)
C.duration="2"; C.fade="1"; tick(2.12)
assert(math.abs(label:GetAlpha()-.56)<.000001)
tick(2.72); assert(not label:IsShown())
''')

lua = runtime(source)
lua.execute(r'''
local C=zNameplates.config.platechat
C.show_without_plate="1"; x=.5; y=.6; behind=false; projections=0
zAPI=function(command)
  if command=="projectNameplate" or command=="projectUnit" then
    projections=projections+1; return x,y,behind and -1 or 10,0,0,2
  end
end
fire("CHAT_MSG_SAY","Camera test","Me"); tick(0)
local anchor
for _,child in ipairs(UIParent.children) do if child.chatProjectionAnchor then anchor=child end end
local label=anchor.chatLabel
resetCalls(); projections=0
for i=1,25 do x=.5+i*.001; y=.6+i*.001; tick(i*.04) end
assert(projections==25 and calls.SetPoint==25 and not calls.ClearAllPoints)
assert(not calls.SetText and not calls.SetFont and not calls.SetScale and not next(metrics))
assert(anchor.point[4]==x*1000 and anchor.point[5]==y*800)
behind=true; tick(1.04); assert(not anchor:IsShown() and not label:IsShown())
behind=false; tick(1.08); assert(anchor:IsShown() and label:IsShown())
-- Reuse the same pooled anchor for a different sender after a world reset.
fire("PLAYER_ENTERING_WORLD"); units.target=units.enemy
zNameplates.nameplates.visiblePlates={}
fire("CHAT_MSG_SAY","Other speaker","Bob","0x02"); tick(1.12)
assert(anchor.name.value=="Bob" and label.text.value=="Other speaker")
local N=zNameplates.config.nameplates
N.name.fontsize="17"; zNameplates.font_unit="next.ttf"; tick(1.16)
assert(anchor.name.font[1]=="next.ttf" and anchor.name.font[2]==17)
-- Native alpha quantization must not turn an unchanged request into writes.
local methods=getmetatable(UIParent).__index
local previous=methods.SetAlpha
methods.SetAlpha=function(self,v) return previous(self,math.floor(v*255+.5)/255) end
C.opacity=".73"; tick(1.20); resetCalls(); tick(1.24)
assert(not calls.SetAlpha and label:GetAlpha()~=tonumber(C.opacity))
''')
print(f"Chat cache: 25 steady updates {steady}; forced projection {forced}; motion/reuse/config/visibility checks passed.")
