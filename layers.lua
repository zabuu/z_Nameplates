-- Explicit, parent-first ordering; only write native layer state when needed.
local Z = zNameplates
local function Layer(frame, strata, level)
  if not frame then return end
  if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
  if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
  local backdrop = frame.backdrop
  if backdrop then
    if backdrop:GetFrameStrata() ~= strata then backdrop:SetFrameStrata(strata) end
    local behind = math.max(0, level - 1)
    if backdrop:GetFrameLevel() ~= behind then backdrop:SetFrameLevel(behind) end
  end
end

local function FontSurface(text, strata, level)
  if text and text.zSmoothFrame then Layer(text.zSmoothFrame, strata, level) end
end

function Z.RepairPlateTextLayers(plate)
  if not plate.health then return end
  local strata, level = plate.health:GetFrameStrata(), plate.health:GetFrameLevel()
  local backdrop = plate.health.backdrop
  if backdrop then Layer(backdrop, strata, math.max(0, level - 1)) end
  if plate.textframe then
    Layer(plate.textframe, strata, level + 5)
    -- The high-resolution font surfaces are extra frames in our version.
    -- Keep them explicitly above their text owner rather than relying on
    -- automatic child-level inheritance when strata or parents change.
    FontSurface(plate.name, strata, level + 6)
    FontSurface(plate.guild, strata, level + 6)
    FontSurface(plate.level, strata, level + 6)
  end
end

function Z.ApplyPlateLayers(plate, strata, base)
  if not plate then return end
  Layer(plate.parent, strata, base)
  Layer(plate, strata, base + 1)
  Layer(plate.health, strata, base + 3)
  Layer(plate.totem, strata, base + 4)
  Layer(plate.castbar, strata, base + 4)
  if plate.castbar then Layer(plate.castbar.icon, strata, base + 5) end
  if plate.debuffs then
    for i = 1, 16 do
      local aura = plate.debuffs[i]
      if aura then
        Layer(aura, strata, base + 4)
        Layer(aura.cd, strata, base + 5)
      end
    end
  end
  if plate.combopoints then
    for i = 1, 5 do Layer(plate.combopoints[i], strata, base + 6) end
  end
  Layer(plate.raidiconframe, strata, base + 7)
  Layer(plate.textframe, strata, base + 8)
  Layer(plate.clusterCountFrame, strata, base + 10)
  Z.RepairPlateTextLayers(plate)
  plate.cachedStrata, plate.cachedBaseLevel = strata, base
end

SLASH_ZNPDUMP1 = "/znpdump"
SlashCmdList.ZNPDUMP = function()
  local function Say(message) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccznpdump:|r " .. message) end
  local unit = UnitExists("mouseover") and "mouseover" or "target"
  if not UnitExists(unit) then Say("No mouseover or target unit."); return end
  local native = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
  local plate = native and native.nameplate
  -- Some clients only expose the nameplateN token to this lookup.
  if not plate and Z.nameplates then
    local guid = UnitGUID(unit)
    for parent in pairs(Z.nameplates.visiblePlates) do
      if guid and parent.nameplate and parent.nameplate.cachedGuid == guid then plate = parent.nameplate; break end
    end
  end
  if not plate then Say("No plate found for " .. unit); return end
  Say(tostring(UnitName(unit)) .. " [" .. tostring(plate.cachedGuid) .. "] " .. unit)
  local function Describe(label, frame)
    if not frame then Say(label .. ": missing"); return end
    local status = label .. ": shown=" .. tostring(frame:IsShown()) .. " visible=" .. tostring(frame:IsVisible())
      .. " alpha=" .. tostring(frame:GetAlpha())
    if frame.GetFrameStrata then
      status = status .. " strata=" .. frame:GetFrameStrata() .. " level=" .. frame:GetFrameLevel()
    end
    if frame.GetWidth then status = status .. " size=" .. tostring(frame:GetWidth()) .. "x" .. tostring(frame:GetHeight()) end
    if frame.GetValue then
      local minimum, maximum = frame:GetMinMaxValues()
      status = status .. " value=" .. tostring(frame:GetValue()) .. " range=" .. tostring(minimum) .. ".." .. tostring(maximum)
    end
    Say(status)
  end
  Describe("native", plate.parent)
  Describe("plate", plate)
  Describe("health", plate.health)
  Describe("native health", plate.original and plate.original.healthbar)
  Describe("backdrop", plate.health and plate.health.backdrop)
  Describe("text layer", plate.textframe)
  Describe("name surface", plate.name and plate.name.zSmoothFrame)
  if plate.health and plate.health.GetStatusBarTexture then
    local texture = plate.health:GetStatusBarTexture()
    if texture and texture.GetAlpha then Describe("fill", texture) else Say("fill: " .. tostring(texture)) end
  end
  Say("depth=" .. tostring(plate.depth) .. " scale=" .. tostring(plate.distanceScale)
    .. " clustered=" .. tostring(plate.clusterHidden) .. " cached layers=" .. tostring(plate.cachedStrata)
    .. "/" .. tostring(plate.cachedBaseLevel))
end
