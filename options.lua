-- One self-contained settings window for the standalone nameplate module.

local Z = zNameplates
local PATH = "Interface\\AddOns\\z_Nameplates"

local alignments = {
  { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" },
}
local positions = {
  { "Top left", "TOPLEFT" }, { "Top", "TOP" }, { "Top right", "TOPRIGHT" },
  { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" },
  { "Bottom left", "BOTTOMLEFT" }, { "Bottom", "BOTTOM" }, { "Bottom right", "BOTTOMRIGHT" },
}
local fontStyles = {
  { "None", "" }, { "Outline", "OUTLINE" },
  { "Thick outline", "THICKOUTLINE" }, { "Monochrome", "MONOCHROME" },
}
local healthFormats = {
  { "Current / maximum", "curmaxs" }, { "Current - maximum", "curmax" },
  { "Current / maximum | percent", "curmaxpercs" }, { "Current - maximum | percent", "curmaxperc" },
  { "Current | percent", "curperc" }, { "Current", "cur" },
  { "Deficit", "deficit" }, { "Percent", "percent" },
}
local filters = {
  { "No filter", "none" }, { "Blacklist", "blacklist" }, { "Whitelist", "whitelist" },
}
local textures = {
  { "Smooth", PATH .. "\\Assets\\img\\bar.tga" },
  { "Gradient", PATH .. "\\Assets\\img\\bar_gradient.tga" },
  { "Striped", PATH .. "\\Assets\\img\\bar_striped.tga" },
  { "ElvUI", PATH .. "\\Assets\\img\\bar_elvui.tga" },
  { "TukUI", PATH .. "\\Assets\\img\\bar_tukui.tga" },
}
local fonts = {
  { "Myriad Pro", PATH .. "\\Assets\\fonts\\Myriad-Pro.ttf" },
  { "Big Noodle", PATH .. "\\Assets\\fonts\\BigNoodleTitling.ttf" },
  { "Expressway", PATH .. "\\Assets\\fonts\\Expressway.ttf" },
  { "PT Sans Narrow", PATH .. "\\Assets\\fonts\\PT-Sans-Narrow-Regular.ttf" },
  { "PT Sans Narrow Bold", PATH .. "\\Assets\\fonts\\PT-Sans-Narrow-Bold.ttf" },
  { "Roboto Mono", PATH .. "\\Assets\\fonts\\RobotoMono.ttf" },
  { "Continuum", PATH .. "\\Assets\\fonts\\Continuum.ttf" },
  { "Homespun", PATH .. "\\Assets\\fonts\\Homespun.ttf" },
  { "Hooge", PATH .. "\\Assets\\fonts\\Hooge.ttf" },
  { "Die Die Die", PATH .. "\\Assets\\fonts\\DieDieDie.ttf" },
}

local pages = {
  {
    name = "General",
    items = {
      { "check", "Show hostile nameplates", {"nameplates","showhostile"} },
      { "check", "Show friendly nameplates", {"nameplates","showfriendly"} },
      { "check", "Hide Blizzard XP floating text", {"nameplates","hide_blizzard_xp"} },
      { "check", "Disable hostile plates in friendly zones", {"nameplates","disable_hostile_in_friendly"} },
      { "check", "Disable friendly plates in friendly zones", {"nameplates","disable_friendly_in_friendly"} },
      { "input", "Vertical offset", {"nameplates","vertical_offset"} },
      { "input", "Inactive alpha (0-1)", {"nameplates","notargalpha"} },
      { "check", "Glow around target", {"nameplates","targetglow"} },
      { "color", "Target glow color", {"nameplates","glowcolor"} },
      { "check", "Red names while in combat", {"nameplates","namefightcolor"} },
      { "check", "Zoom target nameplate", {"nameplates","targetzoom"} },
      { "input", "Target zoom factor", {"nameplates","targetzoomval"} },
      { "input", "Nameplate width", {"nameplates","width"} },
      { "check", "Enemy player class colors", {"nameplates","enemyclassc"} },
      { "check", "Friendly player class colors", {"nameplates","friendclassc"} },
      { "check", "Class-color friendly names", {"nameplates","friendclassnamec"} },
      { "check", "Show combo points", {"nameplates","cpdisplay"} },
      { "check", "Click-through nameplates", {"nameplates","clickthrough"} },
      { "check", "Allow enemy nameplate overlap", {"nameplates","overlap_enemy"} },
      { "check", "Allow friendly nameplate overlap", {"nameplates","overlap_friendly"} },
      { "check", "Overlap all plates in friendly areas", {"nameplates","overlap_friendly_area"} },
      { "check", "Never overlap plates in combat with me", {"nameplates","overlap_combat"} },
      { "check", "Replace totems with icons", {"nameplates","totemicons"} },
      { "check", "Show guild/sub-name", {"nameplates","showguildname"} },
    },
  },
  {
    name = "Health",
    items = {
      { "input", "Healthbar vertical offset", {"nameplates","health","offset"} },
      { "input", "Healthbar height", {"nameplates","heighthealth"} },
      { "select", "Healthbar texture", {"nameplates","healthtexture"}, textures },
      { "check", "Show health text", {"nameplates","showhp"} },
      { "select", "Health text alignment", {"nameplates","hptextpos"}, alignments },
      { "select", "Name text alignment", {"nameplates","nametextpos"}, alignments },
      { "select", "Health text format", {"nameplates","hptextformat"}, healthFormats },
      { "color", "Enemy name color", {"nameplates","enemynamecolor"} },
      { "color", "Friendly name color", {"nameplates","friendlynamecolor"} },
      { "color", "Critter name color", {"nameplates","critternamecolor"} },
      { "check", "Vertical healthbar", {"nameplates","verticalhealth"} },
      { "check", "Hide bar: enemy NPCs", {"nameplates","enemynpc"} },
      { "check", "Hide bar: enemy players", {"nameplates","enemyplayer"} },
      { "check", "Hide bar: neutral NPCs", {"nameplates","neutralnpc"} },
      { "check", "Hide bar: friendly NPCs", {"nameplates","friendlynpc"} },
      { "check", "Hide bar: friendly players", {"nameplates","friendlyplayer"} },
      { "check", "Hide bar: critters", {"nameplates","critters"} },
      { "check", "Hide bar: totems", {"nameplates","totems"} },
      { "check", "Always show if health is missing", {"nameplates","fullhealth"} },
      { "check", "Always show target healthbar", {"nameplates","target"} },
      { "check", "Friendly-player blue outline", {"nameplates","outfriendly"} },
      { "check", "Friendly-NPC green outline", {"nameplates","outfriendlynpc"} },
      { "check", "Neutral yellow outline", {"nameplates","outneutral"} },
      { "check", "Enemy red outline", {"nameplates","outenemy"} },
      { "check", "Highlight target border", {"nameplates","targethighlight"} },
      { "color", "Target border color", {"nameplates","highlightcolor"} },
    },
  },
  {
    name = "Cast & Auras",
    items = {
      { "check", "Enable castbars", {"nameplates","showcastbar"} },
      { "check", "Only show target castbar", {"nameplates","targetcastbar"} },
      { "check", "Show spell name", {"nameplates","spellname"} },
      { "input", "Castbar height", {"nameplates","heightcast"} },
      { "select", "Castbar texture", {"appearance","castbar","texture"}, textures },
      { "color", "Cast color", {"appearance","castbar","castbarcolor"} },
      { "color", "Channel color", {"appearance","castbar","channelcolor"} },
      { "input", "Castbar decimal places", {"unitframes","castbardecimals"} },
      { "check", "Enable debuffs", {"nameplates","showdebuffs"} },
      { "check", "Show debuffs on hostile units", {"nameplates","showdebuffs_hostile"} },
      { "check", "Show debuffs on friendly units", {"nameplates","showdebuffs_friendly"} },
      { "check", "Only show your debuffs", {"nameplates","owndebuffs"} },
      { "select", "Debuff position", {"nameplates","debuffs","position"}, {{"Above","TOP"},{"Below","BOTTOM"}} },
      { "input", "Debuff icon offset", {"nameplates","debuffoffset"} },
      { "input", "Debuff icon size", {"nameplates","debuffsize"} },
      { "check", "Show debuff stacks", {"nameplates","debuffs","showstacks"} },
      { "check", "Enable debuff timers", {"nameplates","debufftimers"} },
      { "check", "Show timer text", {"nameplates","debufftext"} },
      { "check", "Show timer animation", {"nameplates","debuffanim"} },
      { "select", "Debuff filter mode", {"nameplates","debuffs","filter"}, filters },
      { "input", "Blacklist (spell names, separated by #)", {"nameplates","debuffs","blacklist"}, 185 },
      { "input", "Whitelist (spell names, separated by #)", {"nameplates","debuffs","whitelist"}, 185 },
      { "input", "Cooldown text size", {"appearance","cd","font_size"} },
      { "check", "Dynamic cooldown text size", {"appearance","cd","dynamicsize"} },
    },
  },
  {
    name = "Appearance",
    items = {
      { "check", "Use separate unit font", {"nameplates","use_unitfonts"} },
      { "select", "Default font", {"global","font_default"}, fonts },
      { "input", "Default font size", {"global","font_size"} },
      { "select", "Unit font", {"global","font_unit"}, fonts },
      { "input", "Unit font size", {"global","font_unit_size"} },
      { "select", "Font style", {"nameplates","name","fontstyle"}, fontStyles },
      { "select", "Cooldown font", {"appearance","cd","font"}, fonts },
      { "check", "Abbreviate long names", {"unitframes","abbrevname"} },
      { "select", "Number abbreviation", {"unitframes","abbrevnum"}, {{"Off","0"},{"Precise","1"},{"Compact","2"}} },
      { "check", "Use Blizzard raid icons", {"unitframes","blizzard_raidicons"} },
      { "select", "Raid icon position", {"nameplates","raidiconpos"}, positions },
      { "input", "Raid icon X offset", {"nameplates","raidiconoffx"} },
      { "input", "Raid icon Y offset", {"nameplates","raidiconoffy"} },
      { "input", "Raid icon size", {"nameplates","raidiconsize"} },
      { "check", "Show quest-giver icons", {"nameplates","questicons"} },
      { "input", "Quest icon size", {"nameplates","questiconsize"} },
      { "input", "Quest icon vertical offset", {"nameplates","questiconoffset"} },
      { "color", "Border color", {"appearance","border","color"} },
      { "color", "Border background", {"appearance","border","background"} },
      { "input", "Default border size", {"appearance","border","default"} },
      { "input", "Nameplate border size (-1 = default)", {"appearance","border","nameplates"} },
      { "check", "Pixel-perfect borders", {"appearance","border","pixelperfect"} },
      { "check", "HiDPI border correction", {"appearance","border","hidpi"} },
      { "preview", "Nameplate Text Preview" },
    },
  },
  {
    name = "Threat",
    items = {
      { "check", "Combat state colors on border", {"nameplates","outcombatstate"} },
      { "check", "Combat state colors on healthbar", {"nameplates","barcombatstate"} },
      { "check", "State: unit attacking you", {"nameplates","ccombatthreat"} },
      { "color", "Attacking-you color", {"nameplates","combatthreat"} },
      { "check", "State: unit attacking off-tank", {"nameplates","ccombatofftank"} },
      { "color", "Off-tank color", {"nameplates","combatofftank"} },
      { "check", "State: unit attacking others", {"nameplates","ccombatnothreat"} },
      { "color", "Attacking-others color", {"nameplates","combatnothreat"} },
      { "check", "State: unit attacking nobody", {"nameplates","ccombatstun"} },
      { "color", "No-target/stunned color", {"nameplates","combatstun"} },
      { "check", "State: unit casting", {"nameplates","ccombatcasting"} },
      { "color", "Casting color", {"nameplates","combatcasting"} },
      { "input", "Off-tank names (separated by #)", {"nameplates","combatofftanks"}, 185 },
    },
  },
  {
    name = "Distance",
    items = {
      { "check", "Scale nameplates by exact distance", {"nameplates","distance_scale"} },
      { "slider", "Minimum distant size", {"nameplates","distance_min_scale"}, 20, 100, 1 },
      { "check", "Fade nameplates by exact distance", {"nameplates","distance_alpha"} },
      { "slider", "Minimum distant opacity", {"nameplates","distance_min_alpha"}, 20, 100, 1 },
      { "check", "Fade and desaturate out-of-sight plates", {"nameplates","los_fade"} },
      { "slider", "Out-of-sight desaturation", {"nameplates","los_desaturation"}, 0, 100, 1 },
    },
  },
  {
    name = "Advanced",
    items = {
      { "check", "Right-click mouselook/attack", {"nameplates","rightclick"} },
      { "input", "Right-click threshold", {"nameplates","clickthreshold"} },
      { "input", "Normal update rate (updates/sec)", {"throttle","nameplates"} },
      { "input", "Target update rate", {"throttle","nameplates_target"} },
      { "input", "Castbar update rate", {"throttle","nameplates_castbar"} },
      { "input", "Mass-nameplate update rate", {"throttle","nameplates_mass"} },
    },
  },
}

local function GetValue(path)
  local value = Z.config
  if not value then return "" end
  for i = 1, table.getn(path) do value = value[path[i]] end
  return value
end

local function SetValue(path, value)
  local target = Z.config
  for i = 1, table.getn(path) - 1 do target = target[path[i]] end
  target[path[table.getn(path)]] = tostring(value)
  Z.Refresh()
end

local frame = CreateFrame("Frame", "zNameplatesOptions", UIParent)
frame:SetWidth(820)
frame:SetHeight(590)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
frame:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11} })
frame:SetBackdropColor(0.03, 0.03, 0.03, 0.90)
frame:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -18)
title:SetText("zNameplates")
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
subtitle:SetText("Standalone nameplates and nameplate-only settings")
subtitle:SetTextColor(0.75, 0.75, 0.75, 1)

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetTexture("Interface\\BUTTONS\\WHITE8X8")
divider:SetVertexColor(0.55, 0.55, 0.55, 0.25)
divider:SetPoint("TOP", frame, "TOP", 0, -100)
divider:SetPoint("BOTTOM", frame, "BOTTOM", 0, 70)
divider:SetWidth(1)

local closeX = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeX:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

local tabFrames = {}
local tabButtons = {}
local widgets = {}
local activeTab = 1

local function Label(parent, text, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetWidth(230)
  label:SetJustifyH("LEFT")
  label:SetTextColor(0.95, 0.95, 0.95, 1)
  label:SetText(text)
  return label
end

local function ApplyColor(path, oldValue)
  local r, g, b = ColorPickerFrame:GetColorRGB()
  local a = 1 - (ColorPickerFrame.opacity or 0)
  if oldValue and not r then SetValue(path, oldValue) else SetValue(path, r .. "," .. g .. "," .. b .. "," .. a) end
end

local function CreateWidget(parent, item, index)
  -- Keep pages at two readable columns. Thirteen rows fit comfortably above
  -- the footer and prevent the extra name-color controls from creating a
  -- clipped third column on the Health tab.
  local col = math.floor((index - 1) / 13)
  local row = math.mod(index - 1, 13)
  local x = 22 + col * 390
  local y = -18 - row * 34
  local kind, text, path = item[1], item[2], item[3]
  local widget = { kind=kind, path=path }

  if kind == "check" then
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y + 5)
    check:SetWidth(24); check:SetHeight(24)
    local label = Label(parent, text, x + 27, y)
    label:SetWidth(300)
    check:SetScript("OnClick", function() SetValue(path, this:GetChecked() and "1" or "0") end)
    widget.control = check
  elseif kind == "slider" then
    local label = Label(parent, text, x, y)
    label:SetWidth(220)
    local sliderName = "zNameplatesOptionSlider" .. tostring(table.getn(widgets) + 1)
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 350, y + 2)
    slider:SetWidth(125); slider:SetHeight(16)
    slider:SetMinMaxValues(item[4] or 0, item[5] or 100)
    slider:SetValueStep(item[6] or 1)
    if getglobal then
      local low = getglobal(sliderName .. "Low")
      local high = getglobal(sliderName .. "High")
      local title = getglobal(sliderName .. "Text")
      if low then low:SetText((item[4] or 0) .. "%") end
      if high then high:SetText((item[5] or 100) .. "%") end
      if title then title:SetText("") end
    end
    slider:SetScript("OnValueChanged", function()
      local value = math.floor((tonumber(arg1) or this:GetValue() or 60) + .5)
      label:SetText(text .. ": " .. value .. "%")
      if not this.zNameplatesUpdating then SetValue(path, value) end
    end)
    widget.control = slider
    widget.label = label
    widget.text = text
  elseif kind == "input" then
    Label(parent, text, x, y)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 350, y + 5)
    input:SetWidth(item[4] or 105); input:SetHeight(24)
    input:SetAutoFocus(false)
    input:SetTextColor(1, 1, 1, 1)
    input:SetJustifyH("LEFT")
    local function Commit() SetValue(path, input:GetText()) end
    input:SetScript("OnEditFocusGained", function() this.zNameplatesEditing = true end)
    input:SetScript("OnEnterPressed", function() Commit(); this:ClearFocus() end)
    input:SetScript("OnEscapePressed", function() this:SetText(GetValue(path)); this:ClearFocus() end)
    input:SetScript("OnEditFocusLost", function()
      this.zNameplatesEditing = nil
      Commit()
    end)
    widget.control = input
  elseif kind == "select" then
    Label(parent, text, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 350, y + 3)
    button:SetWidth(150); button:SetHeight(23)
    button:SetScript("OnClick", function()
      local values = item[4]
      local current, found = GetValue(path), 1
      for i = 1, table.getn(values) do if values[i][2] == current then found = i end end
      found = IsShiftKeyDown() and found - 1 or found + 1
      if found < 1 then found = table.getn(values) elseif found > table.getn(values) then found = 1 end
      SetValue(path, values[found][2])
    end)
    widget.values = item[4]
    widget.control = button
  elseif kind == "color" then
    Label(parent, text, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 350, y + 3)
    button:SetWidth(105); button:SetHeight(23)
    button:SetText("Choose")
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("LEFT", button, "LEFT", 7, 0); swatch:SetWidth(13); swatch:SetHeight(13)
    swatch:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    button:SetScript("OnClick", function()
      local oldValue = GetValue(path)
      local r, g, b, a = Z.GetStringColor(oldValue)
      ColorPickerFrame.func = function() ApplyColor(path) end
      ColorPickerFrame.opacityFunc = function() ApplyColor(path) end
      ColorPickerFrame.cancelFunc = function() SetValue(path, oldValue) end
      ColorPickerFrame.hasOpacity = true
      ColorPickerFrame.opacity = 1 - (tonumber(a) or 1)
      ColorPickerFrame:SetColorRGB(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
      ColorPickerFrame:Show()
    end)
    widget.control = button
    widget.swatch = swatch
  elseif kind == "preview" then
    local preview = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    preview:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)
    preview:SetWidth(350); preview:SetHeight(28)
    preview:SetJustifyH("CENTER")
    preview:SetText(text)
    widget.control = preview
  end
  table.insert(widgets, widget)
end

local function ShowTab(index)
  activeTab = index
  for i = 1, table.getn(tabFrames) do
    if i == index then tabFrames[i]:Show(); tabButtons[i]:Disable()
    else tabFrames[i]:Hide(); tabButtons[i]:Enable() end
  end
  frame:Refresh()
end

local tabStep = math.floor((820 - 40) / table.getn(pages))
for pageIndex = 1, table.getn(pages) do
  local tabIndex = pageIndex
  local pageData = pages[pageIndex]
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (pageIndex - 1) * tabStep, -68)
  button:SetWidth(tabStep - 5); button:SetHeight(24); button:SetText(pageData.name)
  button:SetScript("OnClick", function() ShowTab(tabIndex) end)
  tabButtons[pageIndex] = button

  local page = CreateFrame("Frame", nil, frame)
  page:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -103)
  page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 75)
  tabFrames[pageIndex] = page
  for itemIndex = 1, table.getn(pageData.items) do CreateWidget(page, pageData.items[itemIndex], itemIndex) end
end

local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 25, 25)
reset:SetWidth(120); reset:SetHeight(25); reset:SetText("Reset defaults")
reset:SetScript("OnClick", function() Z.Reset() end)

local reload = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reload:SetPoint("LEFT", reset, "RIGHT", 8, 0)
reload:SetWidth(120); reload:SetHeight(25); reload:SetText("Reload UI")
reload:SetScript("OnClick", ReloadUI)

local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 25)
close:SetWidth(120); close:SetHeight(25); close:SetText("Close")
close:SetScript("OnClick", function() frame:Hide() end)

function frame:Refresh()
  if not Z.config then return end
  for i = 1, table.getn(widgets) do
    local widget = widgets[i]
    if widget.path then
      local value = GetValue(widget.path)
      if widget.kind == "check" then widget.control:SetChecked(value == "1")
      elseif widget.kind == "slider" then
        local amount = tonumber(value) or 60
        widget.control.zNameplatesUpdating = true
        widget.control:SetValue(amount)
        widget.control.zNameplatesUpdating = nil
        widget.label:SetText(widget.text .. ": " .. math.floor(amount + .5) .. "%")
      elseif widget.kind == "input" and not widget.control.zNameplatesEditing then widget.control:SetText(value or "")
      elseif widget.kind == "select" then
        local label = tostring(value or "")
        for j = 1, table.getn(widget.values) do if widget.values[j][2] == value then label = widget.values[j][1] end end
        widget.control:SetText(label)
      elseif widget.kind == "color" then
        local r, g, b = Z.GetStringColor(value)
        widget.swatch:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
      end
    elseif widget.kind == "preview" then
      local useUnit = Z.config.nameplates.use_unitfonts == "1"
      local font = useUnit and Z.font_unit or Z.font_default
      local size = tonumber(useUnit and Z.config.global.font_unit_size or Z.config.global.font_size) or 12
      local style = Z.config.nameplates.name.fontstyle or ""
      widget.control:SetFont(font, math.max(12, size + 3), style)
    end
  end
end

frame:SetScript("OnShow", function() frame:Refresh() end)
ShowTab(activeTab)
Z.options = frame

SLASH_ZNAMEPLATES1 = "/znp"
SLASH_ZNAMEPLATES2 = "/znameplates"
SlashCmdList["ZNAMEPLATES"] = function(message)
  local command = string.lower(message or "")
  command = string.gsub(command, "^%s+", "")
  command = string.gsub(command, "%s+$", "")
  if command == "list" then
    if Z.ToggleCombatList then Z.ToggleCombatList() end
  elseif frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

-- Keep the combat-list implementation inside an existing addon file. The
-- OctoWoW client can reject Lua filenames created after the game started,
-- even when /reload successfully picks up edits to files it already knows.
do
  local listRows = {}
  local listEntries = {}
  local listEntryCount = 0
  local LIST_HEADER_HEIGHT = 18
  local LIST_PADDING = 4

  local list = CreateFrame("Frame", "zNameplatesCombatList", UIParent)
  list:SetFrameStrata("MEDIUM")
  list:SetWidth(160)
  list:SetHeight(LIST_HEADER_HEIGHT + 18)
  list:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -32, -180)
  list:SetMovable(true)
  list:EnableMouse(true)
  if list.SetClampedToScreen then list:SetClampedToScreen(true) end
  list:Hide()

  local listHeader = CreateFrame("Button", nil, list)
  listHeader:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1)
  listHeader:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, -1)
  listHeader:SetHeight(LIST_HEADER_HEIGHT - 1)
  listHeader:RegisterForDrag("LeftButton")
  listHeader:SetScript("OnDragStart", function() list:StartMoving() end)

  local listCount = listHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listCount:SetPoint("LEFT", listHeader, "LEFT", 4, 0)
  listCount:SetTextColor(.75, .75, .75, 1)
  listCount:SetText("(0)")

  local listCollapse = CreateFrame("Button", nil, listHeader)
  listCollapse:SetPoint("RIGHT", listHeader, "RIGHT", -19, 0)
  listCollapse:SetWidth(17)
  listCollapse:SetHeight(16)
  listCollapse.text = listCollapse:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  listCollapse.text:SetAllPoints(listCollapse)
  listCollapse.text:SetText("-")

  local listClose = CreateFrame("Button", nil, listHeader)
  listClose:SetPoint("RIGHT", listHeader, "RIGHT", -2, 0)
  listClose:SetWidth(16)
  listClose:SetHeight(16)
  listClose.text = listClose:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  listClose.text:SetAllPoints(listClose)
  listClose.text:SetText("x")
  listClose.text:SetTextColor(.9, .38, .38, 1)
  listClose:SetScript("OnClick", function() list:Hide() end)

  local listDivider = list:CreateTexture(nil, "ARTWORK")
  listDivider:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  listDivider:SetVertexColor(.45, .45, .45, .45)
  listDivider:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -LIST_HEADER_HEIGHT)
  listDivider:SetPoint("TOPRIGHT", list, "TOPRIGHT", -3, -LIST_HEADER_HEIGHT)
  listDivider:SetHeight(1)

  local listEmpty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  listEmpty:SetPoint("TOP", list, "TOP", 0, -LIST_HEADER_HEIGHT - 5)
  listEmpty:SetText("No nearby nameplates")

  local function ListSettings()
    return Z.config and Z.config.combatlist
  end

  listHeader:SetScript("OnDragStop", function()
    list:StopMovingOrSizing()
    local settings = ListSettings()
    if not settings or not list.GetPoint then return end
    local point, _, relativePoint, x, y = list:GetPoint()
    settings.point = point or "TOPRIGHT"
    settings.relativePoint = relativePoint or settings.point
    settings.x = tostring(x or -32)
    settings.y = tostring(y or -180)
  end)

  local function ListPlateLevel(plate)
    local level = plate.unit and UnitLevel and UnitLevel(plate.unit)
    if level and level > 0 then return level end
    local label = plate.level and plate.level.GetText and plate.level:GetText()
    local _, _, number = string.find(label or "", "(%d+)")
    if number then return tonumber(number) end
    if level == -1 or (label and string.find(label, "?", 1, true)) then return 999 end
    return 0
  end

  local function ListPlateNearby(plate)
    local unit = plate and plate.unit
    return unit and not plate.isCritter and UnitExists(unit)
      and not (UnitCanAssist and UnitCanAssist("player", unit))
      and not (UnitIsDead and UnitIsDead(unit))
  end

  local function ListCompare(left, right)
    if left.tagged ~= right.tagged then return left.tagged < right.tagged end
    if left.level ~= right.level then return left.level > right.level end
    if left.name ~= right.name then return left.name < right.name end
    return left.guid < right.guid
  end

  local function BuildCombatList()
    for index = listEntryCount, 1, -1 do listEntries[index] = nil end
    listEntryCount = 0

    local visible = Z.nameplates and Z.nameplates.visiblePlates
    if not visible then return 0 end
    for base in pairs(visible) do
      local plate = base and base.nameplate
      if plate and plate.unit and (not base.IsVisible or base:IsVisible()) then
        local guid = plate.cachedGuid or plate.unit
        if ListPlateNearby(plate) then
          local name = plate.name and plate.name.GetText and plate.name:GetText()
          name = name or (UnitName and UnitName(plate.unit)) or "Unknown"
          listEntryCount = listEntryCount + 1
          listEntries[listEntryCount] = {
            plate = plate, guid = tostring(guid), name = string.lower(name),
            level = ListPlateLevel(plate),
            tagged = (plate.taggedByPlayer or plate.taggedByOther) and 1 or 0,
          }
        end
      end
    end

    -- Avoid the old client's stale implicit table length on reused arrays.
    -- Insertion sorting this small visible-nameplate list also guarantees that
    -- the comparator never receives a nil entry.
    for i = 2, listEntryCount do
      local entry = listEntries[i]
      local index = i - 1
      while index >= 1 and ListCompare(entry, listEntries[index]) do
        listEntries[index + 1] = listEntries[index]
        index = index - 1
      end
      listEntries[index + 1] = entry
    end
    return listEntryCount
  end

  local function SetListFont(text, source, fallbackSize)
    local font, size, flags
    if source and source.GetFont then font, size, flags = source:GetFont() end
    if not font then
      local useUnit = Z.config.nameplates.use_unitfonts == "1"
      font = useUnit and Z.font_unit or Z.font_default
      size = tonumber(useUnit and Z.config.global.font_unit_size or Z.config.global.font_size)
      flags = Z.config.nameplates.name.fontstyle
    end
    if font and font ~= "" then
      text:SetFont(font, math.max(8, tonumber(size) or fallbackSize or 11), flags or "")
    end
  end

  local function SetListTextColor(destination, source, r, g, b, a)
    if source and source.GetTextColor then
      local sr, sg, sb, sa = source:GetTextColor()
      if sr then r, g, b, a = sr, sg, sb, sa end
    end
    destination:SetTextColor(r or 1, g or 1, b or 1, a or 1)
  end

  local function UpdateListRaidIcon(row, plate)
    local icon = row.raidicon
    local raidIndex
    if GetRaidTargetIndex and plate.unit then
      local ok, value = pcall(GetRaidTargetIndex, plate.unit)
      if ok then raidIndex = tonumber(value) end
    end

    if raidIndex and raidIndex >= 1 and raidIndex <= 8 then
      if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(icon, raidIndex)
      else
        local column = math.mod(raidIndex - 1, 4)
        local atlasRow = math.floor((raidIndex - 1) / 4)
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        icon:SetTexCoord(column * .25, (column + 1) * .25,
          atlasRow * .5, (atlasRow + 1) * .5)
      end
      icon:Show()
      return
    end

    -- Fall back to the marker texture already resolved on the source plate.
    local source = plate.raidicon
    if source and source.IsShown and source:IsShown() and source.GetTexture and source:GetTexture() then
      icon:SetTexture(source:GetTexture())
      if source.GetTexCoord then icon:SetTexCoord(source:GetTexCoord()) end
      icon:Show()
    else
      icon:Hide()
    end
  end

  local function CreateListRow(index)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function()
      if this.unit and UnitExists(this.unit) and TargetUnit then TargetUnit(this.unit) end
    end)

    row.health = CreateFrame("StatusBar", nil, row)
    row.health:SetFrameLevel(row:GetFrameLevel() + 1)
    row.health:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 20, 2)
    row.health:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 2)
    Z.CreateBackdrop(row.health, 1)

    row.raidicon = row.health:CreateTexture(nil, "OVERLAY")
    row.raidicon:SetPoint("RIGHT", row.health, "RIGHT", -1, 0)
    row.raidicon:SetWidth(12)
    row.raidicon:SetHeight(12)
    row.raidicon:SetAlpha(.45)
    row.raidicon:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("BOTTOMLEFT", row.health, "TOPLEFT", 0, 1)
    row.name:SetPoint("BOTTOMRIGHT", row.health, "TOPRIGHT", 0, 1)
    row.name:SetJustifyH("CENTER")

    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.level:SetPoint("RIGHT", row.health, "LEFT", -2, 0)
    row.level:SetJustifyH("RIGHT")

    row.healthText = row.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.healthText:SetAllPoints(row.health)
    row.healthText:SetJustifyH("CENTER")
    listRows[index] = row
    return row
  end

  local function UpdateListRow(row, entry, index, rowHeight, width)
    local plate, health = entry.plate, entry.plate.health
    row.unit, row.plate = plate.unit, plate
    row:SetWidth(width - LIST_PADDING * 2)
    row:SetHeight(rowHeight)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PADDING,
      -LIST_HEADER_HEIGHT - 2 - (index - 1) * rowHeight)

    row.health:SetHeight(math.max(5, tonumber(Z.config.nameplates.heighthealth) or 8))
    row.health:SetStatusBarTexture(Z.media[Z.config.nameplates.healthtexture])
    if health and health.GetMinMaxValues and health.GetValue then
      local minimum, maximum = health:GetMinMaxValues()
      if not maximum or maximum <= (minimum or 0) then minimum, maximum = 0, 1 end
      row.health:SetMinMaxValues(minimum or 0, maximum)
      row.health:SetValue(health:GetValue() or minimum or 0)
    else
      row.health:SetMinMaxValues(0, 1)
      row.health:SetValue(1)
    end
    if health and health.GetStatusBarColor then
      local r, g, b, a = health:GetStatusBarColor()
      row.health:SetStatusBarColor(r or .9, g or .2, b or .3, a or 1)
    end

    if health and health.backdrop and health.backdrop.GetBackdropBorderColor then
      local r, g, b, a = health.backdrop:GetBackdropBorderColor()
      row.health.backdrop:SetBackdropBorderColor(r or .2, g or .2, b or .2, a or 1)
    elseif plate.taggedByPlayer then
      row.health.backdrop:SetBackdropBorderColor(.35, 1, .05, .75)
    else
      row.health.backdrop:SetBackdropBorderColor(Z.GetStringColor(Z.config.appearance.border.color))
    end

    SetListFont(row.name, plate.name, 11)
    SetListFont(row.level, plate.level, 10)
    SetListFont(row.healthText, health and health.text, 9)
    row.name:SetText(plate.name and plate.name:GetText() or UnitName(plate.unit) or "Unknown")
    row.level:SetText(plate.level and plate.level:GetText()
      or (entry.level == 999 and "??" or entry.level))
    SetListTextColor(row.name, plate.name, 1, 1, 1, 1)
    SetListTextColor(row.level, plate.level, 1, 1, .2, 1)
    UpdateListRaidIcon(row, plate)

    local sourceText = health and health.text
    local healthText = sourceText and sourceText.GetText and sourceText:GetText()
    if Z.config.nameplates.showhp == "1" and healthText and healthText ~= "" then
      row.healthText:SetText(healthText)
      SetListTextColor(row.healthText, sourceText, 1, 1, 1, 1)
      row.healthText:Show()
    else
      row.healthText:Hide()
    end
    row:Show()
  end

  function list:Refresh()
    local settings = ListSettings()
    if not settings then return end
    local width = math.max(160, math.max(75, tonumber(Z.config.nameplates.width) or 120)
      + 20 + LIST_PADDING * 2 + 1)
    local useUnit = Z.config.nameplates.use_unitfonts == "1"
    local fontSize = tonumber(useUnit and Z.config.global.font_unit_size
      or Z.config.global.font_size) or 12
    local rowHeight = fontSize + math.max(5, tonumber(Z.config.nameplates.heighthealth) or 8) + 5
    local total = BuildCombatList()

    self:SetWidth(width)
    listCount:SetText("(" .. total .. ")")
    Z.CreateBackdrop(self, 0)

    if settings.collapsed == "1" then
      listCollapse.text:SetText("+")
      listDivider:Hide()
      listEmpty:Hide()
      self:SetHeight(LIST_HEADER_HEIGHT + 1)
      for i = 1, table.getn(listRows) do listRows[i]:Hide() end
      return
    end

    listCollapse.text:SetText("-")
    listDivider:Show()
    if total == 0 then
      -- An enabled list always leaves a small movable frame on screen.
      self:SetHeight(LIST_HEADER_HEIGHT + 18)
      listEmpty:Show()
    else
      self:SetHeight(LIST_HEADER_HEIGHT + 4 + total * rowHeight)
      listEmpty:Hide()
    end

    for i = 1, total do
      UpdateListRow(listRows[i] or CreateListRow(i), listEntries[i], i, rowHeight, width)
    end
    for i = total + 1, table.getn(listRows) do listRows[i]:Hide() end
  end

  listCollapse:SetScript("OnClick", function()
    local settings = ListSettings()
    if not settings then return end
    settings.collapsed = settings.collapsed == "1" and "0" or "1"
    list:Refresh()
  end)

  list:SetScript("OnShow", function()
    local settings = ListSettings()
    if settings then settings.shown = "1"; list:Refresh() end
  end)
  list:SetScript("OnHide", function()
    local settings = ListSettings()
    if settings then settings.shown = "0" end
  end)
  list:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.lastRefresh or 0) + .12 > now then return end
    this.lastRefresh = now
    this:Refresh()
  end)

  list:RegisterEvent("ADDON_LOADED")
  list:RegisterEvent("PLAYER_REGEN_DISABLED")
  list:RegisterEvent("PLAYER_REGEN_ENABLED")
  list:RegisterEvent("PLAYER_TARGET_CHANGED")
  pcall(list.RegisterEvent, list, "NAME_PLATE_UNIT_ADDED")
  pcall(list.RegisterEvent, list, "NAME_PLATE_UNIT_REMOVED")
  list:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
      if arg1 ~= "z_Nameplates" then return end
      this:UnregisterEvent("ADDON_LOADED")
      local settings = ListSettings()
      if not settings then return end
      this:ClearAllPoints()
      this:SetPoint(settings.point or "TOPRIGHT", UIParent,
        settings.relativePoint or "TOPRIGHT", tonumber(settings.x) or -32, tonumber(settings.y) or -180)
      if settings.shown == "1" then this:Show() end
    end
    if this:IsShown() then this:Refresh() end
  end)

  function Z.ToggleCombatList()
    if list:IsShown() then list:Hide() else list:Show() end
  end
  Z.combatList = list
end
