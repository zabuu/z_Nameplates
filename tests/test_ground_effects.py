"""Run real ground marker discovery, trigger, expiry and pooling lifecycle."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
tree = ast.parse((root / "tests/test_plate_chat.py").read_text(encoding="utf-8-sig"))
bootstrap = next(ast.literal_eval(n.value.args[0]) for n in tree.body
                 if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
                 and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(bootstrap)
core = (root / "core.lua").read_text(encoding="utf-8-sig")
lua.execute('local Z=zNameplates\n' + core[core.index("function Z.NormalizeWorldProjection("):core.index("function Z.GetPlayerWorldPosition(")])
lua.execute('''
local methods=getmetatable(UIParent).__index
function methods:SetAllPoints() end
function methods:SetTexCoord() end
function methods:SetShadowColor() end
function methods:SetShadowOffset() end
fontWrites=0
function methods:SetFont(...) self.font={...}; fontWrites=fontWrites+1 end
Z=zNameplates
WorldFrame=CreateFrame("Frame")
Z.config.groundeffects={enabled="1",traps="1",flares="1",size="22",opacity=".45",fontsize="11",height=".35",scale="1"}
nativeObjects={}; scans=0; states=0; cameraVisible=true; projectionX=.5; projectionY=.4
zAPI=function(command,a,b,c)
 if command=="groundObjectVersion" then return 1 end
 if command=="groundObject" then
  scans=scans+1
  for guid,o in pairs(nativeObjects) do
   if guid~=c and o.kind==a and o.id==b then return guid,o.x,o.y,o.z,o.kind,o.id,1 end
  end
 elseif command=="groundObjectState" then
  states=states+1; local o=nativeObjects[a]
  if o then return a,o.x,o.y,o.z,o.kind,o.id,1 end
 elseif command=="worldToScreen" then
  return cameraVisible and projectionX or 1.2,projectionY,20
 end
end
GetSpellDuration=function(id) return id==3355 and 10000 or id==13810 and 30000 or id==1543 and 30000 or 60000 end
GetSpellRecField=function(id,key) assert(key=="effectMiscValue"); return {id+100000,0,0} end
function groundEvent(name,...)
 event=name; arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8=unpack(arg)
 this=zNameplatesGroundEffects; this.scripts.OnEvent()
end
function groundTick(time)
 clock=time; this=zNameplatesGroundEffects; this.scripts.OnUpdate()
end
function spawn(guid,kind,id,x,y,z) nativeObjects[guid]={kind=kind,id=id,x=x,y=y,z=z} end
function count() return table.getn(Z.groundEffectRecords) end
''')
lua.execute((root / "groundeffects.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
assert(not zNameplatesGroundEffects:IsShown() and scans==0)
groundEvent("SPELL_GO_SELF",0,999,"0x01")
assert(count()==0 and scans==0)
-- Wait for a confirmed, player-owned trap object before displaying anything.
groundEvent("SPELL_GO_SELF",0,1499,"0x01")
groundTick(0); assert(count()==1 and not Z.groundEffectRecords[1].frame)
spawn("trap1",5,101499,12,24,5)
groundTick(.11)
local r=Z.groundEffectRecords[1]; local frame=r.frame
assert(r.guid=="trap1" and r.x==12 and r.y==24 and r.z==5)
assert(frame:IsShown() and frame.mouse==false and frame.icon.alpha==.45)
assert(frame.timer:GetEffectiveAlpha()==1 and r.expires==60 and r.phase=="armed")
groundEvent("AURA_CAST_ON_OTHER",3355,"otherHunter","victim",0,0,0,0,10000)
assert(r.phase=="armed")
clock=1; groundEvent("AURA_CAST_ON_OTHER",3355,"0x01","victim",0,0,0,0,10000)
assert(r.phase=="active" and r.expires==11)
nativeObjects.trap1=nil; groundTick(2)
assert(count()==1 and r.x==12 and frame:IsShown())
clock=3; groundEvent("AURA_CAST_ON_OTHER",3355,"0x01","victim",0,0,0,0,10000)
assert(r.expires==11) -- Duplicate aura effects never restart the timer.
groundEvent("DEBUFF_REMOVED_OTHER","differentVictim",0,3355)
assert(count()==1)
groundEvent("DEBUFF_REMOVED_OTHER","victim",0,3355,0,0,0,2)
assert(count()==1) -- A stack update is not a removed aura.
groundEvent("DEBUFF_REMOVED_OTHER","victim",0,3355,0,0,0,1)
groundTick(3.1); assert(count()==0 and not frame:IsShown())
-- Flare uses its actual destination, not the caster or current cursor.
clock=4; spawn("flare1",6,1543,70,80,10)
groundEvent("SPELL_GO_SELF",0,1543,"0x01"); groundTick(4)
r=Z.groundEffectRecords[1]
assert(r.frame==frame and r.x==70 and r.y==80 and r.expires==34)
assert(string.find(frame.icon.texture,"Flare"))
-- Ground icons use the same WorldFrame -> UIParent mapping as real plates.
-- Icon scale is independent: changing either scale cannot move the anchor.
for _,ui in ipairs({.64,.8,.9,1,1.1}) do
 for _,world in ipairs({.8,1}) do
  for _,icon in ipairs({.75,1,1.4}) do
   UIParent:SetScale(ui); WorldFrame:SetScale(world); Z.config.groundeffects.scale=tostring(icon)
   groundTick(clock+.00001)
   assert(frame:IsShown())
   assert(math.abs(frame.point[4]-projectionX*world/ui*UIParent:GetWidth()/icon)<.000001)
   assert(math.abs(frame.point[5]-projectionY*world/ui*UIParent:GetHeight()/icon)<.000001)
  end
 end
end
-- Clip after normalization, not against the raw WorldFrame range.
UIParent:SetScale(.8); WorldFrame:SetScale(1); projectionX=.81
groundTick(clock+.00001); assert(not frame:IsShown())
projectionX=.79; groundTick(clock+.00001); assert(frame:IsShown())
UIParent:SetScale(1); projectionX=.5; Z.config.groundeffects.scale="1"
groundTick(clock+.00001)
local before=fontWrites; local beforeStates=states; local beforeScans=scans
for i=1,60 do groundTick(4+i/120) end
assert(fontWrites==before and scans==beforeScans and states-beforeStates<=3)
cameraVisible=false; groundTick(4.6); assert(not frame:IsShown() and count()==1)
cameraVisible=true; groundTick(4.7); assert(frame:IsShown())
Z.config.groundeffects.opacity=".3"; Z.config.groundeffects.size="28"; groundTick(4.8)
assert(frame.icon.alpha==.3 and frame.width==28 and frame.timer:GetEffectiveAlpha()==1)
clock=5; groundEvent("SPELL_GO_SELF",0,1543,"0x01")
groundTick(5); assert(count()==2 and not Z.groundEffectRecords[2].frame)
spawn("flare2",6,1543,100,200,3); groundTick(5.11)
assert(Z.groundEffectRecords[2].guid=="flare2")
-- Early despawn clears after a short event-order grace, not a fake trigger.
nativeObjects.flare2=nil; groundTick(5.4); groundTick(6.1)
assert(count()==1)
groundTick(34.1); assert(count()==0)
-- Replacement is confirmed before the preceding armed trap disappears.
clock=40; spawn("trap2",5,101499,1,2,3)
groundEvent("SPELL_GO_SELF",0,1499,"0x01"); groundTick(40)
clock=41; groundEvent("SPELL_GO_SELF",0,13809,"0x01"); groundTick(41)
assert(count()==2 and Z.groundEffectRecords[1].frame:IsShown())
spawn("frost",5,113809,4,5,6); groundTick(41.2)
assert(count()==1 and Z.groundEffectRecords[1].kind=="frost")
groundEvent("AURA_CAST_ON_OTHER",13810,"0x01","victim",0,0,0,0,30000)
r=Z.groundEffectRecords[1]; assert(r.phase=="active")
groundEvent("DEBUFF_REMOVED_OTHER","victim",0,13810)
assert(count()==1) -- A target leaves the slow; the frost patch remains.
groundEvent("PLAYER_ENTERING_WORLD"); assert(count()==0)
-- The live Frost Trap failure: the GO vanishes, but no usable trigger cast or
-- aura event arrives. Keep the very same frame and world position across the
-- handoff to the owned dynamic ice field (not an older Frost Trap elsewhere).
nativeObjects={}; clock=50
spawn("frostArmed",5,113809,9,11,4)
groundEvent("SPELL_GO_SELF",0,13809,"0x01"); groundTick(50)
r=Z.groundEffectRecords[1]; frame=r.frame
assert(r.phase=="armed" and frame:IsShown())
nativeObjects.frostArmed=nil
spawn("olderIceField",6,13810,80,90,4)
groundTick(50.3)
assert(r.phase=="armed" and frame:IsShown() and not r.fieldGuid)
spawn("ownIceField",6,13810,9,11,4); groundTick(50.6)
assert(r.phase=="active" and r.fieldGuid=="ownIceField" and r.frame==frame)
assert(r.x==9 and r.y==11 and r.z==4 and frame:IsShown())
assert(math.abs(r.expires-80.3)<.000001)
local fieldExpiry=r.expires
clock=51; groundEvent("AURA_CAST_ON_OTHER",13810,"0x01","victim",0,0,0,0,6000)
groundEvent("DEBUFF_REMOVED_OTHER","victim",0,13810,0,0,0,1)
assert(r.expires==fieldExpiry and count()==1)
local fieldScans=scans
for i=1,60 do groundTick(51+i/120) end
assert(scans==fieldScans and r.fieldGuid=="ownIceField") -- Direct lookups after binding.
nativeObjects.ownIceField=nil; spawn("otherFieldSamePlace",6,13810,9,11,4)
groundTick(52); groundTick(52.8)
assert(count()==0 and not frame:IsShown()) -- Never rebind a vanished field.
-- Missing without a field is still a real despawn, not a fabricated trigger.
nativeObjects={}; clock=60; spawn("frostCancelled",5,113809,1,2,3)
groundEvent("SPELL_GO_SELF",0,13809,"0x01"); groundTick(60)
nativeObjects.frostCancelled=nil; groundTick(60.3); groundTick(60.8)
assert(count()==1 and Z.groundEffectRecords[1].phase=="armed")
groundTick(61.6); assert(count()==0)
-- A short individual slow does not truncate the full field duration.
clock=70; spawn("frostAura",5,113809,1,2,3)
groundEvent("SPELL_GO_SELF",0,13809,"0x01"); groundTick(70)
groundEvent("AURA_CAST_ON_OTHER",13810,"0x01","victim",0,0,0,0,6000)
assert(Z.groundEffectRecords[1].expires==100)
groundEvent("PLAYER_ENTERING_WORLD"); assert(count()==0)
clock=75; groundEvent("SPELL_GO_SELF",0,1499,"0x01"); groundTick(75)
Z.config.groundeffects.enabled="0"; Z.RefreshGroundEffects()
assert(count()==0 and not zNameplatesGroundEffects:IsShown())
Z.config.groundeffects.enabled="1"; zAPI=function() return nil end
groundEvent("SPELL_GO_SELF",0,1543,"0x01"); assert(count()==0)
''')
print("Ground timers: UI/icon scale and clipping, exact owned objects, persistent Frost handoff, field lifetime, no rebinding/scans while active, expiry, pooling and live settings passed.")
