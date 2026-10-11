-- Stable screen-space displacement; world/camera movement stays immediate.
local Z = zNameplates
local sequence = 0
local nextSolve = 0
local entries = {}

local function Intersects(a, x, y, b, padding)
  return math.abs(x-b.x) < (a.w+b.w)*.5 + padding
    and math.abs(y-b.y) < (a.h+b.h)*.5 + padding
end

function Z.SetPlateLayoutHover(plate,receiver,enter,hidden)
  local now=GetTime and GetTime() or 0
  if enter then plate.layoutHoverReceiver=receiver; plate.layoutHoverUntil=nil
  elseif plate.layoutHoverReceiver==receiver or (hidden and receiver==plate.parent) then
    plate.layoutHoverReceiver=nil
    plate.layoutHoverUntil=hidden and nil or now+.2
  end
end

local function Measure(plate,ui)
  -- Measure visible regions, not the legacy width+50 collision placeholder.
  local x,y=plate.GetCenter and plate:GetCenter()
  local top=plate.GetTop and plate:GetTop()
  local scale=plate:GetEffectiveScale()/ui
  local left,right,bottom,upper
  if x and top then
    x,top=x*scale,top*scale
    local function Include(object)
      if not object or not object.GetLeft or not object.GetRight or not object.GetTop or not object.GetBottom
          or (object.IsShown and not object:IsShown()) then return end
      if object.GetText then local text=object:GetText(); if not text or text=="" then return end end
      local l,r,t,b=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
      if not l or not r or not t or not b then return end
      local k=(object.GetEffectiveScale and object:GetEffectiveScale() or plate:GetEffectiveScale())/ui
      l,r,t,b=l*k-x,r*k-x,t*k-top,b*k-top
      left=math.min(left or l,l); right=math.max(right or r,r)
      bottom=math.min(bottom or b,b); upper=math.max(upper or t,t)
    end
    Include(plate.health); Include(plate.name); Include(plate.level); Include(plate.guild)
    Include(plate.castbar); Include(plate.clusterDebuffLabel)
    Include(plate.raidicon)
    for _,aura in ipairs(plate.debuffs or {}) do Include(aura) end
  end
  if left then return math.max(20,right-left),math.max(14,upper-bottom),(right+left)*.5,(upper+bottom)*.5 end
  local bar=plate.health
  return math.max(20,(bar and bar:GetWidth() or plate:GetWidth())*scale),
    math.max(14,plate:GetHeight()*scale),0,0
end

local function Penalty(s,dx,dy,count)
  local x,y=s.baseX+dx+s.cx,s.baseY+dy+s.cy
  local penalty=0
  local neighbors=s.neighbors or entries
  for j=1,#neighbors do
    local other=neighbors[j]
    if other~=s then
      local overlapX=(s.w+other.w)*.5+2-math.abs(x-other.x)
      local overlapY=(s.h+other.h)*.5+2-math.abs(y-other.y)
      if overlapX>0 and overlapY>0 then
        penalty=penalty+overlapX*overlapY*(other.hovered and 12 or other.priority and 6 or 4)
      end
    end
  end
  -- Penalise detachment and travel; keep a warm layout instead of solving
  -- each frame from scratch. Sideways relocation costs more than vertical.
  return penalty+dx*dx*1.4+dy*dy*.35+
    ((dx-s.dx)^2+(dy-s.dy)^2)*(s.priority and .25 or .12)
end

local function HideLink(plate)
  if plate.layoutAnchorLink then plate.layoutAnchorLink:Hide() end
end

local function DrawLink(plate,s,uiScale)
  local C=Z.config.nameplates
  if C.sticky_anchor_link=="0" or not (s.hovered or plate.istarget)
      or s.displayX*s.displayX+s.displayY*s.displayY<24*24
      or not CreateFrame or not plate.GetFrameLevel then HideLink(plate); return end
  local link=plate.layoutAnchorLink
  if not link then
    link=CreateFrame("Frame",nil,plate.parent); link:EnableMouse(false)
    link:SetWidth(1); link:SetHeight(1); link.dots={}
    for i=1,12 do
      local dot=link:CreateTexture(nil,"BACKGROUND")
      dot:SetTexture("Interface\\BUTTONS\\WHITE8X8"); dot:SetWidth(1.4); dot:SetHeight(1.4)
      dot:SetVertexColor(1,1,1,.3); link.dots[i]=dot
    end
    plate.layoutAnchorLink=link
  end
  link:SetScale(uiScale/plate.parent:GetEffectiveScale())
  link:SetFrameStrata(plate:GetFrameStrata()); link:SetFrameLevel(math.max(0,plate:GetFrameLevel()-1))
  for i,dot in ipairs(link.dots) do
    local t=i/13
    dot:ClearAllPoints(); dot:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.baseX+s.displayX*t,s.baseY+s.displayY*t)
  end
  link:Show()
end

local function UpdateStickyPlacements(now, visible, shouldOverlap, targetGuid, hoverGuid)
  local C = Z.config.nameplates
  local enabled = C.sticky_placement == "1" and type(zAPI) == "function"
  local ui = UIParent:GetEffectiveScale()
  local count = 0
  for parent in pairs(visible) do
    local plate = parent.nameplate
    local identity = plate and (plate.cachedGuid or plate.unit)
    local sx, sy, depth
    local eligible = enabled and identity and parent:IsVisible() and not plate.clusterHidden
    local allowsOverlap = plate and shouldOverlap(plate)
    if eligible then
      sx, sy, depth = Z.GetPlateProjection(plate, now)
    end
    if allowsOverlap then
      -- Leave the working native layout untouched outside stacking. Record
      -- its centre-to-projection bias before combat changes the hitbox width.
      if eligible and type(sx)=="number" and sx==sx and type(depth)=="number" and depth>0 and ui>0 then
        local nativeX,nativeY=parent:GetCenter()
        if nativeX and nativeY and type(sy)=="number" and sy==sy then
          local scale=plate:GetEffectiveScale()/ui
          if scale>0 then
            plate.stickyAnchorCalibration={identity=identity,
              x=(nativeX*parent:GetEffectiveScale()/ui-sx*UIParent:GetWidth())/scale,
              y=((nativeY+parent:GetHeight()*.5)*parent:GetEffectiveScale()/ui-sy*UIParent:GetHeight())/scale}
          end
        end
      end
      eligible=false; sx,sy,depth=nil,nil,nil
    end
    if type(sx) ~= "number" or type(sy) ~= "number" or type(depth) ~= "number"
        or sx~=sx or sy~=sy or depth~=depth or depth <= 0 or ui <= 0 then
      local previous=plate and plate.stickyPlacement
      -- One missing sample must not flash the client collision layout.
      -- Never retain a hidden, reclassified or recycled unit's position.
      if eligible and previous and previous.identity==identity and now-previous.last<=.12 then
        count=count+1; entries[count]=previous
      elseif plate then plate.stickyPlacement = nil; HideLink(plate) end
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
          local calibration=plate.stickyAnchorCalibration
          local bias=calibration and calibration.identity==identity and calibration.x or 0
          local baseY=calibration and calibration.identity==identity and calibration.y
          s = {identity=identity,order=sequence,biasX=bias,by=baseY and baseY*plate:GetEffectiveScale()/ui or ny-sy,
            dx=0,dy=0,displayX=0,displayY=0,vx=0,vy=0,depth=depth}
          plate.stickyPlacement = s
        end
        -- Scale the initial head/slot offset with perspective, not font steps.
        local perspective = math.max(.25,math.min(4,s.depth/depth))
        -- Native collision frames can be shoved sideways. Never preserve or
        -- return to that displacement: centre the column on the world anchor.
        s.baseX, s.baseY = sx+s.biasX*plate:GetEffectiveScale()/ui, sy+s.by*perspective
        s.nativeX, s.nativeY = nx, ny
        s.sx, s.sy, s.last = sx, sy, now
        s.plate = plate
        local scale = plate:GetEffectiveScale()/ui
        local bufferX=math.max(0,math.min(40,tonumber(C.collision_buffer_x) or 0))
        local bufferY=math.max(0,math.min(40,tonumber(C.collision_buffer_y) or 0))
        if not s.contentW or now>=nextSolve then
          s.contentW,s.contentH,s.cx,s.cy=Measure(plate,ui)
        end
        s.w,s.h=s.contentW+bufferX*2*scale,s.contentH+bufferY*2*scale
        s.priority = identity==targetGuid or identity==hoverGuid
        s.hovered=C.sticky_hover_protection~="0" and (plate.layoutHoverReceiver~=nil or
          (plate.layoutHoverUntil and now<plate.layoutHoverUntil)) or false
        if s.hovered then
          s.dx,s.dy=s.displayX,s.displayY; s.vx,s.vy=0,0
        end
        s.x,s.y = s.baseX+s.dx+s.cx,s.baseY+s.dy+s.cy
        count=count+1; entries[count]=s
      else
        local previous=plate.stickyPlacement
        if previous and previous.identity==identity and now-previous.last<=.12 then
          count=count+1; entries[count]=previous
        else plate.stickyPlacement=nil; HideLink(plate) end
      end
    end
  end
  for i=#entries,count+1,-1 do entries[i]=nil end
  -- Bound collision work in exceptionally crowded scenes; native smoothing
  -- remains available. Clustering normally keeps the visible set below this.
  if count>100 then
    for i=1,count do entries[i].plate.stickyPlacement=nil; HideLink(entries[i].plate) end
    return
  end
  if now<nextSolve then return end
  nextSolve=now+.05
  table.sort(entries,function(a,b)
    if a.hovered~=b.hovered then return a.hovered end
    return a.order<b.order
  end)
  local delay = math.max(.05,math.min(.5,tonumber(C.sticky_delay) or .15))
  local maximum=math.max(32,math.min(180,tonumber(C.sticky_max_displacement) or 96))
  for i=1,count do
    local s=entries[i]
    local nearby=s.neighbors or {}; s.neighbors=nearby
    local n=0
    for j=1,count do
      local other=entries[j]
      if other~=s and math.abs(s.baseX+s.cx-other.x)<(s.w+other.w)*.5+maximum
          and math.abs(s.baseY+s.cy-other.y)<(s.h+other.h)*.5+maximum*2 then
        n=n+1; nearby[n]=other
      end
    end
    for j=#nearby,n+1,-1 do nearby[j]=nil end
    table.sort(nearby,function(a,b)
      if a.hovered~=b.hovered then return a.hovered end
      local da=(s.x-a.x)^2+(s.y-a.y)^2
      local db=(s.x-b.x)^2+(s.y-b.y)^2
      if da==db then return a.order<b.order end
      return da<db
    end)
    for j=#nearby,33,-1 do nearby[j]=nil end
    local obstructed=false
    for _,other in ipairs(nearby) do
      if Intersects(s,s.x,s.y,other,-2) then obstructed=true; break end
    end
    if obstructed then s.collisionSince=s.collisionSince or now else s.collisionSince=nil end
    if not s.hovered and (not obstructed or now-(s.collisionSince or now)>=delay) then
      local bestX,bestY=s.dx,s.dy
      local best=Penalty(s,bestX,bestY,count)
      local function Try(dx,dy)
        if math.abs(dx)>maximum*.6 or dy<0 or dy>maximum then return end
        local value=Penalty(s,dx,dy,count)
        if value<best-4 then bestX,bestY,best=dx,dy,value end
      end
      Try(0,0)
      -- Small steps toward home let labels reclaim space continuously.
      Try(s.dx*.8,s.dy*.8)
      local step=math.max(12,s.h+2)
      local side=math.min(maximum*.6,s.w*.4+(tonumber(C.sticky_column_gap) or 6))
      for row=0,math.min(6,math.ceil(maximum/step)) do
        Try(0,row*step); Try(side,row*step); Try(-side,row*step)
      end
      -- Contact candidates are exact local resolutions, not global columns.
      for _,other in ipairs(nearby) do
        if other~=s and math.abs(s.baseX-other.x)<(s.w+other.w)*.5+maximum*.6 then
          local above=other.y+(s.h+other.h)*.5+2-s.baseY-s.cy
          Try(s.dx,above); Try(0,above)
        end
      end
      s.dx,s.dy=bestX,bestY
      s.x,s.y=s.baseX+s.dx+s.cx,s.baseY+s.dy+s.cy
    end
    -- World-projection jumps reset state above. Native collision-frame jumps
    -- are deliberately ignored, even when a tall column exceeds 120 pixels.
  end
end

function Z.UpdateStickyPlacements(now,visible,shouldOverlap,targetGuid,hoverGuid,scene)
  if not scene then return UpdateStickyPlacements(now,visible,shouldOverlap,targetGuid,hoverGuid) end
  -- Dummy previews use the same solver in a separate scene, not the live
  -- registry, collision array or solve cadence.
  local previousEntries,previousSolve=entries,nextSolve
  entries,nextSolve=scene.entries or {},scene.nextSolve or 0
  local ok,result=pcall(UpdateStickyPlacements,now,visible,shouldOverlap,targetGuid,hoverGuid)
  scene.entries,scene.nextSolve=entries,nextSolve
  entries,nextSolve=previousEntries,previousSolve
  if not ok then error(result) end
  return result
end

function Z.ApplyStickyPlacement(plate,now,nativeX,nativeY,uiScale,plateScale)
  local s=plate.stickyPlacement
  if not s then return end
  local elapsed=math.max(0,math.min(.05,now-(s.renderTime or now)))
  s.renderTime=now
  local duration=math.max(.1,math.min(.6,tonumber(Z.config.nameplates.sticky_motion_duration) or .22))
  local speed=math.max(40,math.min(400,tonumber(Z.config.nameplates.sticky_motion_speed) or 140))
  local omega=2/duration
  local function Advance(position,velocity,target)
    if s.hovered then return position,0 end
    local change=position-target
    local temp=(velocity+omega*change)*elapsed
    local decay=math.exp(-omega*elapsed)
    local nextPosition=target+(change+temp)*decay
    local delta=math.max(-speed*elapsed,math.min(speed*elapsed,nextPosition-position))
    return position+delta,math.max(-speed,math.min(speed,(velocity-omega*temp)*decay))
  end
  s.displayX,s.vx=Advance(s.displayX,s.vx or 0,s.dx)
  s.displayY,s.vy=Advance(s.displayY,s.vy or 0,s.dy)
  DrawLink(plate,s,uiScale)
  -- Screen-relative; native collision movement cannot displace it mid-frame.
  -- Native-parent ownership still controls visibility and unit identity.
  return (s.baseX+s.displayX)*uiScale/plateScale,
    (s.baseY+s.displayY)*uiScale/plateScale
end
