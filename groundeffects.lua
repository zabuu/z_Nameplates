-- Small read-only ground markers: no mouse input, targeting, terrain reticles,
-- or per-frame object scans. Never guess a flare's position from the cursor.
local Z=zNameplates
local watcher=CreateFrame("Frame","zNameplatesGroundEffects",UIParent)
local records,pool,lastCast={},{},{}
local definitions={
  freezing={base=1499,icon="Spell_Frost_ChainsOfIce",duration=20},
  frost={base=13809,icon="Spell_Frost_FreezingBreath",duration=30},
  immolation={base=13795,icon="Spell_Fire_FlameShock",duration=15},
  explosive={base=13813,icon="Spell_Fire_SelfDestruct",duration=20},
  flare={base=1543,icon="Spell_Fire_Flare",duration=30},
}
local casts={ [1499]="freezing",[14310]="freezing",[14311]="freezing",
  [13809]="frost",[13795]="immolation",[14302]="immolation",[14303]="immolation",[14304]="immolation",[14305]="immolation",
  [13813]="explosive",[14316]="explosive",[14317]="explosive",[1543]="flare" }
local effects={ [3355]="freezing",[14308]="freezing",[14309]="freezing",[13810]="frost",
  [13797]="immolation",[14298]="immolation",[14299]="immolation",[14300]="immolation",[14301]="immolation",
  [13812]="explosive",[14314]="explosive",[14315]="explosive" }
local nativeAPI,nativeReady
local function Native(command,a,b,c)
  if type(zAPI)~="function" then return end
  local ok,v1,v2,v3,v4,v5,v6,v7=pcall(zAPI,command,a,b,c)
  if ok then return v1,v2,v3,v4,v5,v6,v7 end
end
local function Ready()
  if nativeAPI~=zAPI then nativeAPI=zAPI; nativeReady=Native("groundObjectVersion")==1 end
  return nativeReady
end
local function SpellName(id)
  if GetSpellNameAndRankForId then local ok,name=pcall(GetSpellNameAndRankForId,id); if ok then return name end end
  if GetSpellInfo then local ok,name=pcall(GetSpellInfo,id); if ok then return name end end
end
local function Kind(id)
  if casts[id] then return casts[id] end
  if casts[id]==false then return end
  local name=SpellName(id)
  if name then for key,data in pairs(definitions) do if SpellName(data.base)==name then casts[id]=key; return key end end end
  if id then casts[id]=false end
end
local function Duration(id,fallback)
  if GetSpellDuration then
    local ok,ms=pcall(GetSpellDuration,id)
    if ok and type(ms)=="number" and ms>0 then return ms/1000 end
  end
  return fallback
end
local function Entry(id)
  if not GetSpellRecField then return end
  local ok,values=pcall(GetSpellRecField,id,"effectMiscValue")
  if ok and type(values)=="table" then
    for i=1,3 do if type(values[i])=="number" and values[i]>0 then return values[i] end end
  end
end
local function SpellTexture(id,kind)
  if GetSpellRecField and GetSpellIconTexture then
    local ok,icon=pcall(GetSpellRecField,id,"spellIconID")
    if ok and type(icon)=="number" then
      local found,texture=pcall(GetSpellIconTexture,icon)
      if found and type(texture)=="string" then return texture end
    end
  end
  return "Interface\\Icons\\"..definitions[kind].icon
end
local function Release(index)
  local record=table.remove(records,index)
  if record.frame then record.frame:Hide(); table.insert(pool,record.frame) end
end
function Z.RefreshGroundEffects()
  local C=Z.config and Z.config.groundeffects
  for i=table.getn(records),1,-1 do
    local r=records[i]
    if not C or C.enabled~="1" or (r.kind=="flare" and C.flares~="1") or (r.kind~="flare" and C.traps~="1") then Release(i) end
  end
  if table.getn(records)==0 then watcher:Hide() end
end
local function CreateMarker()
  local frame=table.remove(pool)
  if frame then return frame end
  frame=CreateFrame("Frame",nil,UIParent)
  frame:EnableMouse(false); frame:SetFrameStrata("HIGH"); frame:SetFrameLevel(30)
  frame.icon=frame:CreateTexture(nil,"ARTWORK"); frame.icon:SetAllPoints(frame)
  frame.icon:SetTexCoord(.08,.92,.08,.92)
  frame.timer=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  frame.timer:SetPoint("CENTER",frame,"CENTER",0,0)
  frame.timer:SetShadowColor(0,0,0,1); frame.timer:SetShadowOffset(1,-1)
  frame.status=frame:CreateTexture(nil,"OVERLAY")
  frame.status:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  frame.status:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,-2)
  frame.status:SetHeight(2); frame:Hide()
  return frame
end
local function Cast(id,now)
  local C=Z.config and Z.config.groundeffects
  local kind=Kind(id)
  if not kind or not C or C.enabled~="1" or not Ready()
      or (kind=="flare" and C.flares~="1") or (kind~="flare" and C.traps~="1") then return end
  if lastCast[id] and now-lastCast[id]<.3 then return end
  lastCast[id]=now
  local query=kind=="flare" and id or Entry(id)
  if not query then return end -- Cannot identify the actual object: do not invent one.
  local exclude
  for _,r in ipairs(records) do if r.kind==kind and r.guid then exclude=r.guid end end
  if table.getn(records)>=12 then Release(1) end
  table.insert(records,{kind=kind,spell=id,query=query,objectType=kind=="flare" and 6 or 5,
    cast=now,expires=now+Duration(id,kind=="flare" and 30 or 60),phase="armed",exclude=exclude,nextQuery=now})
  watcher:Show()
end
local function Activate(record,id,target,ms,now)
  if record.phase~="armed" then return end
  now=now or GetTime()
  -- Frost's marker describes the ground field, not the shorter slow applied
  -- to an individual victim. Re-entering its slow must not restart this clock.
  local duration
  if record.kind=="frost" then duration=Duration(13810,definitions.frost.duration)
  else duration=type(ms)=="number" and ms>0 and ms/1000 or Duration(id,definitions[record.kind].duration) end
  record.phase="active"; record.target=target; record.effect=id; record.missingAt=nil
  record.triggered=now; record.expires=now+duration
end

local function RecoverFrostField(record,now)
  -- A trap GO is consumed when its persistent dynamic field is created. Some
  -- clients send no usable cast/aura event for that handoff. Confirm the own
  -- field at this exact trap location instead of treating removal as despawn.
  local guid,x,y,z=Native("groundObject",6,13810,record.unmatchedField)
  if not guid or type(x)~="number" or type(y)~="number" or type(z)~="number" then return end
  local dx,dy,dz=x-record.x,y-record.y,z-record.z
  if dx*dx+dy*dy+dz*dz>2.25 then
    -- An older own Frost Trap elsewhere is not this trap's replacement. The
    -- next bounded discovery retry can look past it, without moving this icon.
    record.unmatchedField=guid
    return
  end
  local triggered=record.missingAt or now
  record.fieldGuid=guid; record.unmatchedField=nil
  Activate(record,13810,nil,nil,triggered)
  return true
end

local function Trigger(id,source,target,ms)
  local kind=effects[id]
  if not kind then return end
  local owner=UnitGUID and UnitGUID("player")
  if not owner or not source then return end
  for i=table.getn(records),1,-1 do
    local r=records[i]
    if r.kind==kind and r.phase=="armed" and r.guid and (source==owner or source==r.guid) then
      Activate(r,id,target,ms)
      -- Keep the original real ground position, including after the trap GO
      -- is consumed. Effect events, not unrelated aura gains, change its phase.
      return
    end
  end
end
watcher:SetScript("OnEvent",function()
  if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LEAVING_WORLD" then
    for i=table.getn(records),1,-1 do Release(i) end
    watcher:Hide(); return
  elseif event=="ADDON_LOADED" then
    if arg1=="z_Nameplates" then Z.RefreshGroundEffects() end
    return
  elseif event=="SPELL_GO_SELF" then
    Cast(tonumber(arg2),GetTime()); Trigger(tonumber(arg2),arg3,arg4)
  elseif event=="UNIT_SPELLCAST_SUCCEEDED" and arg1=="player" then
    Cast(tonumber(arg3),GetTime()); Trigger(tonumber(arg3),UnitGUID and UnitGUID("player"))
  elseif event=="SPELL_GO_OTHER" then Trigger(tonumber(arg2),arg3,arg4)
  elseif event=="AURA_CAST_ON_SELF" or event=="AURA_CAST_ON_OTHER" then Trigger(tonumber(arg1),arg2,arg3,arg8)
  elseif event=="DEBUFF_REMOVED_OTHER" then
    for i=table.getn(records),1,-1 do
      local r=records[i]
      if arg7~=2 and r.phase=="active" and r.target==arg1 and r.effect==tonumber(arg3) and r.kind~="frost" and r.kind~="explosive" then Release(i) end
    end
  end
end)
watcher:SetScript("OnUpdate",function()
  local C=Z.config and Z.config.groundeffects
  if not C or C.enabled~="1" then Z.RefreshGroundEffects(); return end
  local now=GetTime()
  for i=table.getn(records),1,-1 do
    local r=records[i]
    if now>=r.expires or (not r.guid and now-r.cast>3) then Release(i)
    else
      if now>=(r.nextQuery or 0) then
        r.nextQuery=now+(r.guid and .25 or .1)
        if not r.guid then
          local guid,x,y,z=Native("groundObject",r.objectType,r.query,r.exclude)
          if guid and type(x)=="number" and type(y)=="number" and type(z)=="number" then
            r.guid,r.x,r.y,r.z=guid,x,y,z
            r.frame=CreateMarker()
            r.frame.icon:SetTexture(SpellTexture(r.spell,r.kind))
            -- A new armed trap replaces the preceding armed trap, not effects
            -- already triggered. Flares may coexist until their own expiry.
            if r.kind~="flare" then
              for j=table.getn(records),1,-1 do
                local old=records[j]
                if old~=r and old.kind~="flare" and old.phase=="armed" and old.cast<r.cast then
                  old.expires=now
                  if old.frame then old.frame:Hide() end
                end
              end
            end
          end
        elseif r.phase=="armed" then
          local guid=Native("groundObjectState",r.guid)
          if guid then r.missingAt=nil
          else
            r.missingAt=r.missingAt or now
            if r.kind=="frost" then RecoverFrostField(r,now) end
          end
        elseif r.fieldGuid then
          -- Once bound, resolve that exact field directly; do not scan or
          -- reassign it to another same-spell patch after it expires.
          if Native("groundObjectState",r.fieldGuid) then r.missingAt=nil
          else r.missingAt=r.missingAt or now end
        end
      end
      local grace=r.kind=="frost" and r.phase=="armed" and 1.25 or .6
      if r.missingAt and now-r.missingAt>grace then
        -- Consumed/dispelled/despawned objects are not assumed to have fired.
        Release(i)
      elseif r.frame then
        local x,y,depth=Native("worldToScreen",r.x,r.y,r.z+(tonumber(C.height) or .35))
        -- zAPI returns WorldFrame coordinates. Reuse the nameplate conversion
        -- before clipping/anchoring, including live UI-scale changes. Icon
        -- scale below is a separate local scale and must only be applied once.
        x,y=Z.NormalizeWorldProjection(x,y)
        if type(x)~="number" or type(y)~="number" or type(depth)~="number" or depth<=0 or x<0 or x>1 or y<0 or y>1 then r.frame:Hide()
        else
          local frame=r.frame; local size=tonumber(C.size) or 22; local scale=tonumber(C.scale) or 1
          if frame.appliedScale~=scale then frame:SetScale(scale); frame.appliedScale=scale end
          if frame.appliedSize~=size then frame:SetWidth(size); frame:SetHeight(size); frame.status:SetWidth(size); frame.appliedSize=size end
          local sx,sy=x*UIParent:GetWidth()/scale,y*UIParent:GetHeight()/scale
          if frame.appliedX~=sx or frame.appliedY~=sy then frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",sx,sy); frame.appliedX,frame.appliedY=sx,sy end
          local opacity=tonumber(C.opacity) or .45
          if frame.appliedOpacity~=opacity then frame.icon:SetAlpha(opacity); frame.appliedOpacity=opacity end
          local text=math.ceil(math.max(0,r.expires-now))
          if frame.lastText~=text then frame.timer:SetText(text>=60 and string.format("%d:%02d",math.floor(text/60),math.mod(text,60)) or tostring(text)); frame.lastText=text end
          local font,size=Z.font_default or "Fonts\\FRIZQT__.TTF",tonumber(C.fontsize) or 11
          if frame.appliedFont~=font or frame.appliedFontSize~=size then
            frame.timer:SetFont(font,size,"OUTLINE"); frame.appliedFont,frame.appliedFontSize=font,size
          end
          if frame.appliedPhase~=r.phase then
            if r.phase=="active" then frame.status:SetVertexColor(.25,.9,.65,.8) else frame.status:SetVertexColor(.9,.72,.25,.65) end
            frame.appliedPhase=r.phase
          end
          if not frame:IsShown() then frame:Show() end
        end
      end
    end
  end
  if table.getn(records)==0 then watcher:Hide() end
end)
for _,name in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","SPELL_GO_SELF","SPELL_GO_OTHER",
  "UNIT_SPELLCAST_SUCCEEDED","AURA_CAST_ON_SELF","AURA_CAST_ON_OTHER","DEBUFF_REMOVED_OTHER"}) do pcall(watcher.RegisterEvent,watcher,name) end
if SetCVar then
  pcall(SetCVar,"NP_EnableSpellGoEvents","1")
  pcall(SetCVar,"NP_EnableAuraCastEvents","1")
end
Z.groundEffectRecords=records -- Diagnostics/tests; this table is never saved.
watcher:Hide()
