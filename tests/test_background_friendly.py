"""Actual light-friendly paths: cadence, interaction, bounded writes and lazy UI."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
core=(ROOT/'core.lua').read_text(encoding='utf-8-sig')
plates=(ROOT/'nameplates.lua').read_text(encoding='utf-8-sig')

lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={config={nameplates={}}}; zNameplates=Z; combat=false; combatReads=0
UnitAffectingCombat=function() combatReads=combatReads+1; return combat end
GetTime=function() return 1 end
p={isFriendly=true,cachedGuid="friend"}
''')
lua.execute('local Z=Z\n'+core[core.index('function Z.IsBackgroundFriendlyPlate('):core.index('local function PlateMouseFocusKind(')])
lua.execute('local Z=Z\n'+core[core.index('function Z.GetPlayerCombatState('):core.index('function Z.NextPlateDataRefresh(')])
lua.execute('''
assert(Z.IsBackgroundFriendlyPlate(p,nil,nil,1))
assert(not Z.IsBackgroundFriendlyPlate(p,"friend",nil,1))
assert(not Z.IsBackgroundFriendlyPlate(p,nil,"friend",1))
p.layoutHoverReceiver={}; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,1)); p.layoutHoverReceiver=nil
p.layoutHoverUntil=1.2; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,1)); p.layoutHoverUntil=nil
combat=true; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,2))
combat=false; p.isFriendly=false; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,3))
p.isFriendly=true; p.isDummy=true; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,3)); p.isDummy=nil
Z.config.nameplates.friendly_performance="0"; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,3))
Z.config.nameplates.friendly_performance="1"; assert(Z.IsBackgroundFriendlyPlate(p,nil,nil,3))
p.cachedGuid=nil; assert(not Z.IsBackgroundFriendlyPlate(p,nil,nil,3))
''')
print('Friendly policy: targets, hover/grace, combat, hostile units, previews and opt-out keep normal behavior.')

sample=plates[plates.index('  local function SampleExactUnitDistance('):plates.index('  local function GetUnitDepth(')]
visual=plates[plates.index('  local function ApplyDistanceEffects('):plates.index('  local function RefreshVisibleNameplatePool(')]
BOOT='''
Z={RepairPlateTextLayers=function() end}; zNameplates=Z
UIParent={GetScale=function() return 1 end}; abs=math.abs
cfg={distance_scale=true,distance_alpha=true,distance_min_scale=.5,distance_min_alpha=.4,
 distance_max_range=40,los_fade=true,distance_unitxp=true}
reads,losReads,scales,anchors,exps=0,0,0,0,0
clock=0; distance=20; sight=true
GetTime=function() return clock end; zAPI=function() end
UnitExists=function() return true end
UnitXP=function() losReads=losReads+1; return sight end
ExactUnitDistance=function() reads=reads+1; return distance end
SetLineOfSightDesaturation=function() end
Z.UpdatePlateTransition=function(p) anchors=anchors+1; p.appearanceAlpha=1 end
local exp=math.exp; math.exp=function(x) exps=exps+1; return exp(x) end
pack={}
for i=1,50 do
 local p={unit="unit"..i,cachedGuid=string.format("0x%08X",i)}
 function p:SetScale(v) scales=scales+1; self.scale=v end
 function p:SetAlpha(v) self.alpha=v end
 pack[i]=p
end
function render(t,light)
 clock=t; Z.plateRenderContext=Z.plateRenderContext or {}
 local c=Z.plateRenderContext; c.active=true; c.now=t; c.ui=UIParent; c.baseScale=1
 for _,p in ipairs(pack) do p.backgroundFriendly=light; apply(p,t,1) end
 c.active=false
end
'''


def visual_runtime(source=plates):
    vm=LuaRuntime(unpack_returned_tuples=True)
    vm.execute(BOOT)
    sampling=source[source.index('  local function SampleExactUnitDistance('):source.index('  local function GetUnitDepth(')]
    effects=source[source.index('  local function ApplyDistanceEffects('):source.index('  local function RefreshVisibleNameplatePool(')]
    vm.execute(sampling+'\n_G.SampleExactUnitDistance=SampleExactUnitDistance')
    vm.execute(effects+'\napply=ApplyDistanceEffects')
    return vm


totals=[]
for light in (False,True):
    vm=visual_runtime()
    vm.execute('render(0,'+str(light).lower()+')')
    vm.execute('for i=1,600 do render(i/60,'+str(light).lower()+') end')
    totals.append({k:vm.globals()[k] for k in ('reads','losReads','scales','anchors','exps')})
normal,light=totals
assert .49<light['reads']/normal['reads']<.52,totals
assert .49<light['losReads']/normal['losReads']<.53,totals
assert normal['anchors']==light['anchors']==50*601
assert light['exps']<=600 and normal['exps']<=600,totals
print('50 plates / 10 s: distance reads %d -> %d; LOS reads %d -> %d; all %d render anchors retained; <=600 shared blends.' %
      (normal['reads'],light['reads'],normal['losReads'],light['losReads'],light['anchors']))

baseline=ROOT.parent/'_pfUIFreezeFix/backups/2026-10-18-background-friendly-2.1.2/nameplates.lua'
if baseline.is_file():
    vm=visual_runtime(baseline.read_text(encoding='utf-8-sig'))
    vm.execute('render(0,true); for i=1,600 do render(i/60,true) end')
    assert vm.globals().exps==30000 and light['exps']<=600, (vm.globals().exps,light['exps'])
    print('Preserved 2.1.2 / 50 plates / 600 frames: 30,000 blend exponentials -> %d, with the same render cadence.' % light['exps'])

vm=visual_runtime()
vm.execute('''
render(0,true); render(.05,true)
local d,l=reads,losReads
-- Acquiring a target/hover/entering combat invalidates both slow samplers now.
render(.051,false); assert(reads==d+50 and losReads==l+50)
local p=pack[1]; local scale=p.scale
distance=35; render(.07,false); render(.11,false)
assert(p.scale<scale and p.scale>.5)
local old=p.scale; local a=anchors; render(.115,false)
assert(p.scale<old and anchors==a+50) -- Animation still runs between samples.
-- Friendly scale jitter has a bounded error; returning to normal restores precision.
for i=1,120 do
 distance=20+math.sin(i)*.001; render(1+i/60,true)
 for _,p in ipairs(pack) do assert(math.abs(p.scale-p.distanceScale)<=.00025) end
end
local d,l=reads,losReads
local oldAPI=UnitXP; UnitXP=function(...) return oldAPI(unpack(arg)) end
render(3.001,true); assert(reads==d+50 and losReads==l+50)
p.cachedGuid="recycled"; render(3.002,true)
assert(p.distanceScaleIdentity=="recycled" and p.distanceSample.identity=="recycled")
''')
print('Sampler upgrades/API swaps/recycling are immediate; smooth scale updates and subpixel error bounds passed.')

# Real world-owned transition applies subpixel hysteresis only to background friends.
vm=LuaRuntime(unpack_returned_tuples=True)
vm.execute('''
Z={config={nameplates={smooth_transitions="0",vertical_offset="0"}}}
UIParent={GetEffectiveScale=function() return 1 end}
home=100; writes=0
p={unit="friend",cachedGuid="friend",parent={},worldPlacementOwned=true,backgroundFriendly=true}
function p:GetEffectiveScale() return 1 end
function p:ClearAllPoints() end
function p:SetPoint(a,b,c,x,y) self.x=x; self.y=y; writes=writes+1 end
Z.ApplyStickyPlacement=function() return home,100 end
''')
vm.execute('local Z=Z\n'+core[core.index('function Z.UpdatePlateTransition('):core.index('Z.throttle = {}')])
vm.execute('''
for i=1,120 do
 home=100+math.sin(i)*.02; Z.UpdatePlateTransition(p,i/60)
 assert(math.abs(p.x-home)<=.05)
end
assert(writes==1)
p.backgroundFriendly=false
Z.UpdatePlateTransition(p,3); assert(math.abs(p.x-home)<=.001)
home=103; Z.UpdatePlateTransition(p,3.01); assert(p.x==home)
p.backgroundFriendly=true; p.cachedGuid="new"
home=104; Z.UpdatePlateTransition(p,3.02); assert(p.x==home)
''')
print('Background anchor jitter: 120 tiny motions -> 1 native write; target precision, real motion and recycling remain immediate.')

# Exercise actual lazy widget creation and actual combo display block.
ensure=plates[plates.index('  nameplates.EnsureComboPoints = function('):plates.index('  nameplates.OnConfigChange = function(')]
combo=plates[plates.index('    if target and C.nameplates.cpdisplay == "1" then'):plates.index('    -- update debuffs',plates.index('    if target and C.nameplates.cpdisplay == "1" then'))]
vm=LuaRuntime(unpack_returned_tuples=True)
vm.execute('''
frames=0; nameplates={}; C={nameplates={cpdisplay="1"}}; border=1; cp=0
GetBorderSize=function() return 1,border end
GetComboPoints=function() return cp end
function CreateFrame(_,_,parent)
 frames=frames+1
 local f={parent=parent}
 function f:Hide() self.shown=false end
 function f:SetShown(v) self.shown=v end
 function f:SetFrameLevel(v) self.level=v end
 function f:SetSize(w,h) self.width=w; self.height=h end
 function f:SetPoint(...) self.point={...} end
 function f:CreateTexture()
  return {SetAllPoints=function() end,SetTexture=function(self,...) self.color={...} end}
 end
 return f
end
CreateBackdrop=function(f) if not f.backdrop then f.backdrop=CreateFrame("Frame",nil,f) end end
pack={}; for i=1,50 do pack[i]={combopoints={},health={}} end
''')
vm.execute(ensure+'\nfunction updateCombo(plate,target)\n'+combo+'\nend')
vm.execute('''
for i=1,120 do for _,p in ipairs(pack) do updateCombo(p,true) end end
assert(frames==0)
local p=pack[1]; cp=3; updateCombo(p,true)
assert(frames==10 and p.layersDirty)
for i=1,5 do assert(p.combopoints[i].shown==(i<=3)) end
cp=5; updateCombo(p,true); assert(frames==10 and p.combopoints[5].shown)
cp=1; updateCombo(p,true); assert(not p.combopoints[2].shown)
border=2; nameplates.EnsureComboPoints(p); assert(frames==10)
assert(p.combopoints[1].point[5]==-6 and p.combopoints[1].width==5)
updateCombo(p,false); for i=1,5 do assert(not p.combopoints[i].shown) end
''')
print('50 unused combo displays: 500 native frames avoided; first use, point changes, config and hide restore the existing display.')
