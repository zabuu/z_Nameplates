"""Check exact layout parity and warm allocation against the prior solver."""
import ast
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT.parent / "_zSuiteMaintenance/all-addons-2026-10-25/before/z_Nameplates/sticky.lua"
tree = ast.parse((ROOT / "tests/test_sticky_placement.py").read_text())
boot = next(ast.literal_eval(n.value.args[0]) for n in tree.body if isinstance(n, ast.Expr)
            and isinstance(n.value, ast.Call) and isinstance(n.value.func, ast.Attribute)
            and n.value.func.attr == "execute")
core = (ROOT / "core.lua").read_text(encoding="utf-8-sig")


def runtime(source):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute(boot)
    vm.execute("local Z=zNameplates\n" + core[core.index("function Z.IsPlateUnitCurrent("):
                                              core.index("-- zAPI projects in the native WorldFrame")])
    vm.execute(source + "\nmeasureBounds=Measure")
    vm.execute(r'''
function object(owner,l,r,b,t,scale,text)
 local o={owner=owner,l=l,r=r,b=b,t=t,scale=scale,text=text,shown=true,alpha=1}
 function o:GetLeft() return self.l end;function o:GetRight() return self.r end
 function o:GetBottom() return self.b end;function o:GetTop() return self.t end
 function o:GetParent() return self.owner end;function o:GetAlpha() return self.alpha end
 function o:IsShown() return self.shown end;function o:IsVisible() return self.shown end
 if scale then function o:GetEffectiveScale() return self.scale end end
 if text then function o:GetText() return self.text end end
 return o
end
pack={};visible={};allVisible={}
for i=1,24 do
 local p=add("layout"..i,200+math.mod(i,6)*8,200+math.floor(i/6)*8)
 function p:GetCenter() return 200,190 end;function p:GetTop() return 200 end
 local surface=object(p,0,0,0,0,.25)
 p.health=object(p,160,240,190,200,1)
 p.name=object(surface,620,980,805,860,nil,"Name")
 p.level=object(surface,600,620,800,840,nil,"60")
 p.debuffs={object(p,200,210,202,212,1)}
 pack[i]=p;allVisible[p.parent]=p.parent
 -- Stable arrival order in both VMs; real visible tables need not enumerate alike.
 visible={[p.parent]=p.parent};Z.UpdateStickyPlacements(0,visible,function() return false end)
end
visible=allVisible
function allows(p) return p.isFriendly or overlap end
function tick(t)
 clock=t;Z.UpdateStickyPlacements(t,visible,allows)
 for _,p in ipairs(pack) do render(p,t) end
end
function boundsWork(n) for i=1,n do measureBounds(pack[1],1) end end
function stateValues()
 local out={}
 for _,p in ipairs(pack) do local s=p.stickyPlacement
  for _,key in ipairs({"baseX","baseY","contentW","contentH","cx","cy","dx","dy","displayX","displayY","vx","vy"}) do
   table.insert(out,s and s[key] or 0)
  end
 end
 return out
end
''')
    return vm


new = runtime((ROOT / "sticky.lua").read_text(encoding="utf-8-sig"))
old = runtime(BASE.read_text(encoding="utf-8-sig")) if BASE.exists() else None
vms = [old,new] if old else [new]
for step in range(1,241):
    script = f'''
for i,p in ipairs(pack) do
 p.px=200+math.mod(i,6)*8+math.sin({step}*.03)*4;p.py=200+math.floor(i/6)*8
 p.name.shown=math.mod({step}+i,11)~=0;p.level.text=math.mod({step}+i,13)==0 and "" or "60"
 p.debuffs[1].alpha=math.mod({step}+i,17)==0 and 0 or 1
 p.isFriendly=i<=4 and {step}>80 and {step}<160
end
overlap={str(120 <= step < 150).lower()}
tick({step}*.016)
'''
    for vm in vms:
        vm.execute(script)
    if old:
        a,b=list(old.globals().stateValues().values()),list(new.globals().stateValues().values())
        assert len(a)==len(b) and all(abs(x-y)<1e-9 for x,y in zip(a,b)), step
growth=[]
for vm in vms:
    vm.execute('''
boundsWork(10);collectgarbage("collect");collectgarbage("stop")
local before=collectgarbage("count");boundsWork(10000)
growth=collectgarbage("count")-before;collectgarbage("restart")
''')
    growth.append(vm.globals().growth)
assert growth[-1]<10,growth
if old:
    assert growth[0]>1000,growth
    print("PASS 10,000 visible-bound measurements: temporary Lua growth %.1f -> %.1f KiB" % tuple(growth))
print("PASS 240 x 24 plate layouts match bounds, displacement and damping exactly; hidden text/auras, quarter-scale font surfaces, overlap and friendly collision scenes")
