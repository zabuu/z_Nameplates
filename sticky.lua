-- Stable screen-space displacement; world/camera movement stays immediate.
local Z = zNameplates
local sequence = 0
local nextSolve = 0
local entries = {}

local function Intersects(a, x, y, b, padding)
  return math.abs(x-b.x) < (a.w+b.w)*.5 + padding
    and math.abs(y-b.y) < (a.h+b.h)*.5 + padding
end

function Z.UpdateStickyPlacements(now, visible, shouldOverlap, targetGuid, hoverGuid)
  local C = Z.config.nameplates
  local enabled = C.sticky_placement == "1" and type(zAPI) == "function"
  local ui = UIParent:GetEffectiveScale()
  local count = 0
  for parent in pairs(visible) do
    local plate = parent.nameplate
    local identity = plate and (plate.cachedGuid or plate.unit)
    local sx, sy, depth
    if enabled and identity and parent:IsVisible() and not plate.clusterHidden
        and not shouldOverlap(plate) then
      sx, sy, depth = Z.GetPlateProjection(plate, now)
    end
    if type(sx) ~= "number" or type(sy) ~= "number" or type(depth) ~= "number"
        or depth <= 0 or ui <= 0 then
      if plate then plate.stickyPlacement = nil end
    else
      local nx, ny = parent:GetCenter()
      if nx and ny then
        local ps = parent:GetEffectiveScale()/ui
        nx, ny = nx*ps, (ny+parent:GetHeight()*.5)*ps
        sx, sy = sx*UIParent:GetWidth(), sy*UIParent:GetHeight()
        local s = plate.stickyPlacement
        if not s or s.identity ~= identity or now-s.last > .25
            or math.abs(sx-s.sx)>160 or math.abs(sy-s.sy)>160 then
          sequence = sequence+1
          s = {identity=identity,order=sequence,bx=nx-sx,by=ny-sy,
            dx=0,dy=0,displayX=0,displayY=0,depth=depth}
          plate.stickyPlacement = s
        end
        -- Scale the initial head/slot offset with perspective, not font steps.
        local perspective = math.max(.25,math.min(4,s.depth/depth))
        s.baseX, s.baseY = sx+s.bx*perspective, sy+s.by*perspective
        s.nativeX, s.nativeY = nx, ny
        s.sx, s.sy, s.last = sx, sy, now
        s.plate = plate
        local scale = plate:GetEffectiveScale()/ui
        local bufferX=math.max(0,math.min(40,tonumber(C.collision_buffer_x) or 0))
        local bufferY=math.max(0,math.min(40,tonumber(C.collision_buffer_y) or 0))
        s.w = math.max(20,(plate:GetWidth()+bufferX*2)*scale)
        s.h = math.max(14,(plate:GetHeight()+bufferY*2)*scale)
        s.priority = identity==targetGuid or identity==hoverGuid
        s.x,s.y = s.baseX+s.dx,s.baseY+s.dy
        count=count+1; entries[count]=s
      else
        plate.stickyPlacement=nil
      end
    end
  end
  for i=#entries,count+1,-1 do entries[i]=nil end
  -- Bound collision work in exceptionally crowded scenes; native smoothing
  -- remains available. Clustering normally keeps the visible set below this.
  if count>100 then
    for i=1,count do entries[i].plate.stickyPlacement=nil end
    return
  end
  if now<nextSolve then return end
  nextSolve=now+.05
  table.sort(entries,function(a,b)
    if a.priority~=b.priority then return a.priority end
    return a.order<b.order
  end)
  local delay = math.max(.05,math.min(.5,tonumber(C.sticky_delay) or .15))
  local release = math.max(.3,math.min(3,tonumber(C.sticky_return) or 1))
  for i=1,count do
    local s=entries[i]
    local obstructed=false
    for j=1,i-1 do
      if Intersects(s,s.x,s.y,entries[j],-2) then obstructed=true; break end
    end
    if obstructed then
      s.clearSince=nil
      s.collisionSince=s.collisionSince or now
      if now-s.collisionSince>=delay then
        -- Try short vertical slides first. Existing, higher-priority plates
        -- are obstacles, not a reason to reorder the entire scene.
        local bestY, bestMove
        for _,direction in ipairs({1,-1}) do
          local y=s.y
          for j=1,i-1 do
            local other=entries[j]
            if Intersects(s,s.x,y,other,2) then
              y=other.y+direction*((s.h+other.h)*.5+2)
            end
          end
          local clear=true
          for j=1,i-1 do
            if Intersects(s,s.x,y,entries[j],1) then clear=false; break end
          end
          local movement=math.abs(y-s.y)
          if clear and math.abs(y-s.nativeY)<=96 and (not bestMove or movement<bestMove) then
            bestY,bestMove=y,movement
          end
        end
        if bestY then s.dy=bestY-s.baseY; s.y=bestY end
      end
    else
      s.collisionSince=nil
      local clear=true
      for j=1,count do
        if j~=i and Intersects(s,s.nativeX,s.nativeY,entries[j],6) then clear=false; break end
      end
      if clear and (math.abs(s.nativeX-s.x)>2 or math.abs(s.nativeY-s.y)>2) then
        if not s.returnX or math.abs(s.nativeX-s.returnX)>4 or math.abs(s.nativeY-s.returnY)>4 then
          s.clearSince=now; s.returnX,s.returnY=s.nativeX,s.nativeY
        end
        if now-(s.clearSince or now)>=release then
          s.dx,s.dy=s.nativeX-s.baseX,s.nativeY-s.baseY
          s.x,s.y=s.nativeX,s.nativeY; s.clearSince=nil; s.returnX=nil
        end
      else s.clearSince=nil; s.returnX=nil end
    end
    -- Avoid indefinite detached labels if native/world calibration diverges.
    if math.abs(s.x-s.nativeX)>120 or math.abs(s.y-s.nativeY)>120 then
      s.dx,s.dy=s.nativeX-s.baseX,s.nativeY-s.baseY
      s.x,s.y=s.nativeX,s.nativeY
    end
  end
end

function Z.ApplyStickyPlacement(plate,now,nativeX,nativeY,uiScale,plateScale)
  local s=plate.stickyPlacement
  if not s then return end
  local elapsed=math.max(0,math.min(.1,now-(s.renderTime or now)))
  s.renderTime=now
  local blend=1-math.exp(-elapsed/ .08)
  s.displayX=s.displayX+(s.dx-s.displayX)*blend
  s.displayY=s.displayY+(s.dy-s.displayY)*blend
  return (s.baseX+s.displayX-nativeX)*uiScale/plateScale,
    (s.baseY+s.displayY-nativeY)*uiScale/plateScale
end
