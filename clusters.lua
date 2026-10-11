-- Crowded-scene aggregation keeps real native unit frames for exact clicking.
local Z = zNameplates
local groups, assignments = {}, {}
local nextUpdate, previousActive
local filterText, debuffFilters = nil, {}

function Z.GetClusterDebuffNames(text)
  if text~=filterText then
    filterText=text; debuffFilters={}
    for entry in string.gfind(text or "", "[^#\n]+") do
      local name=string.gsub(string.gsub(entry,"^%s+",""),"%s+$","")
      if name~="" then debuffFilters[#debuffFilters+1]=name end
    end
  end
  return debuffFilters
end

local function DebuffGroup(unit, text)
  Z.GetClusterDebuffNames(text)
  if #debuffFilters==0 or not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return "" end
  local ok,auras=pcall(C_UnitAuras.GetUnitAuras,unit,"HARMFUL")
  if not ok or type(auras)~="table" then return "" end
  for _,name in ipairs(debuffFilters) do
    for _,aura in ipairs(auras) do if aura.name==name then return name end end
  end
  return ""
end

local function RangeFill(plate,group)
  local bar=plate.health
  local texture=plate.clusterRangeTexture
  if not texture and bar.CreateTexture then
    texture=bar:CreateTexture(nil,"ARTWORK")
    plate.clusterRangeTexture=texture
  end
  if not texture then return end
  local width,height=bar:GetWidth(),bar:GetHeight()
  local minimum,maximum=group.minimum/100,group.maximum/100
  local fill=bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  texture:SetTexture(fill and fill.GetTexture and fill:GetTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
  local r,g,b=1,0,0
  if bar.GetStatusBarColor then r,g,b=bar:GetStatusBarColor() end
  texture:SetVertexColor(r,g,b,tonumber(Z.config.nameplates.cluster_range_opacity) or .4)
  texture:ClearAllPoints()
  if Z.config.nameplates.verticalhealth=="1" then
    texture:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",0,height*minimum)
    texture:SetWidth(width); texture:SetHeight(math.max(.001,height*(maximum-minimum)))
  else
    texture:SetPoint("LEFT",bar,"LEFT",width*minimum,0)
    texture:SetWidth(math.max(.001,width*(maximum-minimum))); texture:SetHeight(height)
  end
  if maximum>minimum then texture:Show() else texture:Hide() end
end

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
  plate.health:Show()
  plate.health:SetMinMaxValues(0,100)
  RangeFill(plate,group)
  -- Data updates can rewrite the representative's HP without changing groups.
  if not plate.health.GetValue or plate.health:GetValue()~=group.minimum then plate.health:SetValue(group.minimum) end
  local healthText=string.format("%.0f–%.0f%%",group.minimum,group.maximum)
  if not plate.health.text.GetText or plate.health.text:GetText()~=healthText then plate.health.text:SetText(healthText) end
  if not plate.clusterRenderDirty and plate.clusterRenderGroup == group
      and plate.clusterRenderCount == group.count and plate.clusterRenderMin == group.minimum
      and plate.clusterRenderMax == group.maximum then return end
  plate.clusterRenderDirty = nil
  plate.clusterRenderGroup, plate.clusterRenderCount, plate.clusterRenderAverage = group, group.count, group.average
  plate.clusterRenderMin,plate.clusterRenderMax=group.minimum,group.maximum
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
  plate.health:SetValue(group.minimum)
  plate.health.text:SetText(healthText)
  if group.debuff and group.debuff~="" then
    if not plate.clusterDebuffLabel then
      plate.clusterDebuffLabel=plate.health:CreateFontString(nil,"OVERLAY","GameFontNormal")
      plate.clusterDebuffLabel:SetPoint("TOP",plate.health,"BOTTOM",0,-2)
    end
    plate.clusterDebuffLabel:SetFont(font or Z.font_unit or Z.font_default,math.max(8,baseSize-1),"OUTLINE")
    plate.clusterDebuffLabel:SetText(group.debuff)
    plate.clusterDebuffLabel:SetTextColor(.85,.75,1,1); plate.clusterDebuffLabel:Show()
  elseif plate.clusterDebuffLabel then plate.clusterDebuffLabel:Hide() end
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
      if Z.SetPlateLayoutHover then Z.SetPlateLayoutHover(hooks.plate,frame,true) end
      SetPlateMouseover(hooks.plate,frame,true)
    end)
    frame:SetScript("OnLeave",function()
      if previousLeave then previousLeave(frame) end
      if Z.SetPlateLayoutHover then Z.SetPlateLayoutHover(hooks.plate,frame,false) end
      -- An Enter on the other receiver may already have transferred ownership.
      Z.ClearPlateMouseover(hooks.plate,frame)
    end)
    frame:SetScript("OnHide",function()
      if previousHide then previousHide(frame) end
      if Z.SetPlateLayoutHover then Z.SetPlateLayoutHover(hooks.plate,frame,false,true) end
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
    group.minimum,group.maximum=nil,nil
    table.wipe(group.members)
  end
  table.wipe(assignments)
  if active then
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
          -- Do not merge different levels or ownership-colour states.
          local tag = plate.taggedByPlayer and "own" or plate.taggedByOther and "other" or "free"
          local debuff=DebuffGroup(unit,C.cluster_debuff_whitelist or "")
          local key = name .. "\031" .. tostring(UnitLevel(unit)) .. "\031" .. tag .. "\031" .. debuff
          local group = groups[key]
          if not group then group = {name=name,debuff=debuff,members={},count=0,total=0}; groups[key] = group end
          group.count, group.total = group.count + 1, group.total + percent
          group.minimum=math.min(group.minimum or percent,percent)
          group.maximum=math.max(group.maximum or percent,percent)
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
        -- Preserve the representative while it remains in this subgroup.
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
      if (hidden or not group) and plate.clusterRangeTexture then plate.clusterRangeTexture:Hide() end
      if (hidden or not group) and plate.clusterDebuffLabel then plate.clusterDebuffLabel:Hide() end
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
  if plate.clusterDebuffLabel then plate.clusterDebuffLabel:Hide() end
  if plate.clusterRangeTexture then plate.clusterRangeTexture:Hide() end
  if plate.clusterCountFrame then plate.clusterCountFrame:Hide() end
  plate.clusterHidden, plate.clusterGroup = nil, nil
  plate.clusterRenderGroup, plate.clusterRenderDirty = nil, nil
  if plate.clusterRaidAlpha ~= nil and plate.raidicon then
    plate.raidicon:SetAlpha(plate.clusterRaidAlpha)
  end
  plate.clusterRaidAlpha = nil
  plate:Show()
end

-- Settings-only demonstration: real range renderer, no fabricated game units,
-- target changes or edits to the live cluster registry.
function Z.RefreshClusterPreview(parent)
  local C=Z.config.nameplates
  local filters=Z.GetClusterDebuffNames(C.cluster_debuff_whitelist or "")
  parent.samples=parent.samples or {}
  if not parent.legend then
    parent.legend=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    parent.legend:SetPoint("TOPLEFT",parent,"TOPLEFT",340,-12)
    parent.legend:SetWidth(220); parent.legend:SetHeight(130); parent.legend:SetJustifyH("LEFT")
    parent.legend:SetText("Solid: lowest HP\nFaded: highest HP\n\nAdd debuffs in Crowds to preview subgroups.\n\nSample ignores the clustering threshold.")
  end
  local minimum=math.max(0,math.min(100,tonumber(C.dummy_cluster_min) or 25))
  local maximum=math.max(minimum,math.min(100,tonumber(C.dummy_cluster_max) or 85))
  local count=math.max(2,math.min(30,tonumber(C.dummy_cluster_members) or 8))
  for i=1,3 do
    local plate=parent.samples[i]
    if not plate then
      plate=CreateFrame("Frame",nil,parent); plate.parent=parent; plate.isDummy=true
      plate:SetWidth(260); plate:SetHeight(40); plate:EnableMouse(false)
      plate.health=CreateFrame("StatusBar",nil,plate)
      plate.health:SetPoint("TOPLEFT",plate,"TOPLEFT",0,-16)
      plate.name=plate:CreateFontString(nil,"OVERLAY","GameFontNormal")
      plate.name:SetPoint("BOTTOM",plate.health,"TOP",0,2)
      plate.health.text=plate.health:CreateFontString(nil,"OVERLAY","GameFontNormal")
      plate.health.text:SetAllPoints(plate.health)
      parent.samples[i]=plate
    end
    if i==1 or filters[i-1] then
      local font=Z.font_unit or Z.font_default or "Fonts\\FRIZQT__.TTF"
      local size=tonumber(C.name and C.name.fontsize) or 10
      plate:SetFrameStrata(parent:GetFrameStrata()); plate:SetFrameLevel(parent:GetFrameLevel()+1)
      plate.health:SetFrameStrata(plate:GetFrameStrata())
      plate.health:SetFrameLevel(plate:GetFrameLevel()+1)
      plate:SetPoint("TOPLEFT",parent,"TOPLEFT",26,-12-(i-1)*54)
      plate.health:SetWidth(math.min(300,tonumber(C.width) or 120))
      plate.health:SetHeight(tonumber(C.heighthealth) or 8)
      plate.health:SetOrientation(C.verticalhealth=="1" and "VERTICAL" or "HORIZONTAL")
      plate.health:SetStatusBarTexture(Z.media and Z.media[C.healthtexture] or C.healthtexture or "Interface\\TargetingFrame\\UI-StatusBar")
      plate.health:SetStatusBarColor(.72,.12,.12,1)
      if Z.CreateBackdrop then local _,border=Z.GetBorderSize("nameplates"); Z.CreateBackdrop(plate.health,border) end
      -- Moving the preview's parent level can also move its child backdrop.
      -- Repair it on every refresh, not only when CreateBackdrop first builds it.
      if plate.health.backdrop then
        plate.health.backdrop:SetFrameStrata(plate.health:GetFrameStrata())
        plate.health.backdrop:SetFrameLevel(math.max(0,plate.health:GetFrameLevel()-1))
      end
      plate.name:SetFont(font,size,C.name and C.name.fontstyle or "")
      plate.name:SetTextColor(Z.GetStringColor(C.enemynamecolor or "1,1,1,1"))
      plate.health.text:SetFont(font,math.max(8,size-2),"OUTLINE")
      plate.health.text:SetTextColor(1,1,1,1)
      plate.health.text:SetJustifyH(C.hptextpos or "RIGHT")
      plate.health.text:SetShown(C.showhp~="0")
      local group={name="Dummy Pack",minimum=minimum,maximum=maximum,count=count,
        average=(minimum+maximum)/2,debuff=i>1 and filters[i-1] or ""}
      group.anchor=plate; plate.clusterGroup=group; plate.clusterRenderDirty=true
      plate:Show(); Z.RenderPlateCluster(plate)
    else
      plate:Hide()
      if plate.clusterCountFrame then plate.clusterCountFrame:Hide() end
    end
  end
end
