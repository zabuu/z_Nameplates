-- Stable screen-space displacement; world/camera movement stays immediate.
local Z = zNameplates
local sequence = 0
local nextSolve = 0
local entries = {}
local avoidanceEntries = {}
local identities = {}

local function AvoidanceOrder(a,b)
  if a.hovered~=b.hovered then return a.hovered end
  return a.order<b.order
end

local function NeighborOrder(state)
  -- Own the comparator with the placement state, not a mutable global sort
  -- context. Read current coordinates: the solver moves entries in-place.
  return function(a,b)
    if a.hovered~=b.hovered then return a.hovered end
    local da=(state.x-a.x)^2+(state.y-a.y)^2
    local db=(state.x-b.x)^2+(state.y-b.y)^2
    if da==db then return a.order<b.order end
    return da<db
  end
end

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
      if (object.IsVisible and not object:IsVisible()) or (object.GetAlpha and object:GetAlpha()==0) then return end
      if object.GetText then local text=object:GetText(); if not text or text=="" then return end end
      local l,r,t,b=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
      if not l or not r or not t or not b then return end
      -- FontStrings/Textures are Regions, not Frames: on 1.12 they do not
      -- expose GetEffectiveScale. Their coordinates belong to their parent
      -- frame, including the quarter-scale smooth-font surface. Falling back
      -- to the whole plate scale made those boxes four times too large.
      local owner=object.GetParent and object:GetParent()
      if owner and owner.GetAlpha and owner:GetAlpha()==0 then return end
      local effective=object.GetEffectiveScale and object:GetEffectiveScale()
        or owner and owner.GetEffectiveScale and owner:GetEffectiveScale()
        or plate:GetEffectiveScale()
      local k=effective/ui
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
  local link=plate.layoutAnchorLink
  if link and link:IsShown() then link:Hide() end
end

local function DrawLink(plate,s,uiScale)
  local C=Z.config.nameplates
  if plate.worldPlacementHidden or s.projectionMissing or C.sticky_anchor_link=="0" or not (s.hovered or plate.istarget)
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
  local scale=uiScale/plate.parent:GetEffectiveScale()
  if math.abs(link:GetScale()-scale)>.000001 then link:SetScale(scale) end
  local strata,level=plate:GetFrameStrata(),math.max(0,plate:GetFrameLevel()-1)
  if link:GetFrameStrata()~=strata then link:SetFrameStrata(strata) end
  if link:GetFrameLevel()~=level then link:SetFrameLevel(level) end
  for i,dot in ipairs(link.dots) do
    local t=i/13
    local x,y=s.baseX+s.displayX*t,s.baseY+s.displayY*t
    if not dot.znpAnchorX or math.abs(x-dot.znpAnchorX)>.001 or math.abs(y-dot.znpAnchorY)>.001 then
      dot:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
      dot.znpAnchorX,dot.znpAnchorY=x,y
    end
  end
  if not link:IsShown() then link:Show() end
end

local function UpdateStickyPlacements(now, visible, shouldOverlap, targetGuid, hoverGuid)
  local C = Z.config.nameplates
  local enabled = C.sticky_placement == "1" and type(zAPI) == "function"
  local ui = UIParent:GetEffectiveScale()
  local uiWidth,uiHeight=UIParent:GetWidth(),UIParent:GetHeight()
  local bufferX=math.max(0,math.min(40,tonumber(C.collision_buffer_x) or 0))
  local bufferY=math.max(0,math.min(40,tonumber(C.collision_buffer_y) or 0))
  local petGuid=UnitExists and UnitGUID and UnitExists("pet") and UnitGUID("pet")
  local count = 0
  for identity in pairs(identities) do identities[identity]=nil end
  for parent in pairs(visible) do
    local plate = parent.nameplate
    local identity = plate and (plate.cachedGuid or plate.unit)
    local sx, sy, depth
    local current=plate and Z.IsPlateUnitCurrent(plate,now)
    local eligible = enabled and current and identity and parent:IsVisible() and not plate.clusterHidden and not identities[identity]
    local allowsOverlap = plate and shouldOverlap(plate)
    if plate then
      plate.worldPlacementOwned=enabled
      plate.worldPlacementHidden=enabled and not current or nil
      if enabled then Z.ReleasePlateNativeCollision(plate) end
    end
    if eligible then
      sx, sy, depth = Z.GetPlateProjection(plate, now)
    end
    if type(sx) ~= "number" or type(sy) ~= "number" or type(depth) ~= "number"
        or sx~=sx or sy~=sy or depth~=depth or depth <= 0 or ui <= 0 then
      local previous=plate and plate.stickyPlacement
      -- Keep the same coordinate owner through projection gaps. A stale
      -- sample is never an obstacle; briefly hold it, then hide, not fallback.
      if eligible and previous and previous.identity==identity then
        previous.projectionMissing=true
        previous.avoidance=false
        if previous.neighbors then for j=#previous.neighbors,1,-1 do previous.neighbors[j]=nil end end
        plate.worldPlacementHidden=now-previous.last>.12
        HideLink(plate)
      elseif plate then
        plate.stickyPlacement=nil
        plate.worldPlacementHidden=enabled and current and not plate.clusterHidden or plate.worldPlacementHidden
        HideLink(plate)
      end
    else
      if eligible then
        sx, sy = sx*uiWidth, sy*uiHeight
        local s = plate.stickyPlacement
        if not s or s.identity ~= identity then
          sequence = sequence+1
          s = {identity=identity,order=sequence,biasX=0,by=0,dx=0,dy=0,displayX=0,displayY=0,vx=0,vy=0,depth=depth}
          plate.stickyPlacement = s
        elseif math.abs(sx-s.sx)>160 or math.abs(sy-s.sy)>160 then
          -- A real camera/world jump may reset avoidance, never home height.
          s.dx,s.dy,s.displayX,s.displayY,s.vx,s.vy=0,0,0,0,0,0
        end
        s.baseX,s.baseY=sx,sy
        s.projectionMissing=nil
        s.avoidance=not allowsOverlap
        plate.worldPlacementHidden=nil
        s.sx, s.sy, s.last = sx, sy, now
        s.plate = plate
        local scale = plate:GetEffectiveScale()/ui
        if not s.contentW or (s.avoidance and now>=nextSolve) then
          s.contentW,s.contentH,s.cx,s.cy=Measure(plate,ui)
        end
        s.w,s.h=s.contentW+bufferX*2*scale,s.contentH+bufferY*2*scale
        s.priority = identity==targetGuid or identity==hoverGuid
        s.hovered=C.sticky_hover_protection~="0" and (plate.layoutHoverReceiver~=nil or
          (plate.layoutHoverUntil and now<plate.layoutHoverUntil)) or false
        if s.hovered and s.avoidance and not s.returningHome then
          s.dx,s.dy=s.displayX,s.displayY; s.vx,s.vy=0,0
        end
        s.x,s.y = s.baseX+s.dx+s.cx,s.baseY+s.dy+s.cy
        count=count+1; entries[count]=s
        identities[identity]=true
      elseif plate then
        plate.stickyPlacement=nil; HideLink(plate)
      end
    end
    if plate and plate.worldPlacementHidden then
      if plate.EnableMouse and (not plate.IsMouseEnabled or plate:IsMouseEnabled()) then plate:EnableMouse(false) end
      if Z.ClearPlateMouseover then Z.ClearPlateMouseover(plate) end
      if plate.layoutHoverReceiver then Z.SetPlateLayoutHover(plate,plate.layoutHoverReceiver,false,true) end
    end
  end
  for i=#entries,count+1,-1 do entries[i]=nil end
  -- Friendly labels (including pets and passive neutrals) are a separate
  -- collision scene. Even a friendly fighting our target must not push that
  -- enemy's plate off its anchor. Update on grace samples as well as fresh ones.
  local avoidanceCount=0
  for i=1,count do
    local s=entries[i]
    local plate=s.plate
    s.collisionFamily=(plate.isFriendly or (petGuid and s.identity==petGuid)
      or (plate.isNeutral and not plate.neutralProvoked)) and "friendly" or "hostile"
    if s.avoidance then
      avoidanceCount=avoidanceCount+1; avoidanceEntries[avoidanceCount]=s
    else
      -- Town labels allowed to overlap still track their world anchors, but
      -- are neither obstacles nor solver clients. Release old displacement
      -- targets immediately; the normal render damping brings them home.
      s.dx,s.dy=0,0
      s.x,s.y=s.baseX+s.cx,s.baseY+s.cy
      s.returningHome=true; s.collisionSince=nil
      if s.neighbors then for j=#s.neighbors,1,-1 do s.neighbors[j]=nil end end
    end
  end
  for i=#avoidanceEntries,avoidanceCount+1,-1 do avoidanceEntries[i]=nil end
  if avoidanceCount==0 then return end
  -- Bound avoidance work without surrendering anchoring to native stacking.
  if count>100 then
    for i=1,count do
      local s=entries[i]; s.avoidance=false; s.dx,s.dy=0,0; s.returningHome=true
      if s.neighbors then for j=#s.neighbors,1,-1 do s.neighbors[j]=nil end end
      HideLink(s.plate)
    end
    return
  end
  if now<nextSolve then return end
  nextSolve=now+.05
  table.sort(avoidanceEntries,AvoidanceOrder)
  local delay = math.max(.05,math.min(.5,tonumber(C.sticky_delay) or .15))
  local maximum=math.max(32,math.min(180,tonumber(C.sticky_max_displacement) or 96))
  for i=1,avoidanceCount do
    local s=avoidanceEntries[i]
    local nearby=s.neighbors or {}; s.neighbors=nearby
    local n=0
    for j=1,avoidanceCount do
      local other=avoidanceEntries[j]
      if s.avoidance and other.avoidance and other~=s and other.collisionFamily==s.collisionFamily
          and math.abs(s.baseX+s.cx-other.x)<(s.w+other.w)*.5+maximum
          and math.abs(s.baseY+s.cy-other.y)<(s.h+other.h)*.5+maximum*2 then
        n=n+1; nearby[n]=other
      end
    end
    for j=#nearby,n+1,-1 do nearby[j]=nil end
    s.neighborOrder=s.neighborOrder or NeighborOrder(s)
    table.sort(nearby,s.neighborOrder)
    for j=#nearby,33,-1 do nearby[j]=nil end
    -- Hover ownership can persist as a crowd disappears (including native
    -- frames that fail to send Leave). It must not pin a lone plate forever
    -- at a former avoidance slot. Allow a short click grace, then ease home.
    if n==0 then s.homeClearSince=s.homeClearSince or now
    else s.homeClearSince=nil end
    s.returningHome=not s.avoidance or (s.homeClearSince~=nil and now-s.homeClearSince>=.35)
    local obstructed=false
    for _,other in ipairs(nearby) do
      if Intersects(s,s.x,s.y,other,-2) then obstructed=true; break end
    end
    if obstructed then s.collisionSince=s.collisionSince or now else s.collisionSince=nil end
    if s.returningHome then
      s.dx,s.dy=0,0
      s.x,s.y=s.baseX+s.cx,s.baseY+s.cy
    elseif not s.hovered and (not obstructed or now-(s.collisionSince or now)>=delay) then
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

local function Advance(position,velocity,target,elapsed,omega,speed,decay)
  local change=position-target
  local temp=(velocity+omega*change)*elapsed
  local nextPosition=target+(change+temp)*decay
  local delta=math.max(-speed*elapsed,math.min(speed*elapsed,nextPosition-position))
  position=position+delta
  velocity=math.max(-speed,math.min(speed,(velocity-omega*temp)*decay))
  -- Settle below a thousandth of a UI pixel instead of integrating infinitesimal
  -- tails forever. Share this helper rather than allocating a closure per plate.
  if math.abs(position-target)<.001 and math.abs(velocity)<.01 then return target,0 end
  return position,velocity
end

function Z.ApplyStickyPlacement(plate,now,nativeX,nativeY,uiScale,plateScale)
  local s=plate.stickyPlacement
  if not s then return end
  local elapsed=math.max(0,math.min(.05,now-(s.renderTime or now)))
  s.renderTime=now
  if s.hovered and s.avoidance and not s.returningHome then
    s.vx,s.vy=0,0
  elseif s.displayX~=s.dx or s.displayY~=s.dy or (s.vx or 0)~=0 or (s.vy or 0)~=0 then
    local duration=math.max(.1,math.min(.6,tonumber(Z.config.nameplates.sticky_motion_duration) or .22))
    local speed=math.max(40,math.min(400,tonumber(Z.config.nameplates.sticky_motion_speed) or 140))
    if s.returningHome and s.hovered then speed=speed*.4 end
    local omega=2/duration
    local decay=math.exp(-omega*elapsed)
    s.displayX,s.vx=Advance(s.displayX,s.vx or 0,s.dx,elapsed,omega,speed,decay)
    s.displayY,s.vy=Advance(s.displayY,s.vy or 0,s.dy,elapsed,omega,speed,decay)
  end
  DrawLink(plate,s,uiScale)
  -- Screen-relative; native collision movement cannot displace it mid-frame.
  -- Native-parent ownership still controls visibility and unit identity.
  return (s.baseX+s.displayX)*uiScale/plateScale,
    (s.baseY+s.displayY)*uiScale/plateScale
end
