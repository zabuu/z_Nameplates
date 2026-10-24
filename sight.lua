-- Collect only due LOS samples; render-rate fades and world anchors stay in
-- the existing visual pass. Private arrays and records are reused after warmup.
local Z = zNameplates

function Z.GetPreparedPlateSight(plate, now)
  local render, sample = Z.plateRenderContext, plate.sightBatchSample
  if render and render.active and render.now == now and sample
      and sample.serial == render.serial and sample.identity == plate.cachedGuid
      and sample.unit == plate.unit and sample.api == zAPI and sample.unitxp == UnitXP then
    return sample.result
  end
end

function Z.PreparePlateSight(now, visible, targetGuid, hoverGuid)
  local C, render = Z.config.nameplates, Z.plateRenderContext
  if C.los_fade ~= "1" or type(UnitXP) ~= "function" or type(zAPI) ~= "function"
      or not render or not render.active or render.now ~= now then return end
  if Z.sightBatchAPI ~= zAPI then
    Z.sightBatchAPI = zAPI
    local ok, version = pcall(zAPI, "nameplateSightVersion")
    Z.sightBatchSupported = ok and version == 1
  end
  if not Z.sightBatchSupported then return end
  local batch = Z.sightBatch
  if not batch then batch = {ids={}, units={}, plates={}, output={}, count=0}; Z.sightBatch = batch end
  if batch.busy then return end
  local count = 0
  for parent in pairs(visible) do
    local plate = parent.nameplate
    if count < 512 and plate and not plate.isDummy and not plate.clusterHidden
        and not plate.worldPlacementHidden and parent:IsVisible() and Z.IsPlateUnitCurrent(plate, now) then
      local background = Z.IsBackgroundFriendlyPlate(plate, targetGuid, hoverGuid, now)
      local interval = background and .2 or .1
      if plate.distanceScaleIdentity ~= plate.cachedGuid or plate.losSampleInterval ~= interval
          or plate.losSampleAPI ~= UnitXP or plate.losSampleNative ~= zAPI
          or not plate.losNextSample or now >= plate.losNextSample then
        count = count + 1
        batch.ids[count], batch.units[count], batch.plates[count] = plate.cachedGuid, plate.unit, plate
      end
    end
  end
  for i=count+1,batch.count do batch.ids[i], batch.units[i], batch.plates[i] = nil,nil,nil end
  batch.count = count
  if count == 0 then return end
  local cost, generation
  if Z.platePerfActive then cost, generation = Z.BeginPlateCost() end
  local api, serial = zAPI, render.serial
  batch.busy = true
  local ok, written = pcall(api, "nameplateSightInto", batch.ids, count, batch.output)
  batch.busy = nil
  if cost then Z.EndPlateCost("zNP native sight batch", cost, generation, count) end
  if not ok or written ~= count or zAPI ~= api or not render.active or render.serial ~= serial then return end
  for i=1,count do
    local value = batch.output[i]
    if value ~= -1 and value ~= 0 and value ~= 1 then return end
  end
  for i=1,count do
    local plate = batch.plates[i]
    if plate.cachedGuid == batch.ids[i] and plate.unit == batch.units[i] then
      local sample = plate.sightBatchSample
      if not sample then sample = {}; plate.sightBatchSample = sample end
      sample.serial, sample.identity, sample.unit = serial, batch.ids[i], batch.units[i]
      sample.api, sample.unitxp, sample.result = api, UnitXP, batch.output[i]
    end
  end
end
