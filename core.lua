-- zNameplates: minimal standalone runtime for the extracted sfUI/pfUI
-- nameplate module. Nothing in this file skins or replaces non-nameplate UI.

zNameplates = zNameplates or {}
-- Keep one harmless global saved-variable declaration for a single upgrade
-- cycle. It makes WoW load the old zNameplates account file before optional
-- dependent zDNumbers starts, allowing that addon to inherit MikSBT_Save.
zNameplatesLegacyBridge = true
local Z = zNameplates
local ADDON = "z_Nameplates"
local PATH = "Interface\\AddOns\\z_Nameplates"

if not table.wipe then
  function table.wipe(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
    return tbl
  end
end

local defaults = {
  global = {
    font_default = PATH .. "\\Assets\\fonts\\Expressway.ttf",
    font_unit = PATH .. "\\Assets\\fonts\\Expressway.ttf",
    font_size = "10",
    font_unit_size = "10",
  },
  appearance = {
    border = {
      background = "0.1,0.1,0.1,0.8",
      color = "0,0,0,1",
      pixelperfect = "1",
      hidpi = "1",
      default = "1",
      nameplates = "-1",
    },
    castbar = {
      castbarcolor = ".7,.7,.9,.8",
      channelcolor = ".9,.9,.7,.8",
      texture = PATH .. "\\Assets\\img\\bar",
    },
    cd = {
      font = PATH .. "\\Assets\\fonts\\BigNoodleTitling.ttf",
      font_size = "12",
      dynamicsize = "1",
    },
  },
  unitframes = {
    abbrevnum = "1",
    abbrevname = "1",
    castbardecimals = "2",
    blizzard_raidicons = "1",
  },
  throttle = {
    nameplates = "10",
    nameplates_target = "50",
    nameplates_castbar = "100",
    nameplates_mass = "7",
  },
  combatlist = {
    shown = "1", collapsed = "1",
    point = "TOPLEFT", relativePoint = "TOPLEFT",
    x = "1223.77657471", y = "-4.8518200319566",
  },
  nameplates = {
    showhostile = "1", showfriendly = "1",
    disable_hostile_in_friendly = "0", disable_friendly_in_friendly = "0",
    use_unitfonts = "1", overlap_enemy = "0", overlap_friendly = "1",
    overlap_friendly_area = "1", overlap_combat = "1",
    nameplate_range = "41",
    distance_scale = "1", distance_min_scale = "58",
    distance_alpha = "1", distance_min_alpha = "37", los_fade = "1",
    los_desaturation = "27",
    verticalhealth = "0", vertical_offset = "0",
    showcastbar = "1", targetcastbar = "0", spellname = "0",
    showdebuffs = "1", showdebuffs_hostile = "1", showdebuffs_friendly = "0",
    owndebuffs = "0", clickthrough = "1", rightclick = "1", clickthreshold = "0.5",
    enemyclassc = "1", friendclassc = "1", friendclassnamec = "1",
    raidiconsize = "16", raidiconpos = "CENTER", raidiconoffx = "0", raidiconoffy = "-5",
    questicons = "1", questiconsize = "26", questiconoffset = "0",
    fullhealth = "0", target = "0", namefightcolor = "1",
    enemynpc = "0", enemyplayer = "0", neutralnpc = "0",
    friendlynpc = "1", friendlyplayer = "1", critters = "1", totems = "1",
    totemicons = "1", showguildname = "1",
    outcombatstate = "1", barcombatstate = "1",
    ccombatthreat = "1", ccombatofftank = "1", ccombatnothreat = "1",
    ccombatstun = "1", ccombatcasting = "0",
    combatthreat = ".7,.2,.2,1", combatofftank = ".7,.4,.2,1",
    combatnothreat = ".7,.7,.2,1", combatstun = ".2,.7,.7,1",
    combatcasting = ".7,.2,.7,1", combatofftanks = "",
    outfriendly = "0", outfriendlynpc = "1", outneutral = "1", outenemy = "1",
    targethighlight = "0", highlightcolor = "1,1,1,1",
    hide_blizzard_xp = "1",
    enemynamecolor = "1,1,1,1", friendlynamecolor = ".2,1,.2,1",
    critternamecolor = "1,1,1,.35",
    showhp = "1", hptextpos = "RIGHT", nametextpos = "CENTER",
    hptextformat = "curmaxs", width = "120", debuffsize = "14", debuffoffset = "4",
    heighthealth = "8", heightcast = "8", cpdisplay = "0",
    targetglow = "1", glowcolor = "0.361,0.004,0,0.35", targetzoom = "0",
    targetzoomval = ".40", notargalpha = ".75",
    healthtexture = PATH .. "\\Assets\\img\\bar",
    name = {
      fontstyle = "OUTLINE",
      fontstyle_friendly = "OUTLINE",
      fontsize = "10",
      fontsize_friendly = "10",
    },
    health = { offset = "-3" },
    debuffs = {
      filter = "none", whitelist = "", blacklist = "",
      showstacks = "0", position = "BOTTOM",
    },
    debufftimers = "1", debufftext = "1", debuffanim = "0",
  },
}
Z.defaults = defaults

local function CopyTable(source)
  local target = {}
  for key, value in pairs(source or {}) do
    target[key] = type(value) == "table" and CopyTable(value) or value
  end
  return target
end
Z.CopyTable = CopyTable

local function MergeMissing(target, source)
  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then target[key] = {} end
      MergeMissing(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

-- The original standalone build exposed one overlap switch for every plate.
-- Preserve that choice when upgrading, then retire the legacy key so enemy
-- and friendly overlap can be controlled independently from now on.
local function MigrateNameplateSettings(config)
  local nameplates = config and config.nameplates
  if type(nameplates) ~= "table" then return end

  if nameplates.overlap ~= nil then
    -- The legacy value is authoritative during this one-time migration. This
    -- also handles databases that received the new default keys on an earlier
    -- reload before migration was added.
    nameplates.overlap_enemy = nameplates.overlap
    nameplates.overlap_friendly = nameplates.overlap
    nameplates.overlap = nil
  end

  -- Roll back the short-lived global dark-gray migration. Only profiles that
  -- were marked by that migration and still contain its exact generated value
  -- are restored; independently chosen custom colours remain untouched.
  if nameplates.enemynamegray_v1 == "1" then
    if nameplates.enemynamecolor == ".3,.3,.3,1" then
      nameplates.enemynamecolor = "1,1,1,1"
    end
    nameplates.enemynamegray_v1 = nil
  end

  if nameplates.name then
    local currentUnitSize = (config.global and config.global.font_unit_size) or (config.global and config.global.font_size) or "10"
    if not nameplates.name.fontsize or nameplates.name.fontsize == "" then
      nameplates.name.fontsize = currentUnitSize
    end
    if not nameplates.name.fontsize_friendly or nameplates.name.fontsize_friendly == "" then
      nameplates.name.fontsize_friendly = nameplates.name.fontsize or currentUnitSize
    end
  end
end

-- Import only settings represented by the standalone schema. This prevents
-- unrelated sfUI/pfUI configuration from entering zNameplatesDB.
local function ImportKnown(target, source, schema)
  if type(source) ~= "table" then return end
  for key, shape in pairs(schema) do
    local value = source[key]
    if type(shape) == "table" then
      if type(target[key]) ~= "table" then target[key] = {} end
      ImportKnown(target[key], value, shape)
    elseif value ~= nil then
      target[key] = value
    end
  end
end

local function RebaseMedia(value)
  if type(value) ~= "string" then return value end
  -- Saved profiles can outlive an addon-folder rename. Rewrite every bundled
  -- asset, not just fonts, so existing bars and cooldown textures stay valid.
  value = string.gsub(value, "Interface\\AddOns\\zNameplates\\", PATH .. "\\")
  value = string.gsub(value, "Interface\\AddOns\\z_Nameplates\\", PATH .. "\\")
  value = string.gsub(value, "Interface\\AddOns\\pfUI\\fonts\\", PATH .. "\\Assets\\fonts\\")
  value = string.gsub(value, "Interface\\AddOns\\pfUI\\img\\", PATH .. "\\Assets\\img\\")
  value = string.gsub(value, "Interface\\AddOns\\sfUI\\fonts\\", PATH .. "\\Assets\\fonts\\")
  value = string.gsub(value, "Interface\\AddOns\\sfUI\\img\\", PATH .. "\\Assets\\img\\")
  return value
end

local function RebaseTable(tbl)
  for key, value in pairs(tbl) do
    if type(value) == "table" then RebaseTable(value) else tbl[key] = RebaseMedia(value) end
  end
end

Z.media = setmetatable({}, { __index = function(tbl, key)
  local value = RebaseMedia(tostring(key))
  value = string.gsub(value, "img:", PATH .. "\\Assets\\img\\")
  value = string.gsub(value, "font:", PATH .. "\\Assets\\fonts\\")
  rawset(tbl, key, value)
  return value
end })

function Z.StrSplit(delimiter, subject)
  if not subject then return nil end
  local fields = {}
  local pattern = string.format("([^%s]+)", delimiter or ":")
  string.gsub(subject, pattern, function(value) table.insert(fields, value) end)
  return unpack(fields)
end

function Z.GetStringColor(value)
  return Z.StrSplit(",", value or "1,1,1,1")
end

function Z.Round(value, places)
  places = places or 0
  local power = 1
  for i = 1, places do power = power * 10 end
  return math.floor(value * power + .5) / power
end

function Z.Abbreviate(value)
  local mode = Z.config.unitframes.abbrevnum
  if mode == "1" or mode == "2" then
    local sign = value < 0 and -1 or 1
    value = math.abs(value)
    if value > 1000000 then
      if mode == "2" then return (math.floor(value / 100000) / 10 * sign) .. "m" end
      return Z.Round(value / 1000000 * sign, 2) .. "m"
    elseif value > 1000 then
      if mode == "2" then return (math.floor(value / 100) / 10 * sign) .. "k" end
      return Z.Round(value / 1000 * sign, 2) .. "k"
    end
  end
  return math.floor(value)
end

local function PerfectPixel()
  local scale = GetCVar("useUiScale") == "1" and tonumber(GetCVar("uiScale")) or 1
  local _, _, screenHeight = string.find(GetCVar("gxResolution") or "1024x768", "x(%d+)")
  local pixel = 768 / (tonumber(screenHeight) or 768) / (scale or 1)
  if pixel > 1 then pixel = 1 end
  if Z.config.appearance.border.hidpi == "1" and pixel < .5 then pixel = pixel * 2 end
  return pixel
end

function Z.GetBorderSize(kind)
  local value = Z.config.appearance.border[kind or "default"]
  if not value or value == "-1" then value = Z.config.appearance.border.default end
  local raw = tonumber(value) or 3
  return raw, raw * PerfectPixel()
end

function Z.CreateBackdrop(frame, inset)
  if not frame then return end
  local _, border = Z.GetBorderSize()
  if inset then border = inset end
  local pixel = PerfectPixel()
  local backdrop = {
    bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
    edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = pixel,
    insets = { left=-pixel, right=-pixel, top=-pixel, bottom=-pixel },
  }
  if not frame.backdrop then
    frame.backdrop = CreateFrame("Frame", nil, frame)
    frame.backdrop:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  end
  frame.backdrop:ClearAllPoints()
  frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -border, border)
  frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", border, -border)
  frame.backdrop:SetBackdrop(backdrop)
  frame.backdrop:SetBackdropColor(Z.GetStringColor(Z.config.appearance.border.background))
  frame.backdrop:SetBackdropBorderColor(Z.GetStringColor(Z.config.appearance.border.color))
end

-- Render plate labels from a larger glyph surface, then resolve them back to
-- their configured height. This gives the parent frame's continuous distance
-- scale substantially more intermediate-looking text sizes on the old client.
function Z.SetSmoothFontString(text, font, size, flags)
  if not text or not font then return end
  size = math.max(1, tonumber(size) or 12)
  if text.SetTextHeight then
    text:SetFont(font, size * 2, flags or "")
    text:SetTextHeight(size)
  else
    text:SetFont(font, size, flags or "")
  end
end

Z.throttle = {}
function Z.throttle:Get(category)
  local fps = tonumber(Z.config.throttle[category]) or 10
  if fps <= 0 then fps = 10 end
  return 1 / fps
end

local function ClassColor(r, g, b)
  return { r=r, g=g, b=b, a=1, GetRGBA=function(self) return self.r, self.g, self.b, self.a end }
end
Z.classColors = setmetatable({
  WARRIOR=ClassColor(.78,.61,.43), MAGE=ClassColor(.25,.78,.92),
  ROGUE=ClassColor(1,.96,.41), DRUID=ClassColor(1,.49,.04),
  HUNTER=ClassColor(.67,.83,.45), SHAMAN=ClassColor(0,.44,.87),
  PRIEST=ClassColor(1,1,1), WARLOCK=ClassColor(.53,.53,.93),
  PALADIN=ClassColor(.96,.55,.73),
}, { __index=function() return ClassColor(.6,.6,.6) end })

Z.unitInfo = { players={}, mobs={} }
local function RememberUnit(unit)
  if not unit or not UnitExists(unit) then return end
  local name = UnitName(unit)
  if not name then return end
  local player = UnitIsPlayer(unit) and true or nil
  local _, classToken = UnitClass(unit)
  local level = UnitLevel(unit)
  local data = {
    class = UnitClassBase and UnitClassBase(unit) or classToken,
    level = level and level > 0 and level or nil,
    elite = not player and UnitClassification(unit) or nil,
    guild = player and GetGuildInfo(unit) or UnitSubName(unit),
  }
  Z.unitInfo[player and "players" or "mobs"][name] = data
end

function Z.GetUnitInfo(name, active, isPlayer)
  local data, player
  if isPlayer ~= false then
    data = Z.unitInfo.players[name]
    if data then player = true end
  end
  if not data and isPlayer ~= true then data = Z.unitInfo.mobs[name] end
  if not data then return end
  return data.class, data.level, data.elite, player, data.guild
end

local scanner = CreateFrame("Frame", "zNameplatesUnitScanner")
for _, eventName in pairs({
  "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
  "NAME_PLATE_UNIT_ADDED", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED",
}) do scanner:RegisterEvent(eventName) end
scanner:SetScript("OnEvent", function()
  if event == "NAME_PLATE_UNIT_ADDED" then RememberUnit(arg1)
  elseif event == "PLAYER_TARGET_CHANGED" then RememberUnit("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then RememberUnit("mouseover")
  else
    RememberUnit("player")
    for i = 1, GetNumPartyMembers() do RememberUnit("party" .. i) end
    for i = 1, GetNumRaidMembers() do RememberUnit("raid" .. i) end
  end
end)

Z.cooldownFrameType = COOLDOWN_FRAME_TYPE or "Model"
Z.CooldownFrame_OnUpdateModel = CooldownFrame_OnUpdateModel or function()
  if this.stopping == 0 then
    local finished = (GetTime() - this.start) / this.duration
    if finished < 1 then this:SetSequenceTime(0, finished * 1000); return end
    this.stopping = 1
    this:SetSequence(1)
    this:SetSequenceTime(1, 0)
  else
    this:AdvanceTime()
  end
end

local function FormatCooldown(seconds)
  if seconds >= 86400 then return math.ceil(seconds / 86400) .. "d" end
  if seconds >= 3600 then return math.ceil(seconds / 3600) .. "h" end
  if seconds >= 60 then return math.ceil(seconds / 60) .. "m" end
  if seconds >= 10 then return tostring(math.ceil(seconds)) end
  return string.format("%.1f", seconds)
end

local function CooldownTextOnUpdate()
  if (this.nextUpdate or 0) > GetTime() then return end
  this.nextUpdate = GetTime() + .1
  local remaining = this.duration - (GetTime() - this.start)
  if remaining <= 0 then this:Hide(); return end
  this.text:SetText(FormatCooldown(remaining))
end

function Z.SetCooldown(cooldown, start, duration, enable)
  if not cooldown then return end
  if cooldown.pfCooldownStyleAnimation == 0 then cooldown:SetAlpha(0) else cooldown:SetAlpha(1) end
  if cooldown.pfCooldownStyleText == 1 and start > 0 and duration > 0 and (not enable or enable > 0) then
    if not cooldown.zText then
      local textFrame = CreateFrame("Frame", nil, cooldown:GetParent())
      textFrame:SetAllPoints(cooldown)
      textFrame:SetFrameLevel(cooldown:GetParent():GetFrameLevel() + 2)
      textFrame.text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      textFrame.text:SetPoint("CENTER")
      textFrame:SetScript("OnUpdate", CooldownTextOnUpdate)
      cooldown.zText = textFrame
    end
    local size = tonumber(Z.config.appearance.cd.font_size) or 12
    if Z.config.appearance.cd.dynamicsize == "1" then
      size = math.max(size, (cooldown:GetParent():GetHeight() or 0) * .64)
    end
    cooldown.zText.text:SetFont(Z.media[Z.config.appearance.cd.font], size, "OUTLINE")
    cooldown.zText.start = start
    cooldown.zText.duration = duration
    cooldown.zText:Show()
  elseif cooldown.zText then
    cooldown.zText:Hide()
  end
end

Z.NAMEPLATE_OBJECTORDER = { "border", "glow", "name", "level", "levelicon", "raidicon" }

local function UpdateFonts()
  local locale = GetLocale()
  if locale == "zhCN" then
    Z.font_default, Z.font_unit = "Fonts\\FZXHLJW.TTF", "Fonts\\FZXHLJW.TTF"
  elseif locale == "zhTW" then
    Z.font_default, Z.font_unit = "Fonts\\FZXHLJW.ttf", "Fonts\\FZXHLJW.ttf"
  elseif locale == "koKR" then
    Z.font_default, Z.font_unit = "Fonts\\2002.TTF", "Fonts\\2002.TTF"
  else
    Z.font_default = Z.media[Z.config.global.font_default]
    Z.font_unit = Z.media[Z.config.global.font_unit]
  end
end

-- Keep quest markers inside the already-loaded core chunk. Some 1.12 clients
-- reject an additional standalone quest file before its functions are defined.
local questMarkerState = {
  byNPC = {}, byGUID = {}, byName = {}, titles = {}, activeQuestIDs = {},
  repeatable = {}, repeatableQuests = {}, repeatableTitles = {}, revision = 0,
  REPEATABLE = { text = "?", r = .20, g = .65, b = 1, priority = 1 },
  INCOMPLETE = { text = "?", r = .56, g = .56, b = .56, priority = 2 },
  AVAILABLE = { text = "!", r = 1, g = .82, b = .05, priority = 3 },
  COMPLETE = { text = "?", r = 1, g = .82, b = .05, priority = 4 },
}

local function BestQuestMarker(current, candidate)
  if not candidate or not questMarkerState[candidate] then return current end
  if not current or questMarkerState[candidate].priority > questMarkerState[current].priority then
    return candidate
  end
  return current
end

local function AddQuestMarker(npcID, status)
  npcID = tonumber(npcID)
  if not npcID or not questMarkerState[status] then return end
  questMarkerState.byNPC[npcID] = BestQuestMarker(questMarkerState.byNPC[npcID], status)
end

local function QuestNPCID(unit, guid)
  if C_CreatureInfo and C_CreatureInfo.GetCreatureID and guid then
    local ok, npcID = pcall(C_CreatureInfo.GetCreatureID, guid)
    if ok and npcID then return tonumber(npcID) end
  end
  if UnitCreatureID and unit then
    local ok, npcID = pcall(UnitCreatureID, unit)
    if ok and npcID then return tonumber(npcID) end
  end
end

local function IsRepeatableQuestMarker(data)
  if not data then return nil end
  if data.repeatable or data.isRepeatable or data.daily or data.isDaily or data.weekly then return true end
  if data["repeat"] or data.rep then return true end
  if data.frequency == 2 or data.frequency == 3 then return true end
  if data.min and data.lvl and math.abs(data.min - data.lvl) >= 30 then return true end
  local flags = tonumber(data.questFlags or data.flags)
  if flags and bit and bit.band then
    return bit.band(flags, 4096) ~= 0 or bit.band(flags, 32768) ~= 0
  end
end

local function QuestMarkerTitle(questID, data)
  local localization = pfDB and pfDB.quests and pfDB.quests.loc
  local localized = localization and localization[tonumber(questID)]
  return localized and localized.T or data and (data.title or data.Title or data.T or data.name)
end

local function QuestMarkerRepeatable(questID, title, data)
  return IsRepeatableQuestMarker(data)
    or questID and questMarkerState.repeatableQuests[tonumber(questID)]
    or title and questMarkerState.repeatableTitles[title]
end

local function QuestMarkerAvailable(questID, data, title)
  questID = tonumber(questID)
  title = title or QuestMarkerTitle(questID, data)
  if questID and (questMarkerState.activeQuestIDs[questID]
    or pfQuest and pfQuest.questlog and (pfQuest.questlog[questID] or pfQuest.questlog[tostring(questID)])) then
    return nil
  end
  if title and questMarkerState.titles[title] then return nil end
  if data and (data.isAvailable == false or data.available == false or data.isOnQuest) then return nil end

  local minimum = data and tonumber(data.min or data.minLevel or data.minimumLevel
    or data.minRequiredLevel or data.requiredLevel)
  local playerLevel = UnitLevel and tonumber(UnitLevel("player"))
  if minimum and playerLevel and minimum > playerLevel then return nil end
  if questID and pfQuest_history and pfQuest_history[questID]
    and not QuestMarkerRepeatable(questID, title, data) then
    return nil
  end
  if data and data.pre and pfQuest_history then
    local completed
    for _, prerequisite in pairs(data.pre) do
      if pfQuest_history[prerequisite] then completed = true; break end
    end
    if not completed then return nil end
  end
  return true
end

local function AddActiveQuestMarkers(questID, title, logStatus)
  questID = tonumber(questID)
  local quests = pfDB and pfDB.quests and pfDB.quests.data
  local data = questID and quests and quests[questID]
  local finishers = data and data["end"] and data["end"].U
  if not finishers then return end

  title = title or QuestMarkerTitle(questID, data)
  local status = title and questMarkerState.titles[title] or logStatus or "INCOMPLETE"
  local repeatable = QuestMarkerRepeatable(questID, title, data)
  if not repeatable and C_QuestLog and C_QuestLog.GetQuestDetails then
    local ok, details = pcall(C_QuestLog.GetQuestDetails, questID)
    if ok then repeatable = QuestMarkerRepeatable(questID, title, details) end
  end
  if repeatable then
    questMarkerState.repeatableQuests[questID] = true
    if title then questMarkerState.repeatableTitles[title] = true end
  end

  for _, npcID in pairs(finishers) do
    if repeatable then questMarkerState.repeatable[npcID] = true end
    AddQuestMarker(npcID, status == "COMPLETE" and "COMPLETE"
      or repeatable and "REPEATABLE" or "INCOMPLETE")
  end
end

function Z.RebuildQuestMarkers()
  table.wipe(questMarkerState.byNPC)
  table.wipe(questMarkerState.titles)
  table.wipe(questMarkerState.activeQuestIDs)

  local getTitle = pfQuestCompat and pfQuestCompat.GetQuestLogTitle or GetQuestLogTitle
  if getTitle then
    for index = 1, 40 do
      local title, _, _, header, _, complete = getTitle(index)
      if title and not header then
        local objectives = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(index)
        if complete == true or complete == 1 or objectives == 0 then
          questMarkerState.titles[title] = "COMPLETE"
        else
          questMarkerState.titles[title] = "INCOMPLETE"
        end
        if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
          local ok, questID = pcall(C_QuestLog.GetQuestIDForLogIndex, index)
          questID = ok and tonumber(questID)
          if questID and questID > 0 then
            questMarkerState.activeQuestIDs[questID] = questMarkerState.titles[title]
          end
        end
      end
    end
  end

  local quests = pfDB and pfDB.quests and pfDB.quests.data
  if quests and pfDatabase and pfDatabase.lastQuestGiversSet then
    for questID in pairs(pfDatabase.lastQuestGiversSet) do
      questID = tonumber(questID)
      local data = questID and quests[questID]
      local starters = data and data.start and data.start.U
      local title = QuestMarkerTitle(questID, data)
      if starters and QuestMarkerAvailable(questID, data, title) then
        local repeatable = QuestMarkerRepeatable(questID, title, data)
        if repeatable then
          questMarkerState.repeatableQuests[questID] = true
          if title then questMarkerState.repeatableTitles[title] = true end
        end
        for _, npcID in pairs(starters) do
          if repeatable then questMarkerState.repeatable[npcID] = true end
          AddQuestMarker(npcID, repeatable and "REPEATABLE" or "AVAILABLE")
        end
      end
    end
  end

  if quests and pfQuest and pfQuest.questlog then
    for questID, entry in pairs(pfQuest.questlog) do
      AddActiveQuestMarkers(questID, type(entry) == "table" and entry.title)
    end
  end
  for questID, status in pairs(questMarkerState.activeQuestIDs) do
    AddActiveQuestMarkers(questID, nil, status)
  end

  questMarkerState.revision = questMarkerState.revision + 1
  if Z.nameplates then Z.nameplates.eventcache = true end
end

function Z.RememberQuestGiver()
  local unit = UnitExists("npc") and "npc" or UnitExists("target") and "target" or nil
  if not unit or UnitIsPlayer(unit) then return end
  local name = UnitName(unit)
  local guid = UnitGUID and UnitGUID(unit)
  local npcID = QuestNPCID(unit, guid)
  local status

  local function ConsiderQuest(entry, available)
    local details = type(entry) == "table" and entry or nil
    local title = details and (details.title or details.name) or type(entry) == "string" and entry
    local questID = details and tonumber(details.questID or details.questId or details.id)
    local quests = pfDB and pfDB.quests and pfDB.quests.data
    local data = questID and quests and quests[questID]
    title = title or QuestMarkerTitle(questID, data)
    local repeatable = QuestMarkerRepeatable(questID, title, details)
      or QuestMarkerRepeatable(questID, title, data)
    if repeatable then
      if npcID then questMarkerState.repeatable[npcID] = true end
      if questID then questMarkerState.repeatableQuests[questID] = true end
      if title then questMarkerState.repeatableTitles[title] = true end
    end

    local loggedStatus = title and questMarkerState.titles[title]
      or questID and questMarkerState.activeQuestIDs[questID]
    local complete = details and (details.isComplete or details.isCompleted
      or details.readyForTurnIn or details.readyForTurnin)
    if not available and loggedStatus == "COMPLETE" then complete = true end
    if complete then
      status = BestQuestMarker(status, "COMPLETE")
    elseif available then
      if loggedStatus then
        status = BestQuestMarker(status, loggedStatus == "COMPLETE" and "COMPLETE"
          or repeatable and "REPEATABLE" or "INCOMPLETE")
      elseif QuestMarkerAvailable(questID, data or details, title)
        and not (details and (details.isAvailable == false or details.available == false)) then
        status = BestQuestMarker(status, repeatable and "REPEATABLE" or "AVAILABLE")
      end
    else
      status = BestQuestMarker(status, repeatable and "REPEATABLE" or "INCOMPLETE")
    end
  end

  if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
    local ok, entries = pcall(C_GossipInfo.GetAvailableQuests)
    if ok and type(entries) == "table" then
      for _, entry in pairs(entries) do ConsiderQuest(entry, true) end
    end
  end
  if C_GossipInfo and C_GossipInfo.GetActiveQuests then
    local ok, entries = pcall(C_GossipInfo.GetActiveQuests)
    if ok and type(entries) == "table" then
      for _, entry in pairs(entries) do ConsiderQuest(entry, nil) end
    end
  end
  if GetGossipAvailableQuests then
    local entries = { GetGossipAvailableQuests() }
    for index = 1, table.getn(entries), 2 do
      ConsiderQuest(entries[index], true)
    end
  end
  if GetGossipActiveQuests then
    local entries = { GetGossipActiveQuests() }
    for index = 1, table.getn(entries), 2 do
      ConsiderQuest(entries[index], nil)
    end
  end
  if GetNumAvailableQuests then
    for index = 1, GetNumAvailableQuests() do
      local title = GetAvailableTitle and GetAvailableTitle(index)
      ConsiderQuest(title or {}, true)
    end
  end
  if GetNumActiveQuests and GetActiveTitle then
    for index = 1, GetNumActiveQuests() do
      ConsiderQuest(GetActiveTitle(index), nil)
    end
  end
  if event == "QUEST_COMPLETE" or event == "QUEST_PROGRESS" and IsQuestCompletable and IsQuestCompletable() then
    status = BestQuestMarker(status, "COMPLETE")
  elseif event == "QUEST_PROGRESS" then
    status = BestQuestMarker(status, "INCOMPLETE")
  elseif event == "QUEST_DETAIL" then
    status = BestQuestMarker(status, "AVAILABLE")
  end

  if guid then questMarkerState.byGUID[guid] = status or "NONE" end
  if name then questMarkerState.byName[name] = status or "NONE" end
  if npcID then questMarkerState.byNPC[npcID] = status end
  questMarkerState.revision = questMarkerState.revision + 1
  if Z.nameplates then Z.nameplates.eventcache = true end
end

function Z.CreateQuestIcon(plate)
  local marker = plate:CreateFontString(nil, "BACKGROUND", "GameFontNormalLarge")
  marker:SetJustifyH("CENTER")
  marker:SetJustifyV("BOTTOM")
  marker:SetShadowColor(0, 0, 0, .9)
  marker:SetShadowOffset(1, -1)
  marker:Hide()
  plate.questIcon = marker
end

function Z.ConfigureQuestIcon(plate, font)
  if not plate or not plate.questIcon or not Z.config then return end
  local size = tonumber(Z.config.nameplates.questiconsize) or 26
  local offset = tonumber(Z.config.nameplates.questiconoffset) or 0
  if size < 8 then size = 8 elseif size > 72 then size = 72 end
  plate.questIcon:ClearAllPoints()
  plate.questIcon:SetPoint("BOTTOM", plate.name, "TOP", 0, offset)
  plate.questIcon:SetFont(font or Z.font_default, size, "THICKOUTLINE")
  plate.questIconRevision = nil
  if Z.config.nameplates.questicons ~= "1" then plate.questIcon:Hide() end
end

function Z.UpdateQuestIcon(plate, name, isPlayer)
  local marker = plate and plate.questIcon
  if not marker then return end
  if not Z.config or Z.config.nameplates.questicons ~= "1" or isPlayer or not plate.unit or not name then
    marker:Hide()
    plate.questIconRevision = nil
    return
  end

  local guid = plate.cachedGuid or UnitGUID and UnitGUID(plate.unit)
  if plate.questIconRevision == questMarkerState.revision and plate.questIconGUID == guid
    and plate.questIconName == name then return end
  plate.questIconRevision = questMarkerState.revision
  plate.questIconGUID = guid
  plate.questIconName = name

  local npcID = QuestNPCID(plate.unit, guid)
  local status = guid and questMarkerState.byGUID[guid]
  if status == "NONE" then marker:Hide(); return end
  if not status and npcID then status = questMarkerState.byNPC[npcID] end
  if not status then status = questMarkerState.byName[name] end
  if status == "NONE" then marker:Hide(); return end
  if not status and pfDatabase and pfDatabase.nameIndex and pfDatabase.nameIndex.units then
    local matches = pfDatabase.nameIndex.units[name]
    if matches then
      for _, id in pairs(matches) do
        local candidate = questMarkerState.byNPC[id]
        if candidate and (not status or questMarkerState[candidate].priority > questMarkerState[status].priority) then
          status = candidate
        end
      end
    end
  end

  local display = status and questMarkerState[status]
  if not display then marker:Hide(); return end
  marker:SetText(display.text)
  marker:SetTextColor(display.r, display.g, display.b, 1)
  marker:Show()
end

local questWatcher = CreateFrame("Frame", "zNameplatesQuestWatcher", UIParent)
for _, eventName in pairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_LOG_UPDATE",
  "QUEST_WATCH_UPDATE", "UNIT_QUEST_LOG_CHANGED", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED",
  "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_FINISHED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
  "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
  pcall(questWatcher.RegisterEvent, questWatcher, eventName)
end
questWatcher:SetScript("OnEvent", function()
  if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL"
    or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE"
    or (event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN")
      and UnitExists("npc") then
    Z.RememberQuestGiver()
  else
    table.wipe(questMarkerState.byGUID)
    table.wipe(questMarkerState.byName)
  end
  this.liveRefresh = nil
  this.refreshAt = GetTime() + .1
end)
questWatcher:SetScript("OnUpdate", function()
  if not this.refreshAt or GetTime() < this.refreshAt then return end
  if pfQuest and ((pfQuest.queueCount or 0) > 0 or pfQuest.updateQuestGivers or pfQuest.updateQuestLog) then
    if not this.liveRefresh then
      Z.RebuildQuestMarkers()
      if UnitExists("npc") then Z.RememberQuestGiver() end
      this.liveRefresh = true
    end
    this.refreshAt = GetTime() + .1
    return
  end
  this.refreshAt = nil
  this.liveRefresh = nil
  Z.RebuildQuestMarkers()
  if UnitExists("npc") then Z.RememberQuestGiver() end
end)

function Z.RefreshQuestIcons()
  questMarkerState.revision = questMarkerState.revision + 1
  questWatcher.refreshAt = GetTime() + .1
  if Z.nameplates then Z.nameplates.eventcache = true end
end

function Z.Refresh()
  UpdateFonts()
  if Z.ApplyBlizzardXPText then Z.ApplyBlizzardXPText() end
  if Z.RefreshQuestIcons then Z.RefreshQuestIcons() end
  if Z.nameplates and Z.nameplates.UpdateConfig then Z.nameplates.UpdateConfig() end
  if Z.combatList and Z.combatList.Refresh then Z.combatList:Refresh() end
  if Z.options and Z.options.Refresh then Z.options:Refresh() end
end

local originalCombatTextAddMessage
local hiddenCombatTextAddMessage

local function IsExperienceFloatingText(message)
  if type(message) ~= "string" then return nil end
  local text = string.lower(message)
  return string.find(text, "xp", 1, true) or
    string.find(text, "experience", 1, true) or
    string.find(text, "经验", 1, true) or
    string.find(text, "경험", 1, true) or
    string.find(text, "経験", 1, true)
end

function Z.ApplyBlizzardXPText()
  local hide = Z.config and Z.config.nameplates and Z.config.nameplates.hide_blizzard_xp == "1"
  if hide then
    if not hiddenCombatTextAddMessage and CombatText_AddMessage then
      originalCombatTextAddMessage = CombatText_AddMessage
      hiddenCombatTextAddMessage = function(message, scrollFunction, r, g, b, displayType, isStaggered)
        if displayType == "xp" or displayType == "XP_GAIN" or IsExperienceFloatingText(message) then return end
        return originalCombatTextAddMessage(message, scrollFunction, r, g, b, displayType, isStaggered)
      end
      CombatText_AddMessage = hiddenCombatTextAddMessage
    end
  elseif hiddenCombatTextAddMessage then
    if CombatText_AddMessage == hiddenCombatTextAddMessage then
      CombatText_AddMessage = originalCombatTextAddMessage
    end
    hiddenCombatTextAddMessage = nil
    originalCombatTextAddMessage = nil
  end
end

function Z.Reset()
  table.wipe(Z.config)
  MergeMissing(Z.config, defaults)
  RebaseTable(Z.config)
  Z.Refresh()
end

local loader = CreateFrame("Frame", "zNameplatesLoader")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if arg1 ~= ADDON then return end
  this:UnregisterEvent("ADDON_LOADED")

  zNameplatesDB = zNameplatesDB or {}
  if type(zNameplatesDB.config) ~= "table" then
    zNameplatesDB.config = CopyTable(defaults)
    if type(pfUI_config) == "table" then
      ImportKnown(zNameplatesDB.config, pfUI_config, defaults)
      -- pfUI only has the old combined overlap setting. Import it into both
      -- standalone controls so extraction does not silently change behavior.
      if type(pfUI_config.nameplates) == "table" and pfUI_config.nameplates.overlap ~= nil then
        zNameplatesDB.config.nameplates.overlap_enemy = pfUI_config.nameplates.overlap
        zNameplatesDB.config.nameplates.overlap_friendly = pfUI_config.nameplates.overlap
      end
      if type(pfUI_throttle) == "table" then
        local map = {
          nameplates="nameplates_custom", nameplates_target="nameplates_target_custom",
          nameplates_castbar="nameplates_castbar_custom", nameplates_mass="nameplates_mass_custom",
        }
        for key, oldKey in pairs(map) do
          if pfUI_throttle[oldKey] then zNameplatesDB.config.throttle[key] = pfUI_throttle[oldKey] end
        end
      end
      zNameplatesDB.importedFromPfUI = true
    end
  end
  MigrateNameplateSettings(zNameplatesDB.config)
  MergeMissing(zNameplatesDB.config, defaults)
  RebaseTable(zNameplatesDB.config)
  Z.config = zNameplatesDB.config
  UpdateFonts()
  Z.ApplyBlizzardXPText()

  if Z.StartNameplates then Z.StartNameplates() end
  if Z.options and Z.options.Refresh then Z.options:Refresh() end
end)
