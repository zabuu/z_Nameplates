"""Change-driven font/layer writes and evenly phased data/LOS work."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8-sig")
plates = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Z={}; zNameplates=Z; clock=1; combatReads=0; fontWrites=0; heightWrites=0
GetTime=function() return clock end
UnitAffectingCombat=function() combatReads=combatReads+1; return true end
text={}
function text:GetFont() return self.font,self.size,self.flags end
function text:SetFont(f,s,o) fontWrites=fontWrites+1; self.font=f; self.size=s; self.flags=o end
function text:SetTextHeight(h) heightWrites=heightWrites+1 end
''')
lua.execute('local Z=Z\n' + core[core.index("function Z.SetSmoothFontString("):core.index("function Z.ShouldUseCombatNameColor(")])
lua.execute('local Z=Z\n' + core[core.index("function Z.GetPlayerCombatState("):core.index("function Z.ShouldUpdatePlateDepth(")])
lua.execute('''
for i=1,100 do Z.SetSmoothFontString(text,"font.ttf",12,"OUTLINE"); assert(Z.GetPlayerCombatState()) end
assert(fontWrites==1 and heightWrites==1 and combatReads==1)
-- External font/style changes and explicit setting changes are not hidden by
-- a stale cache. Fractional font sizes still pass through without quantizing.
text.font="other.ttf"; Z.SetSmoothFontString(text,"font.ttf",12,"OUTLINE")
Z.SetSmoothFontString(text,"font.ttf",12.125,"THICKOUTLINE")
assert(text.size==24.25 and fontWrites==3 and heightWrites==2)
clock=1.01; Z.GetPlayerCombatState(); assert(combatReads==2)
local phases={}
for i=1,50 do
 local p={cachedGuid=string.format("0x%08X",i)}
 local next=Z.NextPlateDataRefresh(p,1)
 assert(next>1 and next<=1.5)
 local key=string.format("%.2f",next); phases[key]=(phases[key] or 0)+1
 assert(Z.NextPlateDataRefresh(p,next)>next)
end
local count=0
for _,n in pairs(phases) do count=count+1; assert(n==5) end
assert(count==10) -- Fifty routine refreshes become ten small batches.
''')

# Execute the actual queued-event block and final refresh block together. A
# due routine timer must not cause a second full data pass after the event pass.
start = plates.index("    local dataUpdated\n")
end = plates.index("    -- =========================================================================\n    -- OVERLAP", start)
queued = plates[start:end]
start = plates.index("    -- use timer based updates\n")
end = plates.index("    -- Zoom animation\n", start)
final = plates[start:end]
lua.execute('''
passes=0; nameplates={OnDataChanged=function() passes=passes+1 end}
function refreshTest(p,now,eventPending)
 local nameplate=p; local hasEventUpdate=eventPending; local update
''' + queued + final + '''
end
p={cachedGuid="0x0010",eventcache=true,auraUpdate=true,targetUpdate=true}
refreshTest(p,1,true)
assert(passes==1 and not p.eventcache and not p.auraUpdate and not p.targetUpdate)
assert(p.tick>1 and p.tick<=1.5)
refreshTest(p,1.01,false); assert(passes==1)
refreshTest(p,p.tick+.001,false); assert(passes==2)
''')

# The real LOS scheduling expression preserves immediate first evaluation and
# the 100 ms upper bound, while distributing subsequent expensive raycasts.
start = plates.index("        local phase = plate.losSamplePhase or 0\n")
end = plates.index("\n      end", start)
lua.execute('function nextLOS(plate,now)\n' + plates[start:end] + '\nreturn plate.losNextSample end')
lua.execute('''
local buckets={}
for i=0,7 do
 local plate={losSamplePhase=i*.0125}
 local due=nextLOS(plate,1)
 assert(due>1 and due<=1.10001)
 assert(nextLOS(plate,due)>due)
 buckets[string.format("%.4f",due)]=true
end
local count=0; for _ in pairs(buckets) do count=count+1 end; assert(count==8)
''')
print("zNP: unchanged fonts skip rebuilds; player-combat checks shared; 50 routine refreshes phased into 10 batches; event updates run once; LOS work spread within 100 ms.")
