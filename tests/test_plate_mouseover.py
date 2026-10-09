"""Event-driven hover ownership, chained scripts, pooling, and cluster selection."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
zNameplates={config={nameplates={mouseover_unit="1"}}}
units={a={guid="ga",hp=50},b={guid="gb",hp=20}}
UnitExists=function(u) return units[u]~=nil or u=="ga" or u=="gb" end
UnitGUID=function(u) return units[u] and units[u].guid end
UnitHealth=function(u) return units[u].hp end
UnitHealthMax=function(u) return 100 end
calls={}; enters=0; leaves=0; hides=0
SetMouseoverUnit=function(u) assert(u~=nil); calls[#calls+1]=u end
function frame()
 local f={scripts={}}
 function f:GetScript(k) return self.scripts[k] end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:Click(button) clicked=self.nameplate.unit; clickedButton=button end
 function f:fire(k) this=self; if self.scripts[k] then self.scripts[k]() end end
 return f
end
function plate(u)
 local p=frame(); p.parent=frame(); p.parent.nameplate=p
 p.unit=u; p.cachedGuid=UnitGUID(u)
 return p
end
a=plate("a"); b=plate("b")
a.parent:SetScript("OnEnter",function() assert(this==a.parent); enters=enters+1 end)
a.parent:SetScript("OnLeave",function() leaves=leaves+1 end)
a.parent:SetScript("OnHide",function() hides=hides+1 end)
clickScript=function() end; a:SetScript("OnClick",clickScript)
''')
lua.execute((root / "clusters.lua").read_text(encoding="utf-8-sig"))
lua.execute('''
Z=zNameplates
Z.InstallPlateMouseover(a.parent,a); Z.InstallPlateMouseover(a,a)
Z.InstallPlateMouseover(a.parent,a); Z.InstallPlateMouseover(b.parent,b)
assert(a:GetScript("OnClick")==clickScript)
a.parent:fire("OnEnter"); assert(calls[#calls]=="ga" and enters==1)
a:fire("OnEnter"); local n=#calls
a.parent:fire("OnLeave"); assert(#calls==n and leaves==1)
a:fire("OnLeave"); assert(calls[#calls]=="")
a:fire("OnEnter"); a.parent:fire("OnEnter"); n=#calls
a:fire("OnHide"); assert(#calls==n) -- Old receiver hides after transfer.
a.parent:fire("OnHide"); assert(calls[#calls]=="" and hides==1)
a.parent:fire("OnEnter"); b.parent:fire("OnEnter"); n=#calls
a.parent:fire("OnLeave"); assert(#calls==n)
Z.ClearPlateMouseover(b); assert(calls[#calls]=="") -- Removal without Leave.
a.parent:fire("OnEnter")
a.unit="b"; a.cachedGuid="gb"; Z.RefreshOwnedPlateMouseover(a,true)
assert(calls[#calls]=="gb") -- Recycled owner is refreshed, not stale.
a.unit=nil; a.cachedGuid=nil; Z.RefreshOwnedPlateMouseover(a,true)
assert(calls[#calls]=="")
a.unit="a"; a.cachedGuid=nil; a.parent:fire("OnEnter")
assert(calls[#calls]=="a") -- No GUID: valid token fallback.
Z.ClearPlateMouseover(a); a.cachedGuid="ga"
SetMouseoverUnit=function(u)
 if u=="ga" then error("GUID unsupported") end
 calls[#calls+1]=u
end
a.parent:fire("OnEnter"); assert(calls[#calls]=="a")
Z.ClearPlateMouseover(a)
SetMouseoverUnit=function(u) assert(u~=nil); calls[#calls+1]=u end
a.clusterGroup={members={a,b}}
a.parent:fire("OnEnter"); assert(calls[#calls]=="gb")
Z.ClickPlate(a,"RightButton"); assert(clicked=="b" and clickedButton=="RightButton")
units.a.hp=10; Z.RefreshOwnedPlateMouseover(a)
assert(calls[#calls]=="ga" and Z.GetPlateClickMember(a)==a)
units.a.hp=0; Z.RefreshOwnedPlateMouseover(a); assert(calls[#calls]=="gb")
units.b.guid="reused"; Z.RefreshOwnedPlateMouseover(a)
assert(calls[#calls]=="") -- Never hover a recycled token in a cluster.
a.clusterGroup=nil; units.a.hp=50
a.parent:fire("OnEnter"); Z.config.nameplates.mouseover_unit="0"
Z.InstallPlateMouseover(a.parent,a); assert(calls[#calls]=="")
n=#calls; a.parent:fire("OnEnter"); assert(#calls==n)
Z.config.nameplates.mouseover_unit="1"
Z.IsPlateClickBlocked=function() return true end
a.parent:fire("OnEnter"); assert(#calls==n)
Z.IsPlateClickBlocked=nil; SetMouseoverUnit=nil
a.parent:fire("OnEnter"); a.parent:fire("OnLeave"); assert(#calls==n)
assert(enters==11) -- Existing handlers remain single-chained on every entry.
''')
source = (root / "nameplates.lua").read_text(encoding="utf-8-sig")
assert "zNameplates.RefreshOwnedPlateMouseover(plate.nameplate, true)" in source
assert "zNameplates.ClearPlateMouseover(plate.nameplate)" in source
assert "zNameplates.InstallPlateMouseover(parent, nameplate)" in source
assert "zNameplates.InstallPlateMouseover(nameplate, nameplate)" in source
print("Plate mouseover checks passed")
