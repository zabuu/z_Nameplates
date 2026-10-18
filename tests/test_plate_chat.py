"""Lua 5.1 smoke tests for plate-chat matching, expiry, colours, and CVars."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for filename in ("core.lua", "options.lua", "layers.lua", "clusters.lua", "nameplates.lua", "dummy.lua", "chat.lua"):
    lua.compile((root / filename).read_text(encoding="utf-8-sig"), name=filename)

lua.execute(r'''
table.wipe = function(t) for k in pairs(t) do t[k] = nil end end
clock = 0
GetTime = function() return clock end
cvars = { chatBubbles="1", chatBubblesParty="1" }
GetCVar = function(k) return cvars[k] end
SetCVar = function(k,v) cvars[k] = v end
units = { player={name="Me", guid="0x01"}, enemy={name="Bob", guid="0x02"} }
UnitExists = function(u) return units[u] ~= nil end
UnitName = function(u) return units[u] and units[u].name end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitIsPlayer = function(u) return units[u] ~= nil end
ChatTypeInfo = { SAY={r=1,g=1,b=1}, GUILD={r=.25,g=1,b=.25} }
local methods = {}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:Show() self.shown=true end
function methods:Hide()
  local shown=self.shown
  self.shown=false
  if shown and self.scripts.OnHide then
    local previous=this; this=self; self.scripts.OnHide(); this=previous
  end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetFrameStrata(v) self.strata=v end
function methods:GetFrameStrata() return self.strata or "BACKGROUND" end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetFrameLevel() return self.level or 4 end
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha or 1 end
function methods:GetEffectiveAlpha() return self:GetAlpha() * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
function methods:SetScale(v) self.scale=v end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:GetWidth() return self.width or 1000 end
function methods:GetHeight() return self.height or 800 end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetFont(...) self.font={...} end
function methods:SetText(v) self.value=v end
function methods:SetTextColor(...) self.color={...} end
function methods:GetStringHeight() return 14 end
function methods:GetStringWidth() return #(self.value or "") * 6 end
function methods:SetTexture(v) self.texture=v end
function methods:SetVertexColor(...) self.color={...} end
function methods:EnableMouse(v) self.mouse=v end
function methods:SetJustifyH(v) self.align=v end
function methods:SetJustifyV(v) end
function methods:SetNonSpaceWrap(v) end
function CreateFrame(kind,name,parent)
  local f=setmetatable({scripts={},events={},shown=true,parent=parent,children={}}, {__index=methods})
  if parent then table.insert(parent.children,f) end
  if name then _G[name]=f end
  return f
end
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
UIParent=CreateFrame("Frame")
zNameplates = {font_unit="unit.ttf",font_default="default.ttf",nameplates={visiblePlates={}},
  config={nameplates={use_unitfonts="1"},platechat={enabled="0",position="RIGHT",x="6",y="0",
    duration="8",fade="1",scale="1",fontsize="12",width="220",opacity="1",fontstyle="OUTLINE",
    say="1",guild="1",whisper="1"}}}
zNameplates.GetStringColor=function(value)
  local r,g,b,a=string.match(value,"([^,]+),([^,]+),([^,]+),([^,]+)")
  return tonumber(r),tonumber(g),tonumber(b),tonumber(a)
end
base=CreateFrame("Frame")
previousHideCalls=0
base:SetScript("OnHide",function() previousHideCalls=previousHideCalls+1 end)
plate=CreateFrame("Frame",nil,base)
plate.unit="enemy"
plate.name=plate:CreateFontString()
base.nameplate=plate
zNameplates.nameplates.visiblePlates[base]=base
function fire(e,text,speaker,guid)
  event,arg1,arg2,arg12=e,text,speaker,guid
  this=zNameplatesChatWatcher
  this.scripts.OnEvent()
end
function tick(t)
  clock=t
  this=zNameplatesChatWatcher
  this.scripts.OnUpdate()
end
function visual(label)
  local previous=this; this=label; label.scripts.OnUpdate(); this=previous
end
''')
lua.execute((root / "chat.lua").read_text(encoding="utf-8-sig"))
lua.execute(r'''
zNameplates.config.platechat.enabled="1"
zNameplates.RefreshPlateChat()
assert(cvars.chatBubbles=="0" and cvars.chatBubblesParty=="0")
fire("CHAT_MSG_GUILD","Hello","Bob")
tick(0)
label=plate.chatLabel
assert(label and label.shown and label.text.value=="Hello")
assert(not label.pointer and #label.background==9)
assert(label.background[1].color[4]==.35)
assert(label.width==42 and label.height==22)
assert(label.text.color[1]==.25 and label.text.color[2]==1)
assert(label:GetFrameLevel()>plate:GetFrameLevel() and label:GetFrameStrata()==plate:GetFrameStrata())
assert(label.point[1]=="LEFT" and label.point[3]=="RIGHT" and not label.mouse)
-- Chat alpha is independent of both the overlay and its native parent.
assert(label.parent==UIParent)
base:SetAlpha(.2); plate:SetAlpha(0)
visual(label)
assert(label.shown and label:GetEffectiveAlpha()==1)
base:SetScale(.9); UIParent:SetScale(.8); plate:SetScale(.6)
zNameplates.config.platechat.scale="1.25"
zNameplates.config.platechat.opacity=".8"
tick(.1)
assert(math.abs(label:GetEffectiveScale()-plate:GetEffectiveScale()*1.25)<.000001)
assert(label:GetEffectiveAlpha()==.8)
-- Copy floating-point depth scale even between throttled message updates.
plate:SetScale(.53217)
visual(label)
assert(math.abs(label:GetEffectiveScale()-plate:GetEffectiveScale()*1.25)<.000001)
assert(label:GetEffectiveAlpha()==.8)
-- Detached bubbles still hide immediately with their native/overlay owner.
base:Hide()
assert(not label.shown and previousHideCalls==1)
base:Show(); tick(.2)
assert(label.shown)
plate:Hide()
assert(not label.shown)
plate:Show(); tick(.3)
plate.worldPlacementHidden=true; visual(label)
assert(not label.shown)
tick(.4)
assert(not label.shown)
plate.worldPlacementHidden=nil; tick(.5)
assert(label.shown)
plate.clusterHidden=true; visual(label)
assert(not label.shown)
plate.clusterHidden=nil; tick(.6)
assert(label.shown)
plate.cachedGuid="0x03"; visual(label)
assert(not label.shown)
plate.cachedGuid=nil; tick(.7)
assert(label.shown)
base:SetAlpha(1); plate:SetAlpha(1)
base:SetScale(1); plate:SetScale(1); UIParent:SetScale(1)
zNameplates.config.platechat.scale="1"
zNameplates.config.platechat.opacity="1"
tick(7.5)
assert(label.alpha==.5)
-- A recycled plate with the same name but a different GUID must not inherit it.
units.enemy.guid="0x03"
tick(7.6)
assert(not label.shown)
units.enemy.guid="0x02"
tick(8.1)
assert(not label.shown)
-- Ambiguous NPC names are not assigned to an arbitrary plate.
other=CreateFrame("Frame")
other.nameplate=CreateFrame("Frame",nil,other)
other.nameplate.name=other.nameplate:CreateFontString()
other.nameplate.unit="other"
units.other={name="Bob",guid="0x04"}
zNameplates.nameplates.visiblePlates[other]=other
fire("CHAT_MSG_SAY","Ambiguous","Bob")
tick(8.2)
assert(not label.shown)
zNameplates.nameplates.visiblePlates[other]=nil
tick(8.3)
assert(label.shown)
cvars.chatBubbles="1"
tick(9)
assert(cvars.chatBubbles=="0")
zNameplates.config.platechat.enabled="0"
zNameplates.RefreshPlateChat()
assert(cvars.chatBubbles=="1" and cvars.chatBubblesParty=="1" and not label.shown)

-- Own chat without a self nameplate is opt-in and follows native projection.
zNameplates.config.nameplates.name={fontsize="10",fontsize_friendly="10"}
zNameplates.config.platechat.enabled="1"
zNameplates.config.platechat.show_without_plate="0"
zNameplates.RefreshPlateChat()
behindCamera=false
zAPI=function(command,unit,offset)
  if command=="projectUnit" then return .5,.6,behindCamera and -1 or 20,0,0,2 end
  if command=="unitPosition" then return 0,0,0 end
end
fire("CHAT_MSG_SAY","My own chat","Me")
local rootChildrenBefore=#UIParent.children
tick(9.1)
assert(#UIParent.children==rootChildrenBefore)
zNameplates.config.platechat.show_without_plate="1"
tick(9.2)
for _,child in ipairs(UIParent.children) do
  if child.chatProjectionAnchor then projected=child; break end
end
assert(projected and projected.shown and not projected.name.shown)
projectedLabel=projected.chatLabel
assert(projectedLabel.shown and projectedLabel.text.value=="My own chat")
assert(projectedLabel.point[1]=="BOTTOM" and projectedLabel.point[3]=="TOP")
assert(projectedLabel.point[4]==0 and projectedLabel.point[5]==10)
assert(projectedLabel.text.align=="CENTER")
assert(projected.point[4]==500 and projected.point[5]==480)
-- Native projection is refreshed; off-camera speakers are hidden.
behindCamera=true
tick(9.3)
assert(not projected.shown and not projectedLabel.shown)
behindCamera=false
tick(9.4)
assert(projected.shown and projectedLabel.shown and #UIParent.children==rootChildrenBefore+2)
-- Hidden-player speech retains distance scale, but never distance alpha.
local N=zNameplates.config.nameplates
N.distance_scale="1"; N.distance_alpha="1"
N.distance_min_scale="50"; N.distance_min_alpha="20"; N.nameplate_range="41"
local positionReads=0
zAPI=function(command,unit,offset)
  if command=="projectUnit" then return .5,.6,40,41,0,2 end
  if command=="unitPosition" then
    positionReads=positionReads+1
    return unit=="player" and 0 or 41,0,0
  end
end
-- Own speech is at zero distance; a hidden nearby player's speech is distant.
units.target=units.enemy
zNameplates.nameplates.visiblePlates[base]=nil
fire("CHAT_MSG_SAY","Distant player","Bob")
tick(9.44)
local distant
for _,child in ipairs(UIParent.children) do
  if child.chatOwner and child.shown and child.text.value=="Distant player" then distant=child end
end
assert(distant and distant:GetEffectiveAlpha()==1)
assert(math.abs(distant:GetEffectiveScale()-.5)<.000001)
N.distance_scale="0"; positionReads=0
tick(9.48)
assert(distant:GetEffectiveScale()==1 and distant:GetEffectiveAlpha()==1)
assert(positionReads==0) -- Alpha-only settings need no distance queries for chat.
N.distance_alpha="0"
zNameplates.nameplates.visiblePlates[base]=base
zNameplates.config.platechat.show_without_plate="0"
tick(9.55)
assert(not projected.shown)
zNameplates.config.platechat.show_without_plate="1"
tick(17.1)
assert(not projected.shown)

-- A hidden group/target player's chat can use its bound GUID, but has only
-- one label while a visible nameplate exists.
units.target=units.enemy
zNameplates.nameplates.visiblePlates[base]=nil
fire("CHAT_MSG_SAY","Hidden player","Bob")
tick(17.2)
assert(projected.shown and projectedLabel.text.value=="Hidden player")
zNameplates.nameplates.visiblePlates[base]=base
tick(17.3)
assert(label.shown and not projected.shown)
-- Rounded background stays padded, borderless, and configurable in all placements.
zNameplates.config.platechat.background_color=".2,.3,.4,1"
zNameplates.config.platechat.background_opacity=".15"
for _,placement in ipairs({{"RIGHT","LEFT","RIGHT"},
    {"LEFT","RIGHT","LEFT"},{"TOP","BOTTOM","TOP"},
    {"BOTTOM","TOP","BOTTOM"}}) do
  zNameplates.config.platechat.position=placement[1]
  tick(clock+.1)
  assert(label.text.value=="Hidden player")
  assert(not label.pointer)
  assert(label.point[1]==placement[2] and label.point[3]==placement[3])
  assert(label.background[1].color[1]==.2 and label.background[1].color[4]==.15)
  assert(label.background[2].point[4]>label.background[5].point[4])
  assert(label.text.point[4]==6 and label.text.point[5]==-4)
end
zNameplates.config.platechat.background_opacity="0"
tick(clock+.1)
assert(label.shown and label.background[1].color[4]==0)
''')
lua.execute(r'''
-- All supported speaker-bearing channels use the same matching/render path.
local C=zNameplates.config.platechat
for _,category in ipairs({"say","yell","party","raid","guild","whisper",
    "emote","npc","channel","battleground","instance"}) do C[category]="1" end
C.show_without_plate="0"
zNameplates.RefreshPlateChat()
for _,entry in ipairs({
  {"CHAT_MSG_SAY","SAY"},{"CHAT_MSG_YELL","YELL"},
  {"CHAT_MSG_PARTY","PARTY"},{"CHAT_MSG_PARTY_LEADER","PARTY_LEADER"},
  {"CHAT_MSG_RAID","RAID"},{"CHAT_MSG_RAID_LEADER","RAID_LEADER"},
  {"CHAT_MSG_RAID_WARNING","RAID_WARNING"},{"CHAT_MSG_GUILD","GUILD"},
  {"CHAT_MSG_OFFICER","OFFICER"},{"CHAT_MSG_WHISPER","WHISPER"},
  {"CHAT_MSG_EMOTE","EMOTE"},{"CHAT_MSG_TEXT_EMOTE","TEXT_EMOTE"},
  {"CHAT_MSG_BATTLEGROUND","BATTLEGROUND"},
  {"CHAT_MSG_BATTLEGROUND_LEADER","BATTLEGROUND_LEADER"},
  {"CHAT_MSG_INSTANCE_CHAT","INSTANCE_CHAT"},
  {"CHAT_MSG_INSTANCE_CHAT_LEADER","INSTANCE_CHAT_LEADER"},
  {"CHAT_MSG_MONSTER_SAY","MONSTER_SAY"},{"CHAT_MSG_MONSTER_YELL","MONSTER_YELL"},
  {"CHAT_MSG_MONSTER_EMOTE","MONSTER_EMOTE"},{"CHAT_MSG_MONSTER_WHISPER","MONSTER_WHISPER"},
  {"CHAT_MSG_MONSTER_PARTY","MONSTER_PARTY"},
  {"CHAT_MSG_RAID_BOSS_EMOTE","RAID_BOSS_EMOTE"},
  {"CHAT_MSG_RAID_BOSS_WHISPER","RAID_BOSS_WHISPER"},
}) do
  assert(zNameplatesChatWatcher.events[entry[1]])
  ChatTypeInfo[entry[2]]={r=.2,g=.4,b=.6}
  arg8=entry[1]=="CHAT_MSG_CHANNEL" and 3 or nil
  fire(entry[1],entry[1],"Bob","0x02")
  tick(clock+.1)
  local current=plate.chatLabel
  assert(current.shown and current.text.value==entry[1],entry[1])
  assert(current.text.color[1]==.2 and current.text.color[3]==.6,entry[1])
end
-- Realm-qualified player names bind to the same nearby GUID.
fire("CHAT_MSG_RAID","Realm-qualified","Bob-OtherRealm","0x02")
tick(clock+.1)
assert(plate.chatLabel.text.value=="Realm-qualified")
-- Outgoing whispers are speech by the player, not by the recipient.
C.show_without_plate="1"
fire("CHAT_MSG_WHISPER_INFORM","Outgoing whisper","Bob","0x02")
tick(clock+.1)
local found=false
for _,p in ipairs(UIParent.children) do
  if p.text and p.shown and p.text.value=="Outgoing whisper" then found=true end
end
assert(found)
-- Numbered/custom channels are deliberately unsupported even with old settings.
C.channel="1"
assert(not zNameplatesChatWatcher.events.CHAT_MSG_CHANNEL)
fire("CHAT_MSG_CHANNEL","Filtered channel","Bob","0x02")
tick(clock+.1)
assert(plate.chatLabel.text.value~="Filtered channel")
-- Actual native frames are suppressed even if a client/skin ignores the CVars.
nativeBubble=CreateFrame("Frame")
nativeBubble:SetAlpha(.8)
C_ChatBubbles={GetAllChatBubbles=function() return {nativeBubble} end}
tick(clock+.1)
assert(nativeBubble.alpha==0)
nativeBubble:SetAlpha(1)
-- Suppression runs even when it is too early to update chat-label content.
tick(clock+.001)
assert(nativeBubble.alpha==0)
C.enabled="0"; zNameplates.RefreshPlateChat()
assert(nativeBubble.alpha==.8)
C.enabled="1"; zNameplates.RefreshPlateChat()
assert(nativeBubble.alpha==0)
-- Forced own speech always uses the real overhead anchor, even with a visible
-- self plate and a general LEFT placement with large custom offsets.
C.position="LEFT"; C.x="-150"; C.y="-40"; C.show_without_plate="1"
local selfBase=CreateFrame("Frame")
selfBase.nameplate=CreateFrame("Frame",nil,selfBase)
selfBase.nameplate.unit="player"; selfBase.nameplate.name=selfBase.nameplate:CreateFontString()
zNameplates.nameplates.visiblePlates[selfBase]=selfBase
local nameAttachmentCalls=0
zAPI=function(command,unit)
 if command=="projectNameplate" and unit=="player" then nameAttachmentCalls=nameAttachmentCalls+1; return .5,.8,10,0,0,2 end
end
fire("CHAT_MSG_SAY","Over my head","Me","0x01"); tick(clock+.1)
local own
for _,child in ipairs(UIParent.children) do if child.text and child.shown and child.text.value=="Over my head" then own=child end end
assert(own and own.point[1]=="BOTTOM" and own.point[3]=="TOP" and own.point[4]==0 and own.point[5]==10)
assert(own.text.align=="CENTER" and nameAttachmentCalls==1 and not selfBase.nameplate.chatLabel)
''')
print("Lua syntax, chat visibility/scale/lifetime, supported channels, and speaker matching passed.")
