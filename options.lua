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
      { "input", "Hostile font size", {"nameplates","name","fontsize"} },
      { "input", "Friendly font size", {"nameplates","name","fontsize_friendly"} },
      { "select", "Hostile font style", {"nameplates","name","fontstyle"}, fontStyles },
      { "select", "Friendly font style", {"nameplates","name","fontstyle_friendly"}, fontStyles },
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
      { "preview", "Hostile Text Preview", nil, "hostile" },
      { "preview", "Friendly Text Preview", nil, "friendly" },
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
  local col = math.floor((index - 1) / 14)
  local row = math.mod(index - 1, 14)
  local x = 22 + col * 390
  local y = -18 - row * 34
  local kind, text, path, extra = item[1], item[2], item[3], item[4]
  local widget = { kind=kind, path=path, extra=extra }

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
      local isFriendly = widget.extra == "friendly"
      local customSize = isFriendly
        and (Z.config.nameplates.name.fontsize_friendly or Z.config.nameplates.name.fontsize)
        or Z.config.nameplates.name.fontsize
      local size = tonumber(customSize)
        or tonumber(useUnit and Z.config.global.font_unit_size or Z.config.global.font_size)
        or 10
      local style = isFriendly
        and (Z.config.nameplates.name.fontstyle_friendly or Z.config.nameplates.name.fontstyle or "")
        or (Z.config.nameplates.name.fontstyle or "")
      widget.control:SetFont(font, math.max(10, size + 2), style)
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
  local listTotemButtons = {}
  local listTotemEntries = {}
  local listTotemCount = 0
  local listMainEntries = {}
  local listMainCount = 0
  local listTaggedEntries = {}
  local listTaggedCount = 0
  local listRows = {}
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

  local listTaggedDivider = list:CreateTexture(nil, "ARTWORK")
  listTaggedDivider:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  listTaggedDivider:SetVertexColor(.45, .45, .45, .4)
  listTaggedDivider:SetHeight(1)
  listTaggedDivider:Hide()

  local listEmpty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  listEmpty:SetPoint("TOP", list, "TOP", 0, -LIST_HEADER_HEIGHT - 5)
  listEmpty:SetText("No enemies in combat")

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

  local TOTEM_ICONS = {
    ["strength of earth totem"] = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    ["stoneskin totem"] = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    ["stoneclaw totem"] = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
    ["earthbind totem"] = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    ["tremor totem"] = "Interface\\Icons\\Spell_Nature_TremorTotem",
    ["searing totem"] = "Interface\\Icons\\Spell_Fire_SearingTotem",
    ["magma totem"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["fire nova totem"] = "Interface\\Icons\\Spell_Fire_SealOfFire",
    ["flametongue totem"] = "Interface\\Icons\\Spell_Nature_GuardianWard",
    ["frost resistance totem"] = "Interface\\Icons\\Spell_FrostResistanceTotem_01",
    ["healing stream totem"] = "Interface\\Icons\\INV_Spear_04",
    ["mana spring totem"] = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    ["mana tide totem"] = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    ["poison cleansing totem"] = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
    ["disease cleansing totem"] = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem",
    ["fire resistance totem"] = "Interface\\Icons\\Spell_FireResistanceTotem_01",
    ["grounding totem"] = "Interface\\Icons\\Spell_Nature_GroundingTotem",
    ["windfury totem"] = "Interface\\Icons\\Spell_Nature_Windfury",
    ["grace of air totem"] = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
    ["nature resistance totem"] = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",
    ["windwall totem"] = "Interface\\Icons\\Spell_Nature_EarthBind",
    ["tranquil air totem"] = "Interface\\Icons\\Spell_Nature_Brilliance",
  }

  local function GetTotemTexture(plate, name)
    if plate and plate.totemIcon and plate.totemIcon ~= "" then return plate.totemIcon end
    if plate and plate.totem and plate.totem.icon and plate.totem.icon.GetTexture then
      local tex = plate.totem.icon:GetTexture()
      if tex and tex ~= "" then return tex end
    end
    if plate and plate.cachedGuid and C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
      local aura = C_UnitAuras.GetBuffDataByIndex(plate.cachedGuid, 1)
      if aura and aura.icon and aura.icon ~= "" then return aura.icon end
    end
    local cleanName = string.lower(name or "")
    cleanName = string.gsub(cleanName, "%s+[%d%a]+$", "")
    cleanName = string.gsub(cleanName, "^%s+", "")
    cleanName = string.gsub(cleanName, "%s+$", "")
    if TOTEM_ICONS[cleanName] then return TOTEM_ICONS[cleanName] end
    for key, tex in pairs(TOTEM_ICONS) do
      if string.find(cleanName, key, 1, true) then return tex end
    end
    if string.find(cleanName, "heal", 1, true) then return "Interface\\Icons\\INV_Spear_04" end
    return "Interface\\Icons\\Spell_Nature_EarthBindTotem"
  end

  local function IsPlateTotem(plate, name)
    if not plate then return false end
    if plate.isTotem then return true end
    if plate.cachedGuid and UnitCreatureTypeID and UnitCreatureTypeID(plate.cachedGuid) == 11 then return true end
    local unit = plate.unit
    if unit and UnitCreatureType and UnitCreatureType(unit) == "Totem" then return true end
    if name and string.find(name, "Totem", 1, true) then return true end
    return false
  end

  local function StartTargetAttack()
    if SlashCmdList and SlashCmdList.STARTATTACK then SlashCmdList.STARTATTACK("")
    else
      local inCombat = (PlayerFrame and PlayerFrame.inCombat) or (Z.nameplates and Z.nameplates.combat and Z.nameplates.combat.inCombat)
      if AttackTarget and UnitCanAttack("player", "target") and not inCombat then AttackTarget() end
    end
  end

  local function SendPetAttack(unit)
    if not UnitExists("pet") or (UnitIsDead and UnitIsDead("pet")) then return end
    if not unit or not UnitExists(unit) then return end
    if UnitIsUnit and UnitIsUnit("target", unit) then
      if PetAttack then PetAttack() end
      return
    end
    local hadTarget = UnitExists("target")
    TargetUnit(unit)
    if PetAttack then PetAttack() end
    if hadTarget then TargetLastTarget() else ClearTarget() end
  end

  local function HandleRowClick(unit)
    if not unit or not UnitExists(unit) then return end
    if arg1 == "RightButton" then SendPetAttack(unit)
    else TargetUnit(unit); StartTargetAttack() end
  end

  local function ListPlateLevel(plate)
    local level = plate.unit and UnitLevel and UnitLevel(plate.unit)
    if level and level > 0 then return level end
    local label = plate.level and plate.level.GetText and plate.level:GetText()
    local _, _, number = string.find(label or "", "(%d+)")
    if number then return tonumber(number) end
    if level == -1 or (label and string.find(label, "?", 1, true)) then return 999 end
    return 0
  end

  local function TotemCompare(left, right)
    local leftHeal = string.find(left.name, "heal", 1, true) and 1 or 0
    local rightHeal = string.find(right.name, "heal", 1, true) and 1 or 0
    if leftHeal ~= rightHeal then return leftHeal > rightHeal end
    if left.name ~= right.name then return left.name < right.name end
    return left.guid < right.guid
  end

  local function ListCompare(left, right)
    if left.tagged ~= right.tagged then return left.tagged < right.tagged end
    if left.level ~= right.level then return left.level > right.level end
    if left.name ~= right.name then return left.name < right.name end
    return left.guid < right.guid
  end

  local function SortEntries(entries, count, compareFunc)
    for i = 2, count do
      local entry = entries[i]
      local index = i - 1
      while index >= 1 and compareFunc(entry, entries[index]) do
        entries[index + 1] = entries[index]
        index = index - 1
      end
      entries[index + 1] = entry
    end
  end

  local function IsEnemyAttackable(plate, unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDead and UnitIsDead(unit) then return false end
    if plate and plate.isCritter then return false end
    if plate and plate.isFriendly then return false end
    if UnitCanAttack and not UnitCanAttack("player", unit) then return false end
    if UnitIsFriend and UnitIsFriend("player", unit) then return false end
    if UnitCanAssist and UnitCanAssist("player", unit) then return false end
    if UnitPlayerOrPetInParty and UnitPlayerOrPetInParty(unit) then return false end
    if UnitPlayerOrPetInRaid and UnitPlayerOrPetInRaid(unit) then return false end
    if UnitIsUnit and (UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet")) then return false end
    if UnitReaction then
      local reaction = UnitReaction("player", unit)
      if reaction and reaction >= 5 then return false end
    end
    return true
  end

  local function BuildCombatList()
    for index = listTotemCount, 1, -1 do listTotemEntries[index] = nil end
    listTotemCount = 0
    for index = listMainCount, 1, -1 do listMainEntries[index] = nil end
    listMainCount = 0
    for index = listTaggedCount, 1, -1 do listTaggedEntries[index] = nil end
    listTaggedCount = 0

    local visible = Z.nameplates and Z.nameplates.visiblePlates
    if not visible then return 0 end
    for base in pairs(visible) do
      local plate = base and base.nameplate
      if plate and plate.unit and (not base.IsVisible or base:IsVisible()) then
        local unit = plate.unit
        if IsEnemyAttackable(plate, unit) then
          local guid = plate.cachedGuid or plate.unit
          local name = (plate.name and plate.name.GetText and plate.name:GetText()) or (UnitName and UnitName(unit)) or "Unknown"
          if IsPlateTotem(plate, name) then
            listTotemCount = listTotemCount + 1
            listTotemEntries[listTotemCount] = { plate=plate, guid=tostring(guid), name=string.lower(name), icon=GetTotemTexture(plate, name), unit=unit }
          elseif UnitAffectingCombat and UnitAffectingCombat(unit) then
            local isTaggedOther = plate.taggedByOther or (UnitIsTapped and UnitIsTappedByPlayer and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit))
            local entry = { plate=plate, guid=tostring(guid), name=string.lower(name), level=ListPlateLevel(plate), tagged=(plate.taggedByPlayer or plate.taggedByOther) and 1 or 0 }
            if isTaggedOther then
              listTaggedCount = listTaggedCount + 1
              listTaggedEntries[listTaggedCount] = entry
            else
              listMainCount = listMainCount + 1
              listMainEntries[listMainCount] = entry
            end
          end
        end
      end
    end
    SortEntries(listTotemEntries, listTotemCount, TotemCompare)
    SortEntries(listMainEntries, listMainCount, ListCompare)
    SortEntries(listTaggedEntries, listTaggedCount, ListCompare)
    return listTotemCount + listMainCount + listTaggedCount
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
    if font and font ~= "" then text:SetFont(font, math.max(8, tonumber(size) or fallbackSize or 11), flags or "") end
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
    if GetRaidTargetIndex and plate.unit then raidIndex = GetRaidTargetIndex(plate.unit) end
    if not raidIndex and plate.raidIndex then raidIndex = plate.raidIndex end
    if raidIndex and UnitPopupButtons and UnitPopupButtons["RAID_TARGET_" .. raidIndex] then
      SetRaidTargetIconTexture(icon, raidIndex)
      icon:Show()
      return
    end
    local source = plate.raidicon
    if source and source.IsShown and source:IsShown() and source.GetTexture and source:GetTexture() then
      icon:SetTexture(source:GetTexture())
      if source.GetTexCoord then icon:SetTexCoord(source.GetTexCoord()) end
      icon:Show()
    else icon:Hide() end
  end

  local function CreateTotemButton(index)
    local btn = CreateFrame("Button", nil, list)
    btn:SetWidth(26); btn:SetHeight(26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(.078, .92, .079, .937)
    Z.CreateBackdrop(btn, 1)
    btn:SetScript("OnClick", function() HandleRowClick(this.unit) end)
    btn:SetScript("OnEnter", function()
      if this.unit and UnitExists(this.unit) then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(this.unit)
        GameTooltip:Show()
      elseif this.name then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.name, 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    listTotemButtons[index] = btn
    return btn
  end

  local function CreateListRow(index)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function() HandleRowClick(this.unit) end)
    row.health = CreateFrame("StatusBar", nil, row)
    row.health:SetFrameLevel(row:GetFrameLevel() + 1)
    row.health:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 20, 2)
    row.health:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 2)
    Z.CreateBackdrop(row.health, 1)
    row.raidicon = row.health:CreateTexture(nil, "OVERLAY")
    row.raidicon:SetPoint("RIGHT", row.health, "RIGHT", -1, 0)
    row.raidicon:SetWidth(12); row.raidicon:SetHeight(12); row.raidicon:SetAlpha(.45); row.raidicon:Hide()
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

  local function UpdateListRow(row, entry, topOffset, rowHeight, width)
    local plate, health = entry.plate, entry.plate.health
    row.unit, row.plate = plate.unit, plate
    row:SetWidth(width - LIST_PADDING * 2)
    row:SetHeight(rowHeight)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PADDING, topOffset)
    row.health:SetHeight(math.max(5, tonumber(Z.config.nameplates.heighthealth) or 8))
    row.health:SetStatusBarTexture(Z.media[Z.config.nameplates.healthtexture])
    if health and health.GetMinMaxValues and health.GetValue then
      local minimum, maximum = health:GetMinMaxValues()
      if not maximum or maximum <= (minimum or 0) then minimum, maximum = 0, 1 end
      row.health:SetMinMaxValues(minimum or 0, maximum)
      row.health:SetValue(health:GetValue() or minimum or 0)
    else row.health:SetMinMaxValues(0, 1); row.health:SetValue(1) end
    if health and health.GetStatusBarColor then
      local r, g, b, a = health:GetStatusBarColor()
      row.health:SetStatusBarColor(r or .9, g or .2, b or .3, a or 1)
    end
    if health and health.backdrop and health.backdrop.GetBackdropBorderColor then
      local r, g, b, a = health.backdrop:GetBackdropBorderColor()
      row.health.backdrop:SetBackdropBorderColor(r or .2, g or .2, b or .2, a or 1)
    elseif plate.taggedByPlayer then row.health.backdrop:SetBackdropBorderColor(.35, 1, .05, .75)
    else row.health.backdrop:SetBackdropBorderColor(Z.GetStringColor(Z.config.appearance.border.color)) end
    SetListFont(row.name, plate.name, 11)
    SetListFont(row.level, plate.level, 10)
    SetListFont(row.healthText, health and health.text, 9)
    row.name:SetText(plate.name and plate.name:GetText() or UnitName(plate.unit) or "Unknown")
    row.level:SetText(plate.level and plate.level:GetText() or (entry.level == 999 and "??" or entry.level))
    SetListTextColor(row.name, plate.name, 1, 1, 1, 1)
    SetListTextColor(row.level, plate.level, 1, 1, .2, 1)
    UpdateListRaidIcon(row, plate)
    local sourceText = health and health.text
    local healthText = sourceText and sourceText.GetText and sourceText:GetText()
    if Z.config.nameplates.showhp == "1" and healthText and healthText ~= "" then
      row.healthText:SetText(healthText)
      SetListTextColor(row.healthText, sourceText, 1, 1, 1, 1)
      row.healthText:Show()
    else row.healthText:Hide() end
    row:Show()
  end

  function list:Refresh()
    local settings = ListSettings()
    if not settings then return end
    local width = math.max(160, math.max(75, tonumber(Z.config.nameplates.width) or 120) + 20 + LIST_PADDING * 2 + 1)
    local fontSize = tonumber((Z.config.nameplates.use_unitfonts == "1") and Z.config.global.font_unit_size or Z.config.global.font_size) or 12
    local rowHeight = fontSize + math.max(5, tonumber(Z.config.nameplates.heighthealth) or 8) + 5
    local total = BuildCombatList()
    self:SetWidth(width)
    listCount:SetText("(" .. total .. ")")
    Z.CreateBackdrop(self, 0)
    if settings.collapsed == "1" then
      listCollapse.text:SetText("+")
      listDivider:Hide()
      listEmpty:Hide()
      listTaggedDivider:Hide()
      self:SetHeight(LIST_HEADER_HEIGHT + 1)
      for i = 1, table.getn(listTotemButtons) do listTotemButtons[i]:Hide() end
      for i = 1, table.getn(listRows) do listRows[i]:Hide() end
      return
    end
    listCollapse.text:SetText("-")
    listDivider:Show()
    if total == 0 then
      self:SetHeight(LIST_HEADER_HEIGHT + 18)
      listEmpty:Show()
      listTaggedDivider:Hide()
      for i = 1, table.getn(listTotemButtons) do listTotemButtons[i]:Hide() end
      for i = 1, table.getn(listRows) do listRows[i]:Hide() end
      return
    end
    listEmpty:Hide()
    local currentY = -LIST_HEADER_HEIGHT - 4
    if listTotemCount > 0 then
      local totemSize, totemGap = 26, 4
      local totemStartX = LIST_PADDING + math.max(0, math.floor((width - LIST_PADDING * 2 - (4 * totemSize + 3 * totemGap)) / 2))
      for i = 1, listTotemCount do
        local btn = listTotemButtons[i] or CreateTotemButton(i)
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self, "TOPLEFT", totemStartX + col * (totemSize + totemGap), currentY - row * (totemSize + totemGap))
        btn.unit, btn.name = listTotemEntries[i].unit, (listTotemEntries[i].plate.name and listTotemEntries[i].plate.name:GetText() or listTotemEntries[i].name)
        btn.icon:SetTexture(listTotemEntries[i].icon)
        btn:Show()
      end
      currentY = currentY - (math.ceil(listTotemCount / 4) * (totemSize + totemGap)) - 2
    end
    for i = listTotemCount + 1, table.getn(listTotemButtons) do listTotemButtons[i]:Hide() end
    for i = 1, listMainCount do
      local row = listRows[i] or CreateListRow(i)
      UpdateListRow(row, listMainEntries[i], currentY - (i - 1) * rowHeight, rowHeight, width)
    end
    currentY = currentY - (listMainCount * rowHeight)
    if listTaggedCount > 0 then
      if listMainCount > 0 or listTotemCount > 0 then
        listTaggedDivider:ClearAllPoints()
        listTaggedDivider:SetPoint("TOPLEFT", self, "TOPLEFT", LIST_PADDING + 4, currentY - 2)
        listTaggedDivider:SetPoint("TOPRIGHT", self, "TOPRIGHT", -LIST_PADDING - 4, currentY - 2)
        listTaggedDivider:Show()
        currentY = currentY - 5
      else listTaggedDivider:Hide() end
      for j = 1, listTaggedCount do
        local row = listRows[listMainCount + j] or CreateListRow(listMainCount + j)
        UpdateListRow(row, listTaggedEntries[j], currentY - (j - 1) * rowHeight, rowHeight, width)
      end
      currentY = currentY - (listTaggedCount * rowHeight)
    else listTaggedDivider:Hide() end
    for i = listMainCount + listTaggedCount + 1, table.getn(listRows) do listRows[i]:Hide() end
    self:SetHeight(-currentY + 4)
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
