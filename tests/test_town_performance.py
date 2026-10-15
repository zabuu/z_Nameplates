"""Count real town update paths; preserve world motion, repairs and smooth scale."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
sticky = (root / "sticky.lua").read_text(encoding="utf-8-sig")


def bootstrap(filename):
    tree = ast.parse((root / "tests" / filename).read_text(encoding="utf-8-sig"))
    return next(ast.literal_eval(n.value.args[0]) for n in tree.body
                if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
                and isinstance(n.value.func, ast.Attribute) and n.value.func.attr == "execute")


identity = core[core.index("function Z.IsPlateUnitCurrent("):
                core.index("-- zAPI projects in the native WorldFrame")]
neighbor_loop = "    for j=1,avoidanceCount do\n"
assert sticky.count(neighbor_loop) == 1
instrumented = sticky.replace(neighbor_loop, neighbor_loop + "      comparisons=comparisons+1\n")
for size in (50, 100, 150):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(bootstrap("test_sticky_placement.py"))
    lua.execute("local Z=zNameplates\n" + identity)
    lua.execute('''
comparisons=0; projections=0
local original=Z.GetPlateProjection
Z.GetPlateProjection=function(...) projections=projections+1; return original(...) end
''')
    lua.execute(instrumented)
    lua.execute(f'''
visible={{}}; pack={{}}
for i=1,{size} do pack[i]=add("town"..i,200,100); pack[i].isFriendly=true end
function townUpdate(t)
 clock=t; Z.UpdateStickyPlacements(t,visible,function(p) return p.isFriendly end)
end
townUpdate(1)
assert(comparisons==0 and projections=={size})
for _,p in ipairs(pack) do assert(p.worldPlacementOwned and not p.stickyPlacement.avoidance) end
-- Camera/world motion still updates on an intervening render frame.
local state=pack[1].stickyPlacement
pack[1].px=205; pack[1].py=106
townUpdate(1.001)
assert(projections=={size}*2 and state.baseX==205 and state.baseY==106)
-- Returning from combat to overlap releases targets, never the world owner.
state.dx=-20; state.displayX=-20; state.dy=30; state.displayY=30
townUpdate(1.002)
assert(state.dx==0 and state.dy==0 and state.displayX==-20 and state.returningHome)
assert(pack[1].worldPlacementOwned and comparisons==0)
''')
    if size <= 100:
        lua.execute('''
-- Fifty/eighty friendly bystanders are not searched as obstacles for two mobs.
pack[1].isFriendly=false; pack[2].isFriendly=false
local before=comparisons; townUpdate(2)
assert(comparisons-before==4)
assert(pack[1].stickyPlacement.avoidance and pack[2].stickyPlacement.avoidance)
pack[1].isFriendly=true; pack[2].isFriendly=true
before=comparisons; townUpdate(2.01)
local state=pack[1].stickyPlacement
assert(comparisons==before and #state.neighbors==0 and state.returningHome)
''')

# The actual layer implementation skips hidden child trees until dirty/audited.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(bootstrap("test_plate_layers.py"))
lua.execute('''
local methods=getmetatable(plate).__index
local strata,level=methods.GetFrameStrata,methods.GetFrameLevel
auraReads=0
function methods:GetFrameStrata() if self.auraMarker then auraReads=auraReads+1 end return strata(self) end
function methods:GetFrameLevel() if self.auraMarker then auraReads=auraReads+1 end return level(self) end
plate.debuffs[1].auraMarker=true; plate.debuffs[1].cd.auraMarker=true
''')
lua.execute((root / "layers.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
Z=zNameplates
Z.ApplyPlateLayers(plate,"LOW",10,1)
assert(auraReads>0); auraReads=0
local before=writes
for i=1,30 do Z.ApplyPlateLayers(plate,"LOW",10,1+i*.01) end
assert(auraReads==0 and writes==before)
-- Newly created auras request the full repair before the audit deadline.
plate.debuffs[2]=frame(plate); plate.debuffs[2].backdrop=frame(plate.debuffs[2])
plate.layersDirty=true
Z.ApplyPlateLayers(plate,"LOW",10,1.31)
assert(plate.debuffs[2].layerLevel==14 and plate.debuffs[2].backdrop.layerLevel==13)
assert(not plate.layersDirty)
-- A client root reset cannot wait for a timed audit.
native:SetFrameStrata("BACKGROUND"); native:SetFrameLevel(0)
Z.ApplyPlateLayers(plate,"LOW",10,1.32)
assert(native.strata=="LOW" and native.layerLevel==10 and plate.health.layerLevel==13)
assert(plate.debuffs[2].layerLevel==14)
-- Child-only external changes get a bounded full audit; text keeps its fast guard.
plate.debuffs[2].layerLevel=0; plate.name.zSmoothFrame.layerLevel=0
Z.ApplyPlateLayers(plate,"LOW",10,1.49)
assert(plate.name.zSmoothFrame.layerLevel==19)
Z.ApplyPlateLayers(plate,"LOW",10,1.51)
assert(plate.debuffs[2].layerLevel==14)
plate.debuffs[2].layerLevel=0
Z.ApplyPlateLayers(plate,"LOW",10) -- Explicit config/creation calls remain immediate.
assert(plate.debuffs[2].layerLevel==14)
''')
assert "plate.layersDirty = true" in plates[plates.index("local function CreateDebuffIcon("):]
assert "nameplate.layersDirty = true" in plates[plates.index("local function UpdateDebuffConfig("):]

# Sample the real distance cache, including failures and identity/API changes.
lua = LuaRuntime(unpack_returned_tuples=True)
sample = plates[plates.index("  local function SampleExactUnitDistance("):
                plates.index("  local function GetUnitDepth(")]
lua.execute('''
reads=0; distances={}; zAPI=function() end
ExactUnitDistance=function(unit,now) reads=reads+1; return distances[unit] end
''')
lua.execute(sample + "\nsampleDistance=SampleExactUnitDistance")
lua.execute('''
pack={}
for i=1,50 do
 local unit="plate"..i; distances[unit]=i
 pack[i]={unit=unit,cachedGuid=string.format("0x%08X",i)}
end
for frame=0,119 do
 for _,p in ipairs(pack) do assert(sampleDistance(p,frame/120)==distances[p.unit]) end
end
assert(reads>=950 and reads<=1050) -- Not 6,000 reads at 120 FPS.
local phases={}
for _,p in ipairs(pack) do phases[string.format("%.4f",p.distanceSample.nextAt)]=true end
local groups=0; for _ in pairs(phases) do groups=groups+1 end; assert(groups==10)
local p=pack[1]; local before=reads
distances[p.unit]=nil; p.cachedGuid="gone"
assert(sampleDistance(p,2)==nil and reads==before+1)
assert(sampleDistance(p,2)==nil and reads==before+1) -- Failed reads are cached too.
p.cachedGuid="new"; distances[p.unit]=33
assert(sampleDistance(p,2)==33 and reads==before+2)
p.unit="newtoken"; distances.newtoken=37
assert(sampleDistance(p,2)==37 and reads==before+3)
zAPI=function() end
assert(sampleDistance(p,2)==37 and reads==before+4)
UnitXP=function() end
assert(sampleDistance(p,2)==37 and reads==before+5)
''')

# Run the actual full visual pass: sampling never throttles animation/anchoring.
lua.execute('''
Z={RepairPlateTextLayers=function() end}; zNameplates=Z
transitions=0; Z.UpdatePlateTransition=function() transitions=transitions+1 end
UIParent={GetScale=function() return 1 end}
cfg={distance_scale=true,distance_alpha=true,distance_min_scale=.5,distance_min_alpha=.4,distance_max_range=40}
abs=math.abs; SetLineOfSightDesaturation=function() end
scaleWrites=0
SampleExactUnitDistance=sampleDistance
p={unit="moving",cachedGuid="0x0000"}
function p:SetScale(s) scaleWrites=scaleWrites+1; self.scale=s end
function p:SetAlpha(a) self.alpha=a end
distances.moving=8; reads=0
''')
visual = plates[plates.index("  local function ApplyDistanceEffects("):
                plates.index("  local function RefreshVisibleNameplatePool(")]
lua.execute(visual + "\napplyDistance=ApplyDistanceEffects")
lua.execute('''
applyDistance(p,0,1); assert(p.scale==1)
distances.moving=40
applyDistance(p,.02,1); assert(p.scale==1 and reads==1)
applyDistance(p,.05,1); local old=p.scale; local before=reads
assert(old<1 and old>.5)
applyDistance(p,.055,1)
assert(p.scale<old and p.scale>.5 and reads==before)
for i=7,120 do applyDistance(p,i/120,1) end
assert(transitions==118 and reads<=22 and scaleWrites>100)
assert(p.scale>.5 and p.scale<.501 and p.alpha>.4 and p.alpha<.401)
''')

# Unit validation reuses its table without suppressing any current-frame checks.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; lookups=0; exists=true; guid="unit1"; owner={}
UnitExists=function() return exists end
UnitGUID=function() lookups=lookups+1; return guid end
C_NamePlate={GetNamePlateForUnit=function() return owner end}
p={unit="nameplate1",cachedGuid=guid,parent=owner}
''')
lua.execute(identity)
lua.execute('''
assert(Z.IsPlateUnitCurrent(p,0)); local saved=p.unitValidation
for i=1,120 do
 assert(Z.IsPlateUnitCurrent(p,i/120)); assert(p.unitValidation==saved)
 local before=lookups; assert(Z.IsPlateUnitCurrent(p,i/120)); assert(lookups==before)
end
assert(lookups==121)
guid="unit2"; p.cachedGuid=guid; assert(Z.IsPlateUnitCurrent(p,1) and p.unitValidation==saved)
owner={}; assert(not Z.IsPlateUnitCurrent(p,2) and p.unitValidation==saved)
''')
print("Town performance: 50/100/150 overlap labels do 0 avoidance comparisons; mixed two-mob solve does 4; unchanged aura trees skipped; 20 Hz distance samples retain render-rate smooth animation/anchors; lifecycle caches reuse storage safely.")
