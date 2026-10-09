-- Crowded-scene aggregation keeps real native unit frames for exact clicking.
local Z = zNameplates
local groups, assignments = {}, {}
local nextUpdate, previousActive

local function Health(plate)
  local unit = plate.unit
  if not unit or not UnitExists(unit) then return end
  if plate.cachedGuid and UnitGUID(unit) ~= plate.cachedGuid then return end
  local hp, maximum = UnitHealth(unit), UnitHealthMax(unit)
  if not hp or not maximum or maximum <= 0 then
    local bar = plate.original and plate.original.healthbar
    if not bar or not bar.GetValue or not bar.GetMinMaxValues then return end
    local minimum
    minimum, maximum = bar:GetMinMaxValues()
    hp = bar:GetValue() - minimum
    maximum = maximum - minimum
  end
  if hp <= 0 or maximum <= 0 then return end
  return hp / maximum * 100, hp
end

function Z.RenderPlateCluster(plate)
  local group = plate.clusterGroup
  if not group or group.anchor ~= plate then return end
  -- A sibling badge does not inherit the overlay's distance fade/shrink.
  -- Native-parent ownership still hides it immediately with the actual unit.
  local badge = plate.clusterCountFrame
  if not badge then
    badge = CreateFrame("Frame", nil, plate.parent)
    badge:SetWidth(1); badge:SetHeight(1)
    badge:EnableMouse(false)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badge.text:SetShadowColor(0, 0, 0, 1)
    badge.text:SetShadowOffset(1, -1)
    badge.text:SetPoint("LEFT", plate.name, "RIGHT", 5, 0)
    plate.clusterCountFrame = badge
  end
  local uiScale = UIParent:GetEffectiveScale()
  local parentScale = plate.parent:GetEffectiveScale()
  badge:SetScale(uiScale / math.max(.001, parentScale))
  badge:SetFrameStrata(plate:GetFrameStrata())
  badge:SetFrameLevel(plate:GetFrameLevel() + 9)
  badge:Show()
  if not plate.clusterRenderDirty and plate.clusterRenderGroup == group
      and plate.clusterRenderCount == group.count and plate.clusterRenderAverage == group.average then return end
  plate.clusterRenderDirty = nil
  plate.clusterRenderGroup, plate.clusterRenderCount, plate.clusterRenderAverage = group, group.count, group.average
  plate.name:SetText(group.name)
  local C = Z.config
  local r, g, b, a = Z.GetStringColor(C.nameplates.cluster_count_color or "1,.92,.15,1")
  badge.text:SetTextColor(r, g, b, a)
  local font = plate.name:GetFont()
  local baseSize = tonumber(C.nameplates.name and C.nameplates.name.fontsize)
    or tonumber(C.global and C.global.font_unit_size) or 12
  badge.text:SetFont(font or Z.font_unit or Z.font_default,
    math.max(14, baseSize * (tonumber(C.nameplates.cluster_count_scale) or 1.6)), "THICKOUTLINE")
  badge.text:SetText("x" .. group.count)
  plate.health:Show()
  plate.health:SetMinMaxValues(0, 100)
  plate.health:SetValue(group.average)
  plate.health.text:SetText(string.format("%.0f%%", group.average))
  -- A representative's auras/cast do not describe the other members.
  if plate.castbar then plate.castbar:Hide(); plate.castbar.isShown = nil end
  if plate.debuffs then for _, aura in pairs(plate.debuffs) do aura:Hide() end end
end

function Z.GetPlateClickMember(plate)
  local group = plate.clusterGroup
  if group then
    local lowest, lowestHP
    for _, member in ipairs(group.members) do
      local percent, hp = Health(member)
      if percent and (not lowestHP or hp < lowestHP) then lowest, lowestHP = member, hp end
    end
    return lowest
  end
  return plate
end

function Z.ClickPlate(plate, button)
  if Z.IsPlateClickBlocked and Z.IsPlateClickBlocked() then return end
  -- Hover and clicks share the same live lowest-health member calculation.
  local member = Z.GetPlateClickMember(plate)
  if member then member.parent:Click(button or "LeftButton") end
end

local mouseoverPlate, mouseoverReceiver, mouseoverIdentifier
local function HoverEnabled()
  return type(SetMouseoverUnit)=="function" and Z.config
    and Z.config.nameplates.mouseover_unit=="1"
end

function Z.ClearPlateMouseover(plate, receiver)
  if mouseoverPlate~=plate or (receiver and receiver~=mouseoverReceiver) then return end
  mouseoverPlate, mouseoverReceiver, mouseoverIdentifier=nil,nil,nil
  -- Empty string, not nil: avoid a stale internal UnitIsPlayer(mouseover).
  if type(SetMouseoverUnit)=="function" then pcall(SetMouseoverUnit, "") end
end

local function SetPlateMouseover(plate, receiver, force)
  if not HoverEnabled() or plate.clusterHidden or
      (Z.IsPlateClickBlocked and Z.IsPlateClickBlocked()) then
    Z.ClearPlateMouseover(plate)
    return
  end
  local member=Z.GetPlateClickMember(plate)
  local identifier, token
  if member then
    local guid=member.cachedGuid
    local unit=member.unit
    local tokenValid=unit and UnitExists(unit) and (not guid or UnitGUID(unit)==guid)
    if tokenValid then token=unit end
    if guid and guid~="" then
      local ok,exists=pcall(UnitExists,guid)
      if tokenValid or (ok and exists) then identifier=guid end
    end
    identifier=identifier or token
  end
  if not identifier then
    if mouseoverPlate then Z.ClearPlateMouseover(mouseoverPlate) end
    return
  end
  if not force and mouseoverPlate==plate and mouseoverIdentifier==identifier then return end
  local ok,result=pcall(SetMouseoverUnit,identifier)
  if (not ok or result==false) and token and token~=identifier then
    identifier=token; ok,result=pcall(SetMouseoverUnit,identifier)
  end
  if ok and result~=false then
    mouseoverPlate,mouseoverReceiver,mouseoverIdentifier=plate,receiver,identifier
  elseif mouseoverPlate then
    Z.ClearPlateMouseover(mouseoverPlate)
  end
end

function Z.RefreshOwnedPlateMouseover(plate, force)
  if mouseoverPlate==plate then SetPlateMouseover(plate,mouseoverReceiver,force) end
end

function Z.InstallPlateMouseover(frame, plate)
  -- OnConfigChange runs repeatedly. Install once, with the live pooled plate
  -- reference in the frame's hook state; never grow a wrapper chain on refresh.
  local hooks=frame.znpMouseoverHooks
  if not hooks then
    hooks={}; frame.znpMouseoverHooks=hooks
    local previousEnter=frame:GetScript("OnEnter")
    local previousLeave=frame:GetScript("OnLeave")
    local previousHide=frame:GetScript("OnHide")
    frame:SetScript("OnEnter",function()
      if previousEnter then previousEnter(frame) end
      SetPlateMouseover(hooks.plate,frame,true)
    end)
    frame:SetScript("OnLeave",function()
      if previousLeave then previousLeave(frame) end
      -- An Enter on the other receiver may already have transferred ownership.
      Z.ClearPlateMouseover(hooks.plate,frame)
    end)
    frame:SetScript("OnHide",function()
      if previousHide then previousHide(frame) end
      -- Hiding the native parent removes both receivers. Hiding only the
      -- overlay must not clear a hover already transferred to the parent.
      Z.ClearPlateMouseover(hooks.plate, frame~=hooks.plate.parent and frame or nil)
    end)
  end
  hooks.plate=plate
  if not HoverEnabled() then Z.ClearPlateMouseover(plate) end
end

function Z.UpdatePlateClusters(now, visible, count, dirty)
  local C = Z.config.nameplates
  local threshold = math.max(10, math.min(100, tonumber(C.cluster_threshold) or 30))
  local active = C.cluster_enabled == "1" and count > threshold
  if not dirty and active == previousActive and nextUpdate and now < nextUpdate then return false end
  local hoveredCluster = mouseoverPlate and mouseoverPlate.clusterGroup
  previousActive, nextUpdate = active, now + .1
  for _, group in pairs(groups) do
    group.count, group.total = 0, 0
    table.wipe(group.members)
  end
  table.wipe(assignments)
  if active then
    local band = math.max(10, math.min(20, tonumber(C.cluster_health_band) or 20))
    local target = UnitGUID("target")
    for parent in pairs(visible) do
      local plate = parent.nameplate
      local unit = plate and plate.unit
      local reaction = unit and UnitReaction(unit, "player")
      if parent:IsVisible() and plate and unit and UnitExists(unit)
          and UnitCanAttack("player", unit) and not UnitIsPlayer(unit)
          and not plate.isCritter and not plate.isTotem
          and (not reaction or reaction < 4 or plate.neutralProvoked)
          and not (plate.cachedGuid and plate.cachedGuid == target)
          and not GetRaidTargetIndex(unit) then
        local percent = Health(plate)
        local name = UnitName(unit)
        if percent and name then
          local bucket = math.floor(math.min(99.999, percent) / band)
          -- Do not merge different levels or ownership-colour states.
          local tag = plate.taggedByPlayer and "own" or plate.taggedByOther and "other" or "free"
          local key = name .. "\031" .. tostring(UnitLevel(unit)) .. "\031" .. tag .. "\031" .. bucket
          local group = groups[key]
          if not group then group = {name=name,members={},count=0,total=0}; groups[key] = group end
          group.count, group.total = group.count + 1, group.total + percent
          group.members[group.count] = plate
        end
      end
    end
    for _, group in pairs(groups) do
      if group.count > 1 then
        local anchor
        for _, member in ipairs(group.members) do
          if member == group.anchor then anchor = member; break end
        end
        -- Keep the existing world anchor while it remains in this health band.
        if not anchor then
          for _, member in ipairs(group.members) do
            if not anchor or (member.platename or "") < (anchor.platename or "") then anchor = member end
          end
        end
        group.anchor, group.average = anchor, group.total / group.count
        for _, member in ipairs(group.members) do assignments[member] = group end
      end
    end
  end
  local changed = false
  for parent in pairs(visible) do
    local plate = parent.nameplate
    if plate then
      local group = assignments[plate]
      local hidden = group and group.anchor ~= plate or false
      if plate.clusterGroup ~= group or (plate.clusterHidden or false) ~= hidden then
        changed = true
        plate.eventcache, plate.lasttick = true, nil
        plate.cache.hp, plate.cache.hpmax = nil, nil
        plate.cache.name = nil
      end
      plate.clusterGroup, plate.clusterHidden = group, hidden
      if hidden then
        if plate.clusterCountFrame then plate.clusterCountFrame:Hide() end
        plate:Hide()
        parent:EnableMouse(false)
        if parent:GetWidth() > 1 then parent:SetSize(1, 1) end
        if plate.raidicon and plate.clusterRaidAlpha == nil then
          plate.clusterRaidAlpha = plate.raidicon:GetAlpha()
          plate.raidicon:SetAlpha(0)
        end
      else
        if not group and plate.clusterCountFrame then plate.clusterCountFrame:Hide() end
        plate:Show()
        if plate.clusterRaidAlpha ~= nil then
          plate.raidicon:SetAlpha(plate.clusterRaidAlpha)
          plate.clusterRaidAlpha = nil
        end
      end
    end
  end
  -- Remove unused bands; the pool remains bounded by current visible units.
  for key, group in pairs(groups) do if group.count == 0 then groups[key] = nil end end
  -- Reconcile only on the existing cluster-membership refresh, not a new
  -- per-frame hover poll. Membership/HP changes can change the click member.
  if mouseoverPlate and (hoveredCluster or mouseoverPlate.clusterGroup) then
    Z.RefreshOwnedPlateMouseover(mouseoverPlate)
  end
  return changed
end

function Z.ResetPlateCluster(plate)
  if plate.clusterCountFrame then plate.clusterCountFrame:Hide() end
  plate.clusterHidden, plate.clusterGroup = nil, nil
  plate.clusterRenderGroup, plate.clusterRenderDirty = nil, nil
  if plate.clusterRaidAlpha ~= nil and plate.raidicon then
    plate.raidicon:SetAlpha(plate.clusterRaidAlpha)
  end
  plate.clusterRaidAlpha = nil
  plate:Show()
end
