-- Live, in-world-style nameplate preview used to test plate overlap and
-- zDNumbers without requiring a pack of real enemies.

local Z = zNameplates
local cluster
local plates = {}
local RefreshCluster

local archetypes = {
  { name="Dummy Vanguard", level="60", health=92, class="WARRIOR", state="tagged" },
  { name="Dummy Arcanist", level="59", health=71, class="MAGE", state="threat", cast=true },
  { name="Dummy Cutpurse", level="58", health=54, class="ROGUE", state="nothreat", raid=true },
  { name="Dummy Stalker", level="57", health=36, class="HUNTER", state="stun" },
  { name="Dummy Warlock", level="56", health=18, class="WARLOCK", state="target" },
}

local function SampleForIndex(index)
  local source = archetypes[math.mod(index - 1, table.getn(archetypes)) + 1]
  return {
    name = source.name .. (index > table.getn(archetypes) and " " .. index or ""),
    level = tostring(math.max(1, 61 - math.mod(index, 12))),
    health = math.max(8, 100 - math.mod(index * 17, 91)),
    class = source.class,
    state = source.state,
    cast = source.cast,
    raid = source.raid,
  }
end

local function StableWorldOffset(index)
  -- A golden-angle layout reads as random without changing whenever the GUI
  -- refreshes. Keep every dummy between one and five yards from the shared
  -- test origin so the cluster remains compact and reproducible.
  local angle = math.rad(math.mod(index * 137.508 + 41, 360))
  local radius = 1 + math.mod(index * 173 + 67, 401) / 100
  return math.cos(angle) * radius, math.sin(angle) * radius
end

local function Message(text, bad)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(text, bad and 1 or .35, bad and .25 or 1, bad and .25 or .45, 1)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("zNameplates: " .. text)
  end
end

local function SetFont(text, font, size, style)
  if Z.SetSmoothFontString then Z.SetSmoothFontString(text, font, size, style)
  else text:SetFont(font, size, style or "") end
end

local function CreateDummy(index)
  local base = CreateFrame("Frame", nil, cluster)
  base:SetFrameStrata("BACKGROUND")
  base:SetFrameLevel(10 + index * 3)
  base.worldOffsetX, base.worldOffsetY = StableWorldOffset(index)

  local plate = CreateFrame("Frame", nil, base)
  plate:SetAllPoints(base)
  plate:SetFrameLevel(base:GetFrameLevel() + 1)
  plate.isDummy = true
  plate.sample = SampleForIndex(index)
  base.nameplate = plate

  plate.health = CreateFrame("StatusBar", nil, plate)
  plate.health:SetFrameLevel(plate:GetFrameLevel() + 1)
  plate.health:SetMinMaxValues(0, 100)
  plate.health:SetValue(plate.sample.health)
  plate.health.text = plate.health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plate.health.text:SetAllPoints(plate.health)

  plate.name = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plate.name:SetText(plate.sample.name)
  plate.level = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plate.level:SetText(plate.sample.level)
  plate.guild = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plate.guild:SetText("<Dummy Guild>")

  plate.glow = plate:CreateTexture(nil, "BACKGROUND")
  plate.glow:SetTexture(Z.media["img:dot"] or "Interface\\BUTTONS\\WHITE8X8")
  plate.glow:Hide()

  plate.castbar = CreateFrame("StatusBar", nil, plate)
  plate.castbar:SetFrameLevel(plate:GetFrameLevel() + 2)
  plate.castbar:SetMinMaxValues(0, 100)
  plate.castbar:SetValue(63)
  plate.castbar.spell = plate.castbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plate.castbar.spell:SetAllPoints(plate.castbar)
  plate.castbar.spell:SetText("Dummy Cast")
  plate.castbar:Hide()

  plate.raidicon = plate:CreateTexture(nil, "OVERLAY")
  plate.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  plate.raidicon:SetTexCoord(.75, 1, .5, 1)
  plate.raidicon:SetAlpha(.45)
  plate.raidicon:Hide()

  plates[index] = base
  return base
end

local function BorderColor(sample)
  local C = Z.config.nameplates
  if sample.state == "tagged" then return .35, 1, .05, .75 end
  if sample.state == "target" and C.targethighlight == "1" then
    return Z.GetStringColor(C.highlightcolor)
  end
  if sample.state == "threat" and C.outcombatstate == "1" and C.ccombatthreat == "1" then
    return Z.GetStringColor(C.combatthreat)
  end
  if sample.state == "nothreat" and C.outcombatstate == "1" and C.ccombatnothreat == "1" then
    return Z.GetStringColor(C.combatnothreat)
  end
  if sample.state == "stun" and C.outcombatstate == "1" and C.ccombatstun == "1" then
    return Z.GetStringColor(C.combatstun)
  end
  if C.outenemy == "1" then return 1, .1, .1, 1 end
  return Z.GetStringColor(Z.config.appearance.border.color)
end

local function RefreshDummy(base, index)
  local C = Z.config.nameplates
  local plate = base.nameplate
  local sample = plate.sample
  local font = C.use_unitfonts == "1" and Z.font_unit or Z.font_default
  local fontSize = tonumber(C.name.fontsize) or tonumber(Z.config.global.font_unit_size) or 10
  local fontStyle = C.name.fontstyle or ""
  local width = tonumber(C.width) or 120
  local barHeight = tonumber(C.heighthealth) or 8
  local healthOffset = tonumber(C.health.offset) or -3
  local totalHeight = math.max(24, fontSize * 2 + barHeight + 8)

  base:SetSize(width + 70, totalHeight)
  plate:SetAllPoints(base)

  plate.health:ClearAllPoints()
  plate.health:SetPoint("CENTER", plate, "CENTER", 0, -2)
  plate.health:SetSize(width, barHeight)
  plate.health:SetOrientation(C.verticalhealth == "1" and "VERTICAL" or "HORIZONTAL")
  plate.health:SetStatusBarTexture(Z.media[C.healthtexture] or C.healthtexture)
  plate.health:SetStatusBarColor(.72, .12, .12, 1)
  local _, nameplateBorder = Z.GetBorderSize("nameplates")
  Z.CreateBackdrop(plate.health, nameplateBorder)
  if plate.health.backdrop then
    plate.health.backdrop:SetBackdropBorderColor(BorderColor(sample))
  end

  plate.name:ClearAllPoints()
  local align = C.nametextpos or "CENTER"
  local point = align == "LEFT" and "BOTTOMLEFT" or align == "RIGHT" and "BOTTOMRIGHT" or "BOTTOM"
  local relative = align == "LEFT" and "TOPLEFT" or align == "RIGHT" and "TOPRIGHT" or "TOP"
  plate.name:SetPoint(point, plate.health, relative, 0, -healthOffset)
  plate.name:SetJustifyH(align)
  SetFont(plate.name, font, fontSize, fontStyle)
  local nr, ng, nb, na = Z.GetStringColor(C.enemynamecolor)
  if C.enemyclassc == "1" then
    local classColor = Z.classColors[sample.class]
    nr, ng, nb, na = classColor.r, classColor.g, classColor.b, classColor.a
  end
  if C.namefightcolor == "1" and sample.state == "threat" then nr, ng, nb, na = 1, .4, .2, 1 end
  plate.name:SetTextColor(nr, ng, nb, na)

  plate.level:ClearAllPoints()
  plate.level:SetPoint("RIGHT", plate.health, "LEFT", -3, 0)
  SetFont(plate.level, font, fontSize, fontStyle)
  plate.level:SetTextColor(1, .82, .2, 1)

  plate.guild:ClearAllPoints()
  plate.guild:SetPoint("TOP", plate.health, "BOTTOM", 0, -2)
  SetFont(plate.guild, font, math.max(7, fontSize - 1), fontStyle)
  plate.guild:SetTextColor(.75, .75, .75, .9)
  plate.guild:SetShown(C.showguildname == "1")

  SetFont(plate.health.text, font, math.max(7, fontSize - 2), "OUTLINE")
  plate.health.text:SetJustifyH(C.hptextpos or "RIGHT")
  plate.health.text:SetText(sample.health .. "%")
  plate.health.text:SetShown(C.showhp == "1")
  local hideHealth = C.enemynpc == "1" and not (sample.state == "target" and C.target == "1")
  plate.health:SetShown(not hideHealth)

  plate.glow:ClearAllPoints()
  plate.glow:SetPoint("CENTER", plate.health, "CENTER", 0, 0)
  plate.glow:SetSize(width + 60, barHeight + 30)
  plate.glow:SetVertexColor(Z.GetStringColor(C.glowcolor))
  plate.glow:SetShown(sample.state == "target" and C.targetglow == "1")

  plate.castbar:ClearAllPoints()
  plate.castbar:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", 0, -4)
  plate.castbar:SetPoint("TOPRIGHT", plate.health, "BOTTOMRIGHT", 0, -4)
  plate.castbar:SetHeight(tonumber(C.heightcast) or 8)
  plate.castbar:SetStatusBarTexture(Z.media[Z.config.appearance.castbar.texture]
    or Z.config.appearance.castbar.texture)
  plate.castbar:SetStatusBarColor(Z.GetStringColor(Z.config.appearance.castbar.castbarcolor))
  Z.CreateBackdrop(plate.castbar)
  SetFont(plate.castbar.spell, font, math.max(7, fontSize - 1), "OUTLINE")
  plate.castbar:SetShown(sample.cast and C.showcastbar == "1" and C.targetcastbar ~= "1")

  plate.raidicon:ClearAllPoints()
  plate.raidicon:SetPoint("BOTTOM", plate.health, "TOP",
    tonumber(C.raidiconoffx) or 0, tonumber(C.raidiconoffy) or -5)
  plate.raidicon:SetSize(tonumber(C.raidiconsize) or 16, tonumber(C.raidiconsize) or 16)
  plate.raidicon:SetShown(sample.raid)

  -- Every preview plate represents a unit at the same world point. Use one
  -- shared midpoint distance so scaling/opacity settings remain visible while
  -- preserving identical perspective across the whole cluster.
  local progress = .5
  local scale = 1
  if C.distance_scale == "1" then
    local minimum = math.max(.2, math.min(1, (tonumber(C.distance_min_scale) or 60) / 100))
    scale = 1 - (1 - minimum) * progress
  end
  if sample.state == "target" and C.targetzoom == "1" then
    scale = scale * (1 + (tonumber(C.targetzoomval) or .4))
  end
  base:SetScale(scale)
  local alpha = sample.state == "target" and 1 or (tonumber(C.notargalpha) or .75)
  if C.distance_alpha == "1" then
    local minimum = math.max(.2, math.min(1, (tonumber(C.distance_min_alpha) or 40) / 100))
    alpha = math.min(alpha, 1 - (1 - minimum) * progress)
  end
  base:SetAlpha(alpha)
  base.previewAlpha = alpha
  base.previewScale = scale
  base.previewHeight = totalHeight * scale
end

local function PositionDummies()
  local C = Z.config.nameplates
  local overlap = C.overlap_enemy == "1"
  local count = cluster.activeCount or 1
  local step = overlap and 7 or 34
  local total = (count - 1) * step
  for i = 1, count do
    local base = plates[i]
    base:ClearAllPoints()
    local x = overlap and (i - 1) * 4 or 0
    base:SetPoint("CENTER", cluster.origin, "CENTER", x, total * .5 - (i - 1) * step)
  end
end

local function ActivePlates()
  local active = {}
  local count = cluster and cluster.activeCount or 0
  for i = 1, count do active[i] = plates[i] end
  return active
end

local function SetDummyCount(count)
  count = math.max(1, math.min(30, math.floor((tonumber(count) or 5) + .5)))
  while table.getn(plates) < count do CreateDummy(table.getn(plates) + 1) end
  local previous = cluster.activeCount or 0
  if count < previous and zDNumbers and zDNumbers.HideDummyDamage then
    local removed = {}
    for i = count + 1, previous do removed[table.getn(removed) + 1] = plates[i] end
    zDNumbers.HideDummyDamage(removed)
  end
  cluster.activeCount = count
  for i = 1, table.getn(plates) do plates[i]:SetShown(i <= count) end
end

local function CaptureWorldAnchor(self)
  self.worldX, self.worldY, self.worldZ = nil, nil, nil
  self.worldOffsetX, self.worldOffsetY, self.worldOffsetZ = nil, nil, nil
  if type(zAPI) ~= "function" then return end
  local ok, cx, cy, cz, fx, fy, fz, rx, ry, rz = pcall(zAPI, "camera")
  if not ok or type(cx) ~= "number" or type(cy) ~= "number" or type(cz) ~= "number"
      or type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number"
      or type(rx) ~= "number" or type(ry) ~= "number" or type(rz) ~= "number" then return end

  -- Lock one shared point into the world in front of and slightly left of the
  -- current camera. It starts beside the settings window, then behaves like a
  -- real cluster as the player pans, pitches, zooms, or moves the camera.
  self.worldX = cx + fx * 25 - rx * 11
  self.worldY = cy + fy * 25 - ry * 11
  self.worldZ = cz + fz * 25 - rz * 11
  self.worldReferenceDepth = 25
  local playerOk, px, py, pz = pcall(zAPI, "unitPosition", "player")
  if playerOk and type(px) == "number" and type(py) == "number" and type(pz) == "number" then
    self.worldOffsetX = self.worldX - px
    self.worldOffsetY = self.worldY - py
    self.worldOffsetZ = self.worldZ - pz
  end
end

local function UpdateCameraAnchor(self, elapsed)
  if not self.worldX or type(zAPI) ~= "function" then return end
  self.cameraTick = (self.cameraTick or 0) + (elapsed or 0)
  if self.cameraTick < .01 then return end
  self.cameraTick = 0

  if self.worldOffsetX then
    local playerOk, px, py, pz = pcall(zAPI, "unitPosition", "player")
    if playerOk and type(px) == "number" and type(py) == "number" and type(pz) == "number" then
      self.worldX = px + self.worldOffsetX
      self.worldY = py + self.worldOffsetY
      self.worldZ = pz + self.worldOffsetZ
    end
  end

  local ok, x, y, depth = pcall(zAPI, "worldToScreen", self.worldX, self.worldY, self.worldZ)
  if ok and type(x) == "number" and type(y) == "number"
      and type(depth) == "number" and depth > 0 then
    local parentWidth, parentHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local clusterScale = math.max(.35, math.min(2, (self.worldReferenceDepth or 25) / depth))
    self:SetAlpha(1)
    self:SetScale(clusterScale)
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
      x * parentWidth, y * parentHeight)

    -- Project every dummy's stable X/Y world offset separately. The
    -- difference from the shared origin is converted back into the cluster's
    -- local coordinates so the formation changes naturally with camera yaw,
    -- pitch, and zoom instead of behaving like a flat screen-space stack.
    for i = 1, (self.activeCount or 0) do
      local base = plates[i]
      local plateOk, plateX, plateY, plateDepth = pcall(zAPI, "worldToScreen",
        self.worldX + (base.worldOffsetX or 0),
        self.worldY + (base.worldOffsetY or 0), self.worldZ)
      if plateOk and type(plateX) == "number" and type(plateY) == "number"
          and type(plateDepth) == "number" and plateDepth > 0 then
        base:ClearAllPoints()
        base:SetPoint("CENTER", self.origin, "CENTER",
          (plateX - x) * parentWidth / clusterScale,
          (plateY - y) * parentHeight / clusterScale)
        base:SetScale((base.previewScale or 1) * depth / plateDepth)
        base:SetAlpha(base.previewAlpha or 1)
      else
        base:SetAlpha(0)
      end
    end
  else
    -- Keep the frame alive so OnUpdate continues and it reappears naturally
    -- when the camera turns back toward the locked world point.
    self:SetAlpha(0)
  end
end

function Z.StartDummyCluster()
  if cluster then RefreshCluster(cluster); return end

  cluster = CreateFrame("Frame", "zNameplatesDummyCluster", UIParent)
  cluster:SetFrameStrata("BACKGROUND")
  cluster:SetFrameLevel(8)
  cluster:SetSize(300, 260)
  cluster:SetPoint("CENTER", UIParent, "CENTER",
    tonumber(Z.config.nameplates.dummy_x) or -500,
    tonumber(Z.config.nameplates.dummy_y) or 120)
  cluster:SetMovable(true)
  cluster:EnableMouse(true)
  cluster:RegisterForDrag("LeftButton")
  if cluster.SetClampedToScreen then cluster:SetClampedToScreen(false) end
  cluster:SetScript("OnDragStart", function()
    -- Dragging remains available as a fallback on clients without zAPI. A
    -- projected point must stay world-locked or dragging and camera motion
    -- would fight over the same frame anchors.
    if this.worldX then return end
    this.dummyDragging = true
    this:StartMoving()
  end)
  cluster:SetScript("OnDragStop", function()
    if not this.dummyDragging then return end
    this.dummyDragging = nil
    this:StopMovingOrSizing()
    local x, y = this:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    x, y = (x or parentX) - parentX, (y or parentY) - parentY
    this:ClearAllPoints()
    this:SetPoint("CENTER", UIParent, "CENTER", x, y)
    Z.config.nameplates.dummy_x = tostring(x)
    Z.config.nameplates.dummy_y = tostring(y)
  end)
  cluster:RegisterEvent("PLAYER_ENTERING_WORLD")
  cluster:SetScript("OnEvent", function()
    this.worldX, this.worldY, this.worldZ = nil, nil, nil
    this.worldOffsetX, this.worldOffsetY, this.worldOffsetZ = nil, nil, nil
    this.recaptureAt = GetTime() + .5
  end)
  cluster:SetScript("OnUpdate", function()
    if this.recaptureAt and GetTime() >= this.recaptureAt then
      this.recaptureAt = nil
      RefreshCluster(this)
    end
    UpdateCameraAnchor(this, arg1)
  end)

  cluster.origin = CreateFrame("Frame", nil, cluster)
  cluster.origin:SetPoint("CENTER", cluster, "CENTER", 0, 0)
  cluster.origin:SetSize(4, 4)
  cluster.origin.dot = cluster.origin:CreateTexture(nil, "BACKGROUND")
  cluster.origin.dot:SetAllPoints(cluster.origin)
  cluster.origin.dot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  cluster.origin.dot:SetVertexColor(1, .75, .1, .7)

  cluster.hint = cluster:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cluster.hint:SetPoint("BOTTOM", cluster, "BOTTOM", 0, 2)
  cluster.hint:SetText("Dummy cluster - drag to move")
  cluster.hint:SetTextColor(1, .82, .25, .55)

  SetDummyCount(Z.config.nameplates.dummy_count)
  Z.dummyCluster = cluster
  cluster.Refresh = RefreshCluster
  RefreshCluster(cluster)
end

RefreshCluster = function(self)
  if not Z.config or not Z.config.nameplates then return end
  if Z.config.nameplates.dummy_preview ~= "1" then
    self:Hide()
    if zDNumbers and zDNumbers.HideDummyDamage then zDNumbers.HideDummyDamage(plates) end
    self.worldX, self.worldY, self.worldZ, self.worldReferenceDepth = nil, nil, nil, nil
    self.worldOffsetX, self.worldOffsetY, self.worldOffsetZ = nil, nil, nil
    self.recaptureAt = nil
    self:SetScale(1)
    return
  end
  SetDummyCount(Z.config.nameplates.dummy_count)
  for i = 1, self.activeCount do RefreshDummy(plates[i], i) end
  PositionDummies()
  if not self.worldX then CaptureWorldAnchor(self) end
  if self.worldX then
    self:EnableMouse(false)
    self.hint:SetText("Camera-locked dummy cluster")
  else
    self:EnableMouse(true)
    self:SetAlpha(1)
    self:SetScale(1)
    self.hint:SetText("Dummy cluster - drag to move")
  end
  self:Show()
end

function Z.PulseDummyDamage()
  if not cluster or not cluster:IsShown() then
    Message("Enable the dummy nameplate cluster first.", true)
    return
  end
  if not zDNumbers or not zDNumbers.PulseDummyDamage then
    Message("zDNumbers is not loaded.", true)
    return
  end
  local ok, reason = zDNumbers.PulseDummyDamage(ActivePlates())
  if not ok then Message(reason or "Unable to pulse dummy damage.", true) end
end
