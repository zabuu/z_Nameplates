"""Execute the real settings UI: preserved controls, navigation, search, and edits."""
from pathlib import Path
import re
import subprocess
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
source = (root / "options.lua").read_text(encoding="utf-8-sig")
baseline = subprocess.check_output(["git", "show", "HEAD:options.lua"], cwd=root, text=True)
paths = lambda text: {tuple(re.findall(r'"([^"]+)"', p)) for p in re.findall(r'\{\s*"(?:check|slider|select|input|color)"\s*,[^\n]*?,\s*(\{[^}]+\})', text)}
assert paths(baseline) <= paths(source), "An existing setting path was removed"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
frames={}; widgets={}; callbacks={}; time=0
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function invoke(frame,event,...)
  local old=this; this=frame; arg1=select(1,...)
  if frame.scripts[event] then frame.scripts[event](...) end
  this=old
end
function methods:SetText(v) self.text=tostring(v or ""); invoke(self,"OnTextChanged") end
function methods:GetText() return self.text or "" end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:GetWidth() return self.width or 1000 end
function methods:GetHeight() return self.height or 800 end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetAllPoints() end
function methods:SetParent(p) self.owner=p end
function methods:GetParent() return self.owner end
function methods:SetMinMaxValues(a,b) self.minimum=a; self.maximum=b end
function methods:GetMinMaxValues() return self.minimum,self.maximum end
function methods:SetValue(v) self.value=v; invoke(self,"OnValueChanged",v) end
function methods:GetValue() return self.value end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetVerticalScroll(v) self.scroll=v end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetScrollChild(v) self.scrollChild=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetScale(v) self.scale=v end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:Show() local old=self.shown; self.shown=true; if not old then invoke(self,"OnShow") end end
function methods:Hide() local old=self.shown; self.shown=false; if old then invoke(self,"OnHide") end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.owner or self.owner:IsVisible()) end
function methods:GetFrameLevel() return 4 end
function methods:GetFrameStrata() return self.strata or "DIALOG" end
function methods:SetFrameStrata(v) self.strata=v end
function methods:SetBackdropColor(r,g,b,a) self.backdropColor={r,g,b,a} end
function methods:ClearFocus() invoke(self,"OnEditFocusLost") end
function methods:SetFont(f,s,o) self.font=f; self.fontSize=s end
function methods:GetFontString() if not self.caption then self.caption=CreateFrame("FontString",nil,self) end; return self.caption end
function methods:GetHighlightTexture() return nil end
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
setmetatable(methods,{__index=function(t,k)
  if not string.find(k,"^[A-Z]") then return nil end
  if string.find(k,"^Get") then return function() return nil end end
  return function() end
end})
function CreateFrame(kind,name,parent,template)
  local f=setmetatable({kind=kind,name=name,owner=parent,template=template,shown=true,enabled=true,points={},scripts={}},{__index=methods})
  frames[#frames+1]=f
  if name then _G[name]=f end
  return f
end
UIParent=CreateFrame("Frame"); UIParent.width=1000; UIParent.height=800
GameTooltip=CreateFrame("Frame"); GameFontHighlightSmall={}; GameFontDisableSmall={}
SlashCmdList={}; StaticPopupDialogs={}; StaticPopup_Show=function(id) popup=id end
GetTime=function() return time end
getglobal=function(name) return _G[name] end
ReloadUI=function() end
zNameplates={font_unit="unit.ttf",font_default="default.ttf",config=nil,
  GetStringColor=function(v) local r,g,b,a=string.match(v,"([^,]+),([^,]+),([^,]+),([^,]+)"); return tonumber(r),tonumber(g),tonumber(b),tonumber(a) end}
Z=zNameplates
''')
lua.execute(source)
core = (root / "core.lua").read_text(encoding="utf-8-sig")
defaults = core[core.index("local defaults = {"):core.index("local function CopyTable(")]
lua.execute('local PATH="Interface\\\\AddOns\\\\z_Nameplates"; local Z=zNameplates\n' + defaults + '\nZ.config=defaults')
lua.execute('''
Z.Refresh=function() Z.options:Refresh() end
Z.GetDefaultSetting=function(path) local v=Z.defaults; for _,k in ipairs(path) do v=v[k] end; return v end
Z.options:Show(); Z.options:Refresh()
assert(#Z.settingsPages==13)
local function findButton(text)
  for _,f in ipairs(frames) do if f.kind=="Button" and f:GetText()==text then return f end end
  error("Missing button "..text)
end
for _,page in ipairs(Z.settingsPages) do
  invoke(findButton(page.name),"OnClick")
  for _,item in ipairs(page.items) do
    if item[3] then
      local value=Z.config
      for _,key in ipairs(item[3]) do value=value[key] end
      assert(value~=nil,"Missing default "..table.concat(item[3],"/"))
    end
  end
end
-- Repeat navigation after multiple refreshes; category buttons never lock.
invoke(findButton("Chat"),"OnClick"); invoke(findButton("Health"),"OnClick")
local searchBox
for _,f in ipairs(frames) do
  if f.kind=="EditBox" and f.width==225 then searchBox=f end
end
searchBox:SetText("raid")
local matching=0
for _,f in ipairs(frames) do if f.kind=="Frame" and f.width==620 and f.shown and (f.height==32 or f.height==38) then matching=matching+1 end end
assert(matching>0)
searchBox:SetText("no such setting 54321")
for _,f in ipairs(frames) do if f.kind=="Frame" and f.width==620 and (f.height==32 or f.height==38) then assert(not f.shown) end end
searchBox:SetText("")
-- Friendly texture labels, never full asset paths.
assert(findButton("Smooth"))
-- Slider number entry clamps, updates the real setting and can be undone.
invoke(findButton("Distance"),"OnClick")
local exact
for _,f in ipairs(frames) do if f.kind=="EditBox" and f.width==70 and f:GetText()=="41" then exact=f end end
assert(exact)
exact:SetText("999"); invoke(exact,"OnEnterPressed")
assert(Z.config.nameplates.nameplate_range=="80")
invoke(findButton("Undo last"),"OnClick")
assert(Z.config.nameplates.nameplate_range=="41")
-- Disabled dependent sliders remain present but not interactable.
Z.config.platechat.enabled="0"; Z.options:Refresh()
local dimmed=0
for _,f in ipairs(frames) do if f.kind=="Frame" and f.width==620 and f.alpha==.45 then dimmed=dimmed+1 end end
assert(dimmed>10)
-- Resets request confirmation rather than mutating config immediately.
invoke(findButton("Reset all..."),"OnClick"); assert(popup=="ZNP_RESET_ALL")
invoke(findButton("Reset category..."),"OnClick"); assert(popup=="ZNP_RESET_PAGE")
local names={}
for _,page in ipairs(Z.settingsPages) do
  for _,item in ipairs(page.items) do
    if item[3] then names[table.concat(item[3],"/")]=page.name end
  end
end
assert(names["platechat/width"]=="Chat")
assert(names["nameplates/cluster_enabled"]=="Crowds")
assert(names["nameplates/dummy_preview"]=="Preview")
assert(names["nameplates/enemynamecolor"]=="Text")
-- The opaque settings panel is above the highest nameplate strata (DIALOG).
assert(Z.options:GetFrameStrata()=="FULLSCREEN")
assert(Z.options.backdropColor[4]==1)
assert(Z.options.width==820 and Z.options.height==560)
-- Confirmations and the shared colour picker remain above the settings panel,
-- then restore their original layer when closed.
modal=CreateFrame("Frame")
modal:SetScript("OnHide",function() originalHideCalled=true end)
StaticPopup_Show=function(id) popup=id; modal:Show(); return modal end
invoke(findButton("Reset all..."),"OnClick")
assert(modal:GetFrameStrata()=="FULLSCREEN_DIALOG")
modal:Hide(); assert(modal:GetFrameStrata()=="DIALOG" and originalHideCalled)
invoke(findButton("Reset all..."),"OnClick")
modal:Hide(); assert(modal:GetFrameStrata()=="DIALOG")
ColorPickerFrame=CreateFrame("Frame")
invoke(findButton("   Edit colour"),"OnClick")
assert(ColorPickerFrame:GetFrameStrata()=="FULLSCREEN_DIALOG")
ColorPickerFrame:Hide(); assert(ColorPickerFrame:GetFrameStrata()=="DIALOG")
''')
print(f"Settings UI executed successfully; all {len(paths(baseline))} original setting paths preserved.")
