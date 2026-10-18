-- Chat labels follow the live speaker's plate and its distance scaling, but
-- never inherit plate fading. A borderless background adds no mouse input.
local Z = zNameplates
local watcher = CreateFrame("Frame", "zNameplatesChatWatcher")
local messages, labels, previousCVars = {}, {}, {}
local projectedAnchors = {}
local speakers, speakerPool = {}, {}
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

local function HideChatLabel(label)
  if label:IsShown() then label:Hide() end
  label.chatLayoutDirty = true
end

local function SetChatScale(frame, scale)
  if frame.chatAppliedScale ~= scale or math.abs(frame:GetScale() - scale) > .000001 then
    frame:SetScale(scale)
    frame.chatAppliedScale = scale
  end
end

local function SetChatAlpha(frame, alpha)
  -- The client quantizes alpha. Compare with the read-back value, not an
  -- unrepresentable requested fraction that would cause a write every tick.
  if frame.chatAppliedAlpha ~= alpha or frame:GetAlpha() ~= frame.chatActualAlpha then
    frame:SetAlpha(alpha)
    frame.chatAppliedAlpha, frame.chatActualAlpha = alpha, frame:GetAlpha()
  end
end

local function SetChatPoint(frame, point, relative, relativePoint, x, y)
  local relationship = frame.chatPointAnchor ~= point or frame.chatPointRelative ~= relative
    or frame.chatPointRelativeAnchor ~= relativePoint
  local coordinates = frame.chatPointX ~= x or frame.chatPointY ~= y
  if frame.GetPoint then
    local p, r, rp, px, py = frame:GetPoint(1)
    relationship = relationship or p ~= point or r ~= relative or rp ~= relativePoint
      or (frame.GetNumPoints and frame:GetNumPoints() ~= 1)
    coordinates = coordinates or not px or not py or math.abs(px-x) > .001 or math.abs(py-y) > .001
  end
  if relationship then frame:ClearAllPoints() end
  if relationship or coordinates then
    -- Replacing the same named anchor also updates moving projected positions;
    -- only a changed relationship needs ClearAllPoints.
    frame:SetPoint(point, relative, relativePoint, x, y)
    frame.chatPointAnchor, frame.chatPointRelative, frame.chatPointRelativeAnchor = point, relative, relativePoint
    frame.chatPointX, frame.chatPointY = x, y
  end
end

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
    for _, label in pairs(labels) do HideChatLabel(label) end
    for _, anchor in pairs(projectedAnchors) do HideChatLabel(anchor) end
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

local function IsOwnMessage(message)
  local guid = UnitGUID and UnitGUID("player")
  if message.guid and guid then return message.guid == guid end
  return SpeakerKey(message.sender) == SpeakerKey(UnitName("player"))
end

local function ProjectChatAnchor(message, index)
  if type(zAPI) ~= "function" then return nil end
  local unit = PlayerForMessage(message)
  if not unit then return nil end
  local ok, x, y, depth, wx, wy, wz
  if IsOwnMessage(message) then
    ok, x, y, depth, wx, wy, wz = pcall(zAPI, "projectNameplate", "player", .25)
  end
  if not ok or type(x) ~= "number" then
    ok, x, y, depth, wx, wy, wz = pcall(zAPI, "projectUnit", unit, .25)
  end
  if not ok or type(x) ~= "number" or type(y) ~= "number" or type(depth) ~= "number"
      or depth <= 0 or x < 0 or x > 1 or y < 0 or y > 1 then return nil end

  local N = Z.config.nameplates
  local scale = 1
  if N.distance_scale == "1"
      and type(wx) == "number" and type(wy) == "number" then
    local playerOk, px, py, pz = pcall(zAPI, "unitPosition", "player")
    local unitOk, ux, uy, uz = pcall(zAPI, "unitPosition", unit)
    if playerOk and unitOk and type(px) == "number" and type(py) == "number"
        and type(ux) == "number" and type(uy) == "number" then
      local dx, dy, dz = ux - px, uy - py, (uz or 0) - (pz or 0)
      local range = math.max(10, tonumber(N.nameplate_range) or 41)
      local progress = math.max(0, math.min(1, (math.sqrt(dx*dx + dy*dy + dz*dz) - 8) / (range - 8)))
      scale = 1 - (1 - math.max(.2, math.min(1, (tonumber(N.distance_min_scale) or 58) / 100))) * progress
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
    anchor.chatProjectionAnchor = true
    projectedAnchors[index] = anchor
  end
  if anchor:GetFrameStrata() ~= "HIGH" then anchor:SetFrameStrata("HIGH") end
  if anchor:GetFrameLevel() ~= 10 then anchor:SetFrameLevel(10) end
  SetChatScale(anchor, scale)
  SetChatAlpha(anchor, 1)
  SetChatPoint(anchor, "CENTER", UIParent, "BOTTOMLEFT",
    x * UIParent:GetWidth() / scale, y * UIParent:GetHeight() / scale)
  local friendly = UnitCanAssist and UnitCanAssist("player", unit)
  local size = tonumber(friendly and N.name.fontsize_friendly or N.name.fontsize) or 10
  local font = N.use_unitfonts == "1" and Z.font_unit or Z.font_default
  local fontChanged = anchor.chatNameObject ~= anchor.name or anchor.chatNameFont ~= font or anchor.chatNameSize ~= size
  if anchor.name.GetFont then
    local f, s, flags = anchor.name:GetFont()
    fontChanged = fontChanged or f ~= font or s ~= size or (flags or "") ~= ""
  end
  if fontChanged then
    anchor.name:SetFont(font, size, "")
    anchor.chatNameFont, anchor.chatNameSize = font, size
  end
  if anchor.chatNameObject ~= anchor.name or anchor.chatNameText ~= message.sender
      or (anchor.name.GetText and anchor.name:GetText() ~= message.sender) then
    anchor.name:SetText(message.sender)
    anchor.chatNameText = message.sender
  end
  anchor.chatNameObject = anchor.name
  if not anchor:IsShown() then anchor:Show() end
  return anchor
end

local function RoundedBackground(label, width, height, C, force)
  -- Vanilla has no texture masks: non-overlapping strips describe a four-pixel
  -- circular corner, keeping translucent edges the same shade as the centre.
  local radius = 4
  local color = C.background_color or ".04,.04,.04,1"
  local opacity = math.max(0, math.min(1, tonumber(C.background_opacity) or .35))
  local geometry = force or label.chatBackgroundWidth ~= width or label.chatBackgroundHeight ~= height
  local tint = force or label.chatBackgroundColor ~= color or label.chatBackgroundOpacity ~= opacity
  if not geometry and not tint then return end
  local r, g, b
  if tint then r, g, b = Z.GetStringColor(color) end
  for i = 1, 9 do
    local piece = label.background[i]
    if geometry then
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
    end
    if tint then piece:SetVertexColor(r or .04, g or .04, b or .04, opacity) end
  end
  label.chatBackgroundWidth, label.chatBackgroundHeight = width, height
  label.chatBackgroundColor, label.chatBackgroundOpacity = color, opacity
end

local function UpdateChatVisual(label)
  local plate = label.chatOwner
  -- Labels have an independent parent so alpha cannot leak in from the native
  -- plate or overlay. Explicitly keep their lifetime tied to that same owner.
  if not plate:IsVisible() or plate.worldPlacementHidden or plate.clusterHidden
      or label.ownerIdentity ~= (plate.cachedGuid or plate.unit) then
    HideChatLabel(label)
    return
  end
  local scale = plate:GetEffectiveScale() / UIParent:GetEffectiveScale() * label.chatScale
  SetChatScale(label, scale)
end

local function ChatOnUpdate()
  -- Only visible messages run this: no text work, unit lookups, or projection.
  -- Copy the owner's continuous scale every render, not at the content throttle.
  UpdateChatVisual(this)
end

local function HideChatWith(frame, label)
  if not frame then return end
  local owners = label.chatHideOwners
  if not owners then owners = setmetatable({}, {__mode="k"}); label.chatHideOwners = owners end
  if owners[frame] then return end
  owners[frame] = true
  local previousHide = frame:GetScript("OnHide")
  frame:SetScript("OnHide", function()
    -- An old native parent can disappear after this plate was reparented.
    if label.chatOwner == frame or label.chatOwner.parent == frame then HideChatLabel(label) end
    if previousHide then previousHide(frame) end
  end)
end

local function RenderMessage(plate, message, now)
  local C = Z.config.platechat
  local label = labels[plate]
  if not label then
    -- Vanilla has no SetIgnoreParentAlpha. A UIParent-owned label can retain
    -- its configured opacity even when its nameplate is completely faded.
    label = CreateFrame("Frame", nil, UIParent)
    label.chatOwner = plate
    label.chatLayoutDirty = true
    label:SetScript("OnUpdate", ChatOnUpdate)
    HideChatWith(plate, label)
    if not plate.chatProjectionAnchor then HideChatWith(plate.parent, label) end
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
    plate.chatLabel=label
    plate.layersDirty=true
  end
  local layer = plate:GetFrameStrata()
  layer = strata[layer] and layer or "HIGH"
  if label:GetFrameStrata() ~= layer then label:SetFrameStrata(layer) end
  -- Above this plate's text/badge, but inside its depth band so a farther
  -- speaker's bubble cannot jump in front of a genuinely nearer plate.
  local level = plate:GetFrameLevel() + 10
  if label:GetFrameLevel() ~= level then label:SetFrameLevel(level) end
  if label.GetParent and label:GetParent() ~= UIParent then
    label:SetParent(UIParent)
    label.chatLayoutDirty = true
  end
  if not plate.chatProjectionAnchor then HideChatWith(plate.parent, label) end
  label.chatScale = tonumber(C.scale) or 1
  label.ownerIdentity = plate.cachedGuid or plate.unit
  label.chatRenderSerial = watcher.chatRenderSerial
  if plate.chatProjectionAnchor then plate.chatRenderSerial = watcher.chatRenderSerial end
  local width = tonumber(C.width) or 220
  local size = tonumber(C.fontsize) or 12
  local font = Z.config.nameplates.use_unitfonts == "1" and Z.font_unit or Z.font_default
  local fontstyle = C.fontstyle or "OUTLINE"
  local position = C.position or "RIGHT"
  local ownOverhead = C.show_without_plate == "1" and IsOwnMessage(message)
  if ownOverhead then position = "TOP" end
  local anchor = anchors[position] or anchors.RIGHT
  SetChatPoint(label, anchor[1], plate.name, anchor[2],
    ownOverhead and 0 or tonumber(C.x) or 6, ownOverhead and 10 or tonumber(C.y) or 0)
  local fontChanged = label.chatTextObject ~= label.text or label.chatFont ~= font
    or label.chatFontSize ~= size or label.chatFontStyle ~= fontstyle
  if label.text.GetFont then
    local f, s, flags = label.text:GetFont()
    fontChanged = fontChanged or f ~= font or s ~= size or (flags or "") ~= fontstyle
  end
  local textChanged = label.chatTextObject ~= label.text or label.chatText ~= message.text
    or (label.text.GetText and label.text:GetText() ~= message.text)
  local layout = label.chatLayoutDirty or fontChanged or textChanged or label.chatWrapWidth ~= width
    or (label.chatWidth and math.abs(label:GetWidth()-label.chatWidth) > .001)
    or (label.chatHeight and math.abs(label:GetHeight()-label.chatHeight) > .001)
  if layout then
    label.text:SetWidth(width)
    label.text:SetHeight(0)
    if fontChanged then label.text:SetFont(font, size, fontstyle) end
    if textChanged then label.text:SetText(message.text) end
    -- Hug short messages; recompute wrapping only after a content/font change.
    local contentWidth = math.max(1, math.min(width, label.text:GetStringWidth()))
    label.text:SetWidth(contentWidth)
    local height = math.max(size, label.text:GetStringHeight()) + 8
    label:SetWidth(contentWidth + 12)
    label:SetHeight(height)
    label.chatWidth, label.chatHeight = contentWidth + 12, height
    label.chatFont, label.chatFontSize, label.chatFontStyle = font, size, fontstyle
    label.chatWrapWidth, label.chatTextObject, label.chatText = width, label.text, message.text
  end
  local justify = position == "LEFT" and "RIGHT" or (position == "RIGHT" and "LEFT" or "CENTER")
  if label.chatLayoutDirty or label.chatJustify ~= justify then
    label.text:SetJustifyH(justify)
    label.text:SetJustifyV("MIDDLE")
    label.chatJustify = justify
  end
  label.message, label.position = message, position
  RoundedBackground(label, label.chatWidth, label.chatHeight, C, label.chatLayoutDirty)
  local color = ChatTypeInfo and ChatTypeInfo[message.channel]
  local r, g, b = color and color.r or 1, color and color.g or 1, color and color.b or 1
  local recolor = label.chatLayoutDirty or label.chatColorObject ~= label.text
    or label.chatR ~= r or label.chatG ~= g or label.chatB ~= b
  if label.text.GetTextColor then
    local ar, ag, ab, aa = label.text:GetTextColor()
    recolor = recolor or ar ~= label.chatActualR or ag ~= label.chatActualG
      or ab ~= label.chatActualB or aa ~= label.chatActualA
  end
  if recolor then
    label.text:SetTextColor(r, g, b, 1)
    label.chatColorObject, label.chatR, label.chatG, label.chatB = label.text, r, g, b
    if label.text.GetTextColor then
      label.chatActualR, label.chatActualG, label.chatActualB, label.chatActualA = label.text:GetTextColor()
    end
  end
  label.chatLayoutDirty = nil
  local remaining = message.time + (tonumber(C.duration) or 8) - now
  local fade = math.min(tonumber(C.fade) or 1, tonumber(C.duration) or 8)
  SetChatAlpha(label, (tonumber(C.opacity) or 1) *
    (fade > 0 and math.min(1, math.max(0, remaining / fade)) or 1))
  if not label:IsShown() then label:Show() end
  UpdateChatVisual(label)
end

local function HideUnusedChat(serial)
  for _, label in pairs(labels) do
    if label.chatRenderSerial ~= serial then HideChatLabel(label) end
  end
  for _, anchor in pairs(projectedAnchors) do
    if anchor.chatRenderSerial ~= serial then HideChatLabel(anchor) end
  end
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
  this.chatRenderSerial = (this.chatRenderSerial or 0) + 1
  if not next(messages) then HideUnusedChat(this.chatRenderSerial); return end
  local projectedCount = 0
  table.wipe(speakers)
  local speakerCount = 0
  for parent in pairs(Z.nameplates and Z.nameplates.visiblePlates or {}) do
    local plate = parent.nameplate
    local unit = plate and (plate.unit or plate.cachedGuid)
    if parent:IsVisible() and plate and plate:IsVisible() and plate.name and plate.name:IsShown()
        and not plate.worldPlacementHidden and not plate.clusterHidden
        and unit and UnitExists(unit) then
      local key = SpeakerKey(UnitName(unit))
      if key then
        local entry = speakers[key]
        if entry then entry.ambiguous = true
        else
          speakerCount = speakerCount + 1
          entry = speakerPool[speakerCount]
          if not entry then entry = {}; speakerPool[speakerCount] = entry end
          entry.plate, entry.guid, entry.ambiguous = plate, UnitGUID and UnitGUID(unit), nil
          speakers[key] = entry
        end
      end
    end
  end
  for key, message in pairs(messages) do
    if C[message.category] ~= "1" or message.time + (tonumber(C.duration) or 8) <= now then
      messages[key] = nil
    else
      local speaker = speakers[key]
      if C.show_without_plate == "1" and IsOwnMessage(message) then
        -- Self speech belongs over the character, never beside a displaced
        -- self plate or at the general chat label's horizontal offset.
        local anchor = ProjectChatAnchor(message, projectedCount + 1)
        if anchor then
          projectedCount = projectedCount + 1
          RenderMessage(anchor, message, now)
        end
      elseif speaker and not speaker.ambiguous and
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
  HideUnusedChat(this.chatRenderSerial)
end)

for eventName in pairs(channels) do pcall(watcher.RegisterEvent, watcher, eventName) end
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:Hide()
