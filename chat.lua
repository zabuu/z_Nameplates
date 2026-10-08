-- Chat labels belong to the live speaker's plate and inherit its distance
-- scaling. A borderless rounded background adds no mouse input.
local Z = zNameplates
local watcher = CreateFrame("Frame", "zNameplatesChatWatcher")
local messages, labels, previousCVars = {}, {}, {}
local projectedAnchors = {}
local suppressedNative = {}
local channels = {
  CHAT_MSG_SAY = {"say", "SAY"}, CHAT_MSG_YELL = {"yell", "YELL"},
  CHAT_MSG_PARTY = {"party", "PARTY"}, CHAT_MSG_PARTY_LEADER = {"party", "PARTY_LEADER"},
  CHAT_MSG_RAID = {"raid", "RAID"}, CHAT_MSG_RAID_LEADER = {"raid", "RAID_LEADER"},
  CHAT_MSG_RAID_WARNING = {"raid", "RAID_WARNING"},
  CHAT_MSG_BATTLEGROUND = {"battleground", "BATTLEGROUND"},
  CHAT_MSG_BATTLEGROUND_LEADER = {"battleground", "BATTLEGROUND_LEADER"},
  CHAT_MSG_INSTANCE_CHAT = {"instance", "INSTANCE_CHAT"},
  CHAT_MSG_INSTANCE_CHAT_LEADER = {"instance", "INSTANCE_CHAT_LEADER"},
  CHAT_MSG_GUILD = {"guild", "GUILD"}, CHAT_MSG_OFFICER = {"guild", "OFFICER"},
  CHAT_MSG_WHISPER = {"whisper", "WHISPER"},
  CHAT_MSG_WHISPER_INFORM = {"whisper", "WHISPER_INFORM"},
  CHAT_MSG_EMOTE = {"emote", "EMOTE"}, CHAT_MSG_TEXT_EMOTE = {"emote", "TEXT_EMOTE"},
  CHAT_MSG_MONSTER_SAY = {"npc", "MONSTER_SAY"},
  CHAT_MSG_MONSTER_YELL = {"npc", "MONSTER_YELL"},
  CHAT_MSG_MONSTER_EMOTE = {"npc", "MONSTER_EMOTE"},
  CHAT_MSG_MONSTER_WHISPER = {"npc", "MONSTER_WHISPER"},
  CHAT_MSG_MONSTER_PARTY = {"npc", "MONSTER_PARTY"},
  CHAT_MSG_RAID_BOSS_EMOTE = {"npc", "RAID_BOSS_EMOTE"},
  CHAT_MSG_RAID_BOSS_WHISPER = {"npc", "RAID_BOSS_WHISPER"},
}
local anchors = {
  RIGHT = {"LEFT", "RIGHT"}, LEFT = {"RIGHT", "LEFT"},
  TOP = {"BOTTOM", "TOP"}, BOTTOM = {"TOP", "BOTTOM"},
}
local strata = {BACKGROUND=true, LOW=true, MEDIUM=true, HIGH=true,
  DIALOG=true, FULLSCREEN=true, FULLSCREEN_DIALOG=true, TOOLTIP=true}

local function SpeakerKey(name)
  if type(name) ~= "string" then return nil end
  name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
  name = string.gsub(name, "|r", "")
  return string.lower(name)
end

local function SuppressDefaultBubbles(enabled)
  for _, cvar in pairs({"chatBubbles", "chatBubblesParty"}) do
    local ok, value = pcall(GetCVar, cvar)
    if ok and value ~= nil then
      if enabled then
        if previousCVars[cvar] == nil then previousCVars[cvar] = value end
        if value ~= "0" then pcall(SetCVar, cvar, "0") end
      elseif previousCVars[cvar] ~= nil then
        if value == "0" then pcall(SetCVar, cvar, previousCVars[cvar]) end
        previousCVars[cvar] = nil
      end
    end
  end
end

local function SuppressNativeBubbleFrames(enabled)
  -- CVars stop normal creation, but existing/extended-client bubbles and skins
  -- can still survive. Suppress their actual root frame, never change its skin.
  if not enabled then
    for frame, alpha in pairs(suppressedNative) do
      if frame:GetAlpha() == 0 then frame:SetAlpha(alpha) end
    end
    table.wipe(suppressedNative)
    return
  end
  if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
  local ok, frames = pcall(C_ChatBubbles.GetAllChatBubbles)
  if not ok or type(frames) ~= "table" then return end
  for _, frame in pairs(frames) do
    if frame and frame.GetAlpha and frame.SetAlpha then
      local alpha = frame:GetAlpha()
      if suppressedNative[frame] == nil then suppressedNative[frame] = alpha end
      if alpha ~= 0 then frame:SetAlpha(0) end
    end
  end
end

function Z.RefreshPlateChat()
  local C = Z.config and Z.config.platechat
  local enabled = C and C.enabled == "1"
  SuppressDefaultBubbles(enabled)
  SuppressNativeBubbleFrames(enabled)
  if not enabled then
    table.wipe(messages)
    for _, label in pairs(labels) do label:Hide() end
    for _, anchor in pairs(projectedAnchors) do anchor:Hide() end
    watcher:Hide()
  else
    watcher:Show()
    watcher.tick = nil
  end
end

local function PlayerForMessage(message)
  if message.category == "npc" then return nil end
  local key = SpeakerKey(message.sender)
  local function Matches(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    if SpeakerKey(UnitName(unit)) ~= key then return nil end
    local guid = UnitGUID and UnitGUID(unit)
    if message.guid and message.guid ~= guid then return nil end
    message.guid = message.guid or guid
    return unit
  end
  local unit = Matches(message.guid) or Matches("player") or Matches("target") or Matches("mouseover")
  if unit then return unit end
  for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
    unit = Matches("party" .. i)
    if unit then return unit end
  end
  for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do
    unit = Matches("raid" .. i)
    if unit then return unit end
  end
  if not message.guid and C_PlayerCache and C_PlayerCache.GetPlayerInfoByName then
    local ok, _, _, _, _, _, _, _, guid = pcall(C_PlayerCache.GetPlayerInfoByName, message.sender)
    if ok then return Matches(guid) end
  end
end

local function ProjectChatAnchor(message, index)
  if type(zAPI) ~= "function" then return nil end
  local unit = PlayerForMessage(message)
  if not unit then return nil end
  local ok, x, y, depth, wx, wy, wz = pcall(zAPI, "projectUnit", unit, .25)
  if not ok or type(x) ~= "number" or type(y) ~= "number" or type(depth) ~= "number"
      or depth <= 0 or x < 0 or x > 1 or y < 0 or y > 1 then return nil end

  local N = Z.config.nameplates
  local scale, alpha = 1, 1
  if (N.distance_scale == "1" or N.distance_alpha == "1")
      and type(wx) == "number" and type(wy) == "number" then
    local playerOk, px, py, pz = pcall(zAPI, "unitPosition", "player")
    local unitOk, ux, uy, uz = pcall(zAPI, "unitPosition", unit)
    if playerOk and unitOk and type(px) == "number" and type(py) == "number"
        and type(ux) == "number" and type(uy) == "number" then
      local dx, dy, dz = ux - px, uy - py, (uz or 0) - (pz or 0)
      local range = math.max(10, tonumber(N.nameplate_range) or 41)
      local progress = math.max(0, math.min(1, (math.sqrt(dx*dx + dy*dy + dz*dz) - 8) / (range - 8)))
      if N.distance_scale == "1" then
        scale = 1 - (1 - math.max(.2, math.min(1, (tonumber(N.distance_min_scale) or 58) / 100))) * progress
      end
      if N.distance_alpha == "1" then
        alpha = 1 - (1 - math.max(.2, math.min(1, (tonumber(N.distance_min_alpha) or 37) / 100))) * progress
      end
    end
  end

  local anchor = projectedAnchors[index]
  if not anchor then
    anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetWidth(1); anchor:SetHeight(1)
    anchor:EnableMouse(false)
    anchor.name = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    anchor.name:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    anchor.name:Hide()
    projectedAnchors[index] = anchor
  end
  anchor:SetFrameStrata("HIGH")
  anchor:SetFrameLevel(10)
  anchor:SetScale(scale)
  anchor:SetAlpha(alpha)
  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
    x * UIParent:GetWidth() / scale, y * UIParent:GetHeight() / scale)
  local friendly = UnitCanAssist and UnitCanAssist("player", unit)
  local size = tonumber(friendly and N.name.fontsize_friendly or N.name.fontsize) or 10
  local font = N.use_unitfonts == "1" and Z.font_unit or Z.font_default
  anchor.name:SetFont(font, size, "")
  anchor.name:SetText(message.sender)
  anchor:Show()
  return anchor
end

local function RoundedBackground(label, width, height, C)
  -- Vanilla has no texture masks: non-overlapping strips describe a four-pixel
  -- circular corner, keeping translucent edges the same shade as the centre.
  local radius = 4
  local r, g, b = Z.GetStringColor(C.background_color or ".04,.04,.04,1")
  local opacity = math.max(0, math.min(1, tonumber(C.background_opacity) or .35))
  for i = 1, 9 do
    local piece = label.background[i]
    local inset, top, stripHeight = 0, radius, height - radius * 2
    if i > 1 then
      local row = math.mod(i - 2, radius)
      local dy = radius - row - .5
      inset = radius - math.sqrt(radius * radius - dy * dy)
      top = i <= 5 and row or height - row - 1
      stripHeight = 1
    end
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", label, "TOPLEFT", inset, -top)
    piece:SetWidth(width - inset * 2)
    piece:SetHeight(stripHeight)
    piece:SetVertexColor(r or .04, g or .04, b or .04, opacity)
  end
end

local function RenderMessage(plate, message, now)
  local C = Z.config.platechat
  local label = labels[plate]
  if not label then
    label = CreateFrame("Frame", nil, plate)
    label:EnableMouse(false)
    label.text = label:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label.text:SetPoint("TOPLEFT", label, "TOPLEFT", 6, -4)
    if label.text.SetNonSpaceWrap then label.text:SetNonSpaceWrap(true) end
    label.background = {}
    for i = 1, 9 do
      label.background[i] = label:CreateTexture(nil, "BACKGROUND")
      label.background[i]:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    end
    labels[plate] = label
  end
  local layer = plate:GetFrameStrata()
  label:SetFrameStrata(strata[layer] and layer or "HIGH")
  label:SetFrameLevel(plate:GetFrameLevel() + 20)
  label:SetScale(tonumber(C.scale) or 1)
  local width = tonumber(C.width) or 220
  local size = tonumber(C.fontsize) or 12
  local font = Z.config.nameplates.use_unitfonts == "1" and Z.font_unit or Z.font_default
  local position = C.position or "RIGHT"
  local anchor = anchors[position] or anchors.RIGHT
  label:ClearAllPoints()
  label:SetPoint(anchor[1], plate.name, anchor[2],
    tonumber(C.x) or 6, tonumber(C.y) or 0)
  label.text:SetWidth(width)
  label.text:SetHeight(0)
  label.text:SetFont(font, size, C.fontstyle or "OUTLINE")
  label.text:SetJustifyH(position == "LEFT" and "RIGHT" or
    (position == "RIGHT" and "LEFT" or "CENTER"))
  label.text:SetJustifyV("MIDDLE")
  if label.message ~= message or label.position ~= position then
    label.text:SetText(message.text)
    label.message, label.position = message, position
  end
  -- Hug short messages instead of filling the configured maximum wrap width.
  local contentWidth = math.max(1, math.min(width, label.text:GetStringWidth()))
  label.text:SetWidth(contentWidth)
  local height = math.max(size, label.text:GetStringHeight()) + 8
  label:SetWidth(contentWidth + 12)
  label:SetHeight(height)
  RoundedBackground(label, contentWidth + 12, height, C)
  local color = ChatTypeInfo and ChatTypeInfo[message.channel]
  label.text:SetTextColor(color and color.r or 1, color and color.g or 1,
    color and color.b or 1, 1)
  local remaining = message.time + (tonumber(C.duration) or 8) - now
  local fade = math.min(tonumber(C.fade) or 1, tonumber(C.duration) or 8)
  label:SetAlpha((tonumber(C.opacity) or 1) *
    (fade > 0 and math.min(1, math.max(0, remaining / fade)) or 1))
  label:Show()
end

watcher:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    table.wipe(messages)
    Z.RefreshPlateChat()
    return
  end
  local C = Z.config and Z.config.platechat
  local channel = channels[event]
  if not C or C.enabled ~= "1" or not channel or C[channel[1]] ~= "1" then return end
  if type(arg1) ~= "string" or arg1 == "" then return end
  local speaker = event == "CHAT_MSG_WHISPER_INFORM" and UnitName("player") or arg2
  if channel[1] ~= "npc" and type(speaker) == "string" then
    -- Player names cannot contain hyphens; optional realm suffixes can.
    -- Do not alter hyphenated NPC names.
    speaker = string.gsub(speaker, "%-.*$", "")
  end
  local key = SpeakerKey(speaker)
  if not key then return end
  -- A GUID, when supplied by the client, is authoritative. Otherwise bind to
  -- a unique visible speaker and retain that GUID for the message's lifetime.
  local guid = type(arg12) == "string" and string.find(arg12, "^0[xX]%x+$") and arg12 or nil
  if not guid and GetCurrentChatGUID then
    local ok, senderGuid = pcall(GetCurrentChatGUID)
    if ok then guid = senderGuid end
  end
  if event == "CHAT_MSG_WHISPER_INFORM" then guid = UnitGUID and UnitGUID("player") end
  messages[key] = {text=arg1, sender=speaker, time=GetTime(), channel=channel[2], category=channel[1], guid=guid,
    emote=channel[1] == "emote" or channel[2] == "MONSTER_EMOTE" or channel[2] == "RAID_BOSS_EMOTE"}
end)

watcher:SetScript("OnUpdate", function()
  local C = Z.config and Z.config.platechat
  if not C or C.enabled ~= "1" then return end
  -- Run before the label throttle so duplicate native frames cannot flash
  -- between chat-label refreshes or wait for the half-second CVar check.
  SuppressNativeBubbleFrames(true)
  local now = GetTime()
  if this.tick and this.tick + .03 > now then return end
  this.tick = now
  if not this.cvarTick or this.cvarTick + .5 <= now then
    this.cvarTick = now
    SuppressDefaultBubbles(true)
  end
  for _, label in pairs(labels) do label:Hide() end
  for _, anchor in pairs(projectedAnchors) do anchor:Hide() end
  local projectedCount = 0
  local speakers = {}
  for parent in pairs(Z.nameplates and Z.nameplates.visiblePlates or {}) do
    local plate = parent.nameplate
    local unit = plate and (plate.unit or plate.cachedGuid)
    if parent:IsVisible() and plate and plate.name and plate.name:IsShown()
        and unit and UnitExists(unit) then
      local key = SpeakerKey(UnitName(unit))
      if key then
        local entry = speakers[key]
        if entry then entry.ambiguous = true
        else speakers[key] = {plate=plate, guid=UnitGUID and UnitGUID(unit)} end
      end
    end
  end
  for key, message in pairs(messages) do
    if C[message.category] ~= "1" or message.time + (tonumber(C.duration) or 8) <= now then
      messages[key] = nil
    else
      local speaker = speakers[key]
      if speaker and not speaker.ambiguous and
          (not message.guid or message.guid == speaker.guid) then
        message.guid = message.guid or speaker.guid
        RenderMessage(speaker.plate, message, now)
      elseif C.show_without_plate == "1" and not (speaker and speaker.ambiguous) then
        local anchor = ProjectChatAnchor(message, projectedCount + 1)
        if anchor then
          projectedCount = projectedCount + 1
          RenderMessage(anchor, message, now)
        end
      end
    end
  end
end)

for eventName in pairs(channels) do pcall(watcher.RegisterEvent, watcher, eventName) end
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:Hide()
