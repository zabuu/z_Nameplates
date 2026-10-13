"""Real projection, identity validation, solver, and render lifecycle together."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates_source = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
clock=0; uiScale=.9; nativeCalls=0; guidCalls=0
units={}; objects={}; associations={}; visible={}; playerCombat=true
Z={config={nameplates={sticky_placement="1",smooth_transitions="1",vertical_offset="8",
 transition_duration=".12",sticky_delay=".05",sticky_motion_speed="140",sticky_max_displacement="96"}}}
zNameplates=Z
UIParent={GetEffectiveScale=function() return uiScale end,GetWidth=function() return 1000 end,GetHeight=function() return 800 end}
WorldFrame={GetEffectiveScale=function() return 1 end}
GetTime=function() return clock end
UnitExists=function(u) return units[u]~=nil end
UnitGUID=function(u)
 guidCalls=guidCalls+1
 return units[u] and units[u].guid
end
UnitAffectingCombat=function(u) return u=="player" and playerCombat or units[u] and units[u].combat end
UnitCanAssist=function(a,u) return units[u] and units[u].friendly end
UnitThreatSituation=function(a,u) return units[u] and units[u].threat end
UnitIsUnit=function(a,b) return a==b end
C_NamePlate={GetNamePlateForUnit=function(u) return associations[u] end}
zAPI=function(command,guid)
 if command=="version" then return 1.9 end
 assert(command=="projectNameplate")
 nativeCalls=nativeCalls+1
 local u=objects[guid]
 if not u or not u.projectable then return nil end
 return u.x/1000,u.y/800,u.depth,1,2,3
end
cfg={overlap_enemy=true,overlap_combat=true}
function add(token,guid,x,y,friendly)
 local u={guid=guid,x=x,y=y,depth=20,projectable=true,combat=true,threat=1,friendly=friendly}
 units[token]=u; objects[guid]=u
 local f={x=x+300,y=y+200,width=190,height=80,visible=true,sizeWrites=0}
 function f:GetCenter() return self.x,self.y end
 function f:GetWidth() return self.width end
 function f:GetHeight() return self.height end
 function f:SetSize(w,h) self.width=w; self.height=h; self.sizeWrites=self.sizeWrites+1 end
 function f:GetEffectiveScale() return 1 end
 function f:IsVisible() return self.visible end
 function f:EnableMouse(v) self.mouse=v end
 local p={parent=f,unit=token,cachedGuid=guid,overlapEnabled=true,scale=uiScale,isFriendly=friendly}
 function p:GetEffectiveScale() return self.scale end
 function p:GetWidth() return 120 end
 function p:GetHeight() return 25 end
 function p:ClearAllPoints() end
 function p:SetPoint(point,owner,relative,x,y) self.reference=owner; self.anchorX=x; self.anchorY=y end
 function p:SetAlpha(v) self.alpha=v end
 function p:EnableMouse(v) self.mouse=v end
 function p:IsMouseEnabled() return self.mouse end
 f.nameplate=p; associations[token]=f; visible[f]=f
 return p,u
end
function near(a,b) assert(math.abs(a-b)<.001,tostring(a).." != "..tostring(b)) end
''')
lua.execute('local Z=zNameplates\n' + core[core.index("function Z.GetPlateProjection("):core.index("Z.throttle = {}")])
lua.execute((root / "sticky.lua").read_text(encoding="utf-8-sig"))
overlap = plates_source[plates_source.index("  local function IsCombatWithPlayer("):plates_source.index("  local function ExactUnitDistance(")]
lua.execute(overlap + '\nshouldOverlap=ShouldOverlap')
# Execute the real final-alpha gate, not a parallel mock of hiding behavior.
alpha_start = plates_source.index("    local desiredAlpha = math.max")
alpha_end = plates_source.rfind("\n  end", alpha_start, plates_source.index("  local function RefreshVisibleNameplatePool("))
lua.execute('function applyAlpha(plate) local abs=math.abs; local baseAlpha,visualAlpha=1,1\n' + plates_source[alpha_start:alpha_end] + '\nend')
lua.execute('''
function step(t)
 clock=t
 Z.UpdateStickyPlacements(t,visible,shouldOverlap)
 for f in pairs(visible) do
  Z.UpdatePlateTransition(f.nameplate,t)
  applyAlpha(f.nameplate)
 end
end
function screen(p) return p.anchorX*p.scale,(p.anchorY-8)*p.scale end
solo,u=add("nameplate1","solo",400,300,false)
step(0)
local saved=solo.stickyPlacement
assert(saved and saved.avoidance and #saved.neighbors==0)
assert(solo.parent.width==1 and solo.parent.height==1 and solo.parent.mouse==false)
local x,y=screen(solo); near(x,400); near(y,300)
-- Actual combat predicate changes; native frames are resized/relocated between
-- ticks. Neither event can move or reconstruct the same-unit projected home.
for i=1,100 do
 u.threat=i%2==0 and 1 or nil
 solo.parent.width=i%2==0 and 1 or 190; solo.parent.height=i%2==0 and 80 or 1
 solo.parent.x=900+i; solo.parent.y=700+i
 step(i*.01)
 assert(solo.stickyPlacement==saved and #saved.neighbors==0)
 near(saved.dx,0); near(saved.dy,0)
 x,y=screen(solo); near(x,400); near(y,300)
end
-- Camera/world movement and UI scaling remain immediate, not mixed with
-- native frame movement or distance-dependent seed-height recalculation.
u.x=440; u.y=340; u.depth=50; solo.scale=.5
step(1.1); x,y=screen(solo); near(x,440); near(y,340)
uiScale=.8; solo.scale=.8
step(1.2); x,y=screen(solo); near(x,440); near(y,340)
-- A missing projection holds briefly, stops being an obstacle immediately,
-- then hides while keeping the same owner/state rather than native fallback.
u.projectable=false
step(1.21); assert(solo.stickyPlacement==saved and not solo.worldPlacementHidden)
solo.mouse=true
step(1.4); assert(solo.stickyPlacement==saved and solo.worldPlacementHidden and solo.alpha==0)
assert(solo.mouse==false)
assert(solo.reference==UIParent and solo.parent.width==1)
solo.parent.x=999; solo.parent.y=999; u.projectable=true
step(1.5); assert(solo.stickyPlacement==saved and not solo.worldPlacementHidden)
x,y=screen(solo); near(x,440); near(y,340)
-- Recreating a plate after a hide/toggle starts at the same world anchor.
solo.stickyPlacement=nil; solo.positionTransition=nil
step(2); x,y=screen(solo); near(x,440); near(y,340)
-- Same-unit projection jumps do not seed height from the native frame.
u.y=600; step(2.1); x,y=screen(solo); near(y,600)
-- A stale cached GUID can still resolve via zAPI, but must never be admitted.
other,v=add("nameplate2","enemy",440,600,false)
local previousCalls=nativeCalls
units.nameplate1={guid="newSlotUnit",combat=true,threat=1}
step(3)
assert(solo.stickyPlacement==nil and solo.worldPlacementHidden and solo.alpha==0)
assert(nativeCalls==previousCalls+1 and #other.stickyPlacement.neighbors==0)
-- Slot attachment mismatch is also rejected, even when its GUID matches.
units.nameplate1=u; associations.nameplate1={}
step(3.1); assert(solo.worldPlacementHidden)
-- Proper replacement clears displacement and never inherits the old unit.
associations.nameplate1=solo.parent
u.guid="replacement"; objects.replacement=u; solo.cachedGuid="replacement"; u.x=200; u.y=250
step(3.2); x,y=screen(solo); near(x,200); near(y,250)
near(solo.stickyPlacement.dx,0); near(solo.stickyPlacement.dy,0)
-- Friendlies/pets at precisely the same spot do not affect a hostile anchor.
visible={[other.parent]=other.parent}
friend=add("nameplate3","friendly",440,600,true)
pet,petUnit=add("nameplate4","petGuid",440,600,true); units.pet=petUnit
friend.overlapEnabled=false; pet.overlapEnabled=false; pet.isFriendly=nil
u.threat=1; v.threat=1
for i=1,100 do step(4+i*.01) end
assert(#other.stickyPlacement.neighbors==0)
near(other.stickyPlacement.displayX,0); near(other.stickyPlacement.displayY,0)
-- Two valid combat enemies still separate, with native stacking disabled.
enemy,w=add("nameplate5","secondEnemy",440,600,false)
for i=1,100 do step(5+i*.01) end
assert(#other.stickyPlacement.neighbors==1)
assert(other.parent.width==1 and enemy.parent.width==1)
assert(other.stickyPlacement.dx~=enemy.stickyPlacement.dx or other.stickyPlacement.dy~=enemy.stickyPlacement.dy)
-- Removing that enemy leaves no stale neighbor and returns the survivor home.
units.nameplate5=nil
for i=1,300 do step(6+i*.01) end
assert(enemy.worldPlacementHidden and enemy.stickyPlacement==nil)
assert(#other.stickyPlacement.neighbors==0)
assert(math.abs(other.stickyPlacement.displayX)<.01 and math.abs(other.stickyPlacement.displayY)<.01)
-- All validation consumers share the same sample within a rendered frame.
local reads=guidCalls
assert(Z.IsPlateUnitCurrent(other,clock)); Z.GetPlateProjection(other,clock)
assert(guidCalls==reads)
-- The world-owned renderer must not even consult native centre coordinates.
other.parent.GetCenter=function() error("Native centre reached world-owned renderer") end
step(10); x,y=screen(other); near(x,440); near(y,600)
-- Very dense scenes stop avoidance work, never switch back to native anchors.
visible={}
for i=1,101 do add("dense"..i,"denseGuid"..i,500,400,false) end
step(11)
for f in pairs(visible) do
 local p=f.nameplate
 assert(p.stickyPlacement and p.worldPlacementOwned and not p.stickyPlacement.avoidance)
 x,y=screen(p); near(x,500); near(y,400)
 assert(f.width==1 and f.height==1)
end
''')
print("Single-owner lifecycle: combat, native resizing, scaling, gaps, toggles, stale slots, pets and real collisions passed.")
