-- Optional companion vitals. No text, borders, per-plate update scripts or
-- changes to the player's friendly-nameplate settings.
local Z=zNameplates
local provider
local watched={}
function Z.SetPairedVitalsProvider(fn)
 provider=type(fn)=="function" and fn or nil
 if not provider then for plate in pairs(watched) do if plate.pairedVitals then plate.pairedVitals:Hide() end end end
end
local colors={[0]={.15,.45,1},[1]={.9,.18,.15},[2]={1,.55,.2},[3]={1,.85,.12},[4]={.2,.85,.65}}
function Z.UpdatePairedVitals(visible)
 for plate in pairs(watched) do
  if not plate:IsVisible() or not plate.cachedGuid then plate.pairedVitals:Hide();watched[plate]=nil end
 end
 for parent in pairs(visible or {}) do
  local plate=parent.nameplate
  if plate then
   local v
   if provider and plate.isFriendly and plate.cachedGuid and plate.name and plate.name:IsVisible() then v=provider(plate.cachedGuid) end
   if type(v)=="table" and type(v.maxHealth)=="number" and v.maxHealth>0 then
    local f=plate.pairedVitals
    if not f then
     f=CreateFrame("Frame",nil,plate);plate.pairedVitals=f;f:EnableMouse(false)
     f.health=CreateFrame("StatusBar",nil,f);f.power=CreateFrame("StatusBar",nil,f)
     for _,bar in ipairs({f.health,f.power}) do bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8");bar:SetMinMaxValues(0,1);bar:EnableMouse(false)
      bar.bg=bar:CreateTexture(nil,"BACKGROUND");bar.bg:SetAllPoints(bar);bar.bg:SetTexture(0,0,0,.55)
     end
     f.health:SetStatusBarColor(.2,.85,.35)
    end
    -- GetEffectiveScale maps UI coordinates directly to framebuffer pixels.
    local pixel=1/math.max(.01,f:GetEffectiveScale())
    local width=(math.max(12,plate.name:GetStringWidth() or 0)+8*pixel)*.7
    f:ClearAllPoints();f:SetPoint("TOP",plate.name,"BOTTOM",0,-2*pixel);f:SetWidth(width);f:SetHeight(5*pixel)
    f.health:ClearAllPoints();f.health:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);f.health:SetWidth(width);f.health:SetHeight(2*pixel)
    f.power:ClearAllPoints();f.power:SetPoint("TOPLEFT",f.health,"BOTTOMLEFT",0,-pixel);f.power:SetWidth(width);f.power:SetHeight(2*pixel)
    f.health:SetValue(math.max(0,math.min(1,(tonumber(v.health) or 0)/v.maxHealth)))
    if type(v.maxPower)=="number" and v.maxPower>0 then
     local c=colors[v.powerType] or colors[0];f.power:SetStatusBarColor(c[1],c[2],c[3]);f.power:SetValue(math.max(0,math.min(1,(tonumber(v.power) or 0)/v.maxPower)));f.power:Show()
    else f.power:Hide() end
    f:Show();watched[plate]=true
   elseif plate.pairedVitals then plate.pairedVitals:Hide();watched[plate]=nil end
  end
 end
 -- A removed/recycled plate can still be shown elsewhere during the same tick.
 for plate in pairs(watched) do
  local found=false;for parent in pairs(visible or {}) do if parent.nameplate==plate then found=true;break end end
  if not found then plate.pairedVitals:Hide();watched[plate]=nil end
 end
end
local frame=CreateFrame("Frame")
frame:SetScript("OnUpdate",function()
 local now=GetTime();if now<(this.nextTick or 0) then return end;this.nextTick=now+.1
 Z.UpdatePairedVitals(Z.nameplates and Z.nameplates.visiblePlates)
end)
