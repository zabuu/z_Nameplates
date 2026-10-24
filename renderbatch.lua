-- Share one live native association check and projection per render. Older
-- DLLs and whole-call failures use core.lua's existing Lua validation path.
local Z = zNameplates

function Z.PrepareValidatedPlateProjections(now, visible)
  local render=Z.plateRenderContext
  if not render or not render.active or render.now~=now or type(zAPI)~="function" then return false end
  if (Z.plateProjectionVersion or 0)<3.1 or type(UnitGUID)~="function" or type(UnitExists)~="function" then return false end
  if Z.validatedPlateAPI~=zAPI then
    Z.validatedPlateAPI=zAPI
    local ok,version=pcall(zAPI,"nameplateValidationVersion")
    Z.validatedPlateSupported=ok and version==1
  end
  if not Z.validatedPlateSupported then return false end
  local batch=Z.validatedPlateBatch
  if not batch then batch={ids={},units={},parents={},plates={},output={},count=0}; Z.validatedPlateBatch=batch end
  if batch.busy then return false end
  local count=0
  for parent in pairs(visible) do
    local plate=parent.nameplate
    if count<512 and plate and not plate.isDummy and not plate.clusterHidden
        and plate.cachedGuid and plate.unit and parent:IsVisible() then
      count=count+1
      batch.ids[count],batch.units[count],batch.parents[count],batch.plates[count]=plate.cachedGuid,plate.unit,parent,plate
    end
  end
  for i=count+1,batch.count do batch.ids[i],batch.units[i],batch.parents[i],batch.plates[i]=nil,nil,nil,nil end
  batch.count=count
  if count==0 then return true end
  local api,serial=zAPI,render.serial
  local guidAPI,existsAPI=UnitGUID,UnitExists
  local lookup=C_NamePlate and C_NamePlate.GetNamePlateForUnit
  local cost,generation
  if Z.platePerfActive then cost,generation=Z.BeginPlateCost() end
  batch.busy=true
  local ok,written=pcall(api,"projectNameplatesValidatedInto",batch.ids,count,batch.output,batch.units,batch.parents)
  batch.busy=nil
  if cost then Z.EndPlateCost("zNP native validated projection",cost,generation,count) end
  if not ok or written~=count or zAPI~=api or not render.active or render.serial~=serial
      or UnitGUID~=guidAPI or UnitExists~=existsAPI or (C_NamePlate and C_NamePlate.GetNamePlateForUnit)~=lookup then return false end
  for i=1,count do
    local k=(i-1)*8
    local current,projected=batch.output[k+1],batch.output[k+2]
    if (current~=0 and current~=1) or (projected~=0 and projected~=1) or (current==0 and projected~=0) then return false end
    if projected==1 then
      for j=3,8 do if type(batch.output[k+j])~="number" then return false end end
    end
  end
  for i=1,count do
    local plate= batch.plates[i]
    if plate.cachedGuid==batch.ids[i] and plate.unit==batch.units[i] and plate.parent==batch.parents[i] then
      local k=(i-1)*8
      local validation=plate.unitValidation
      if not validation then validation={}; plate.unitValidation=validation end
      validation.time,validation.unit,validation.guid=now,plate.unit,plate.cachedGuid
      validation.api,validation.exists,validation.lookup=guidAPI,existsAPI,lookup
      validation.parent,validation.current=plate.parent,batch.output[k+1]==1
      local sample=plate.projectionSample
      if not sample then sample={}; plate.projectionSample=sample end
      sample.time,sample.identity,sample.api,sample.command=now,plate.cachedGuid,api,"projectNameplate"
      sample.renderSerial=serial
      sample.x,sample.y,sample.depth=nil,nil,nil
      sample.wx,sample.wy,sample.wz=nil,nil,nil
      if batch.output[k+2]==1 then
        sample.x,sample.y,sample.depth=batch.output[k+3],batch.output[k+4],batch.output[k+5]
        sample.wx,sample.wy,sample.wz=batch.output[k+6],batch.output[k+7],batch.output[k+8]
      end
    end
  end
  return true
end
