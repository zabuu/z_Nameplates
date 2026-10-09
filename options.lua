-- One self-contained settings window for the standalone nameplate module.

local Z = zNameplates
local PATH = "Interface\\AddOns\\z_Nameplates"

-- Keep dialogs spawned by our elevated settings panel above it, then restore
-- their original strata when they close (the frames are shared Blizzard UI).
local function RaiseSettingsDialog(dialog)
  if not dialog then return end
  if not dialog.znpRestoreLayerHook then
    local previous=dialog:GetScript("OnHide")
    dialog:SetScript("OnHide",function()
      if previous then previous(dialog) end
      if dialog.znpPreviousStrata then
        local strata=dialog.znpPreviousStrata
        dialog.znpPreviousStrata=nil
        dialog:SetFrameStrata(strata)
      end
    end)
    dialog.znpRestoreLayerHook=true
  end
  if not dialog.znpPreviousStrata then dialog.znpPreviousStrata=dialog:GetFrameStrata() end
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
end
function Z.ShowSettingsConfirmation(id)
  RaiseSettingsDialog(StaticPopup_Show(id))
end

local alignments = {
  { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" },
}
local positions = {
  { "Top left", "TOPLEFT" }, { "Top", "TOP" }, { "Top right", "TOPRIGHT" },
  { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" },
  { "Bottom left", "BOTTOMLEFT" }, { "Bottom", "BOTTOM" }, { "Bottom right", "BOTTOMRIGHT" },
}
local fontStyles = {
  { "None", "" }, { "Outline", "OUTLINE" },
  { "Thick outline", "THICKOUTLINE" }, { "Monochrome", "MONOCHROME" },
}
local healthFormats = {
  { "Current / maximum", "curmaxs" }, { "Current - maximum", "curmax" },
  { "Current / maximum | percent", "curmaxpercs" }, { "Current - maximum | percent", "curmaxperc" },
  { "Current | percent", "curperc" }, { "Current", "cur" },
  { "Deficit", "deficit" }, { "Percent", "percent" },
}
local filters = {
  { "No filter", "none" }, { "Blacklist", "blacklist" }, { "Whitelist", "whitelist" },
}
local textures = {
  { "Smooth", PATH .. "\\Assets\\img\\bar.tga" },
  { "Gradient", PATH .. "\\Assets\\img\\bar_gradient.tga" },
  { "Striped", PATH .. "\\Assets\\img\\bar_striped.tga" },
  { "ElvUI", PATH .. "\\Assets\\img\\bar_elvui.tga" },
  { "TukUI", PATH .. "\\Assets\\img\\bar_tukui.tga" },
}
local fonts = {
  { "Myriad Pro", PATH .. "\\Assets\\fonts\\Myriad-Pro.ttf" },
  { "Big Noodle", PATH .. "\\Assets\\fonts\\BigNoodleTitling.ttf" },
  { "Expressway", PATH .. "\\Assets\\fonts\\Expressway.ttf" },
  { "PT Sans Narrow", PATH .. "\\Assets\\fonts\\PT-Sans-Narrow-Regular.ttf" },
  { "PT Sans Narrow Bold", PATH .. "\\Assets\\fonts\\PT-Sans-Narrow-Bold.ttf" },
  { "Roboto Mono", PATH .. "\\Assets\\fonts\\RobotoMono.ttf" },
  { "Continuum", PATH .. "\\Assets\\fonts\\Continuum.ttf" },
  { "Homespun", PATH .. "\\Assets\\fonts\\Homespun.ttf" },
  { "Hooge", PATH .. "\\Assets\\fonts\\Hooge.ttf" },
  { "Die Die Die", PATH .. "\\Assets\\fonts\\DieDieDie.ttf" },
}

local pages = {
  {
    name = "General",
    items = {
      { "check", "Show hostile nameplates", {"nameplates","showhostile"} },
      { "check", "Show friendly nameplates", {"nameplates","showfriendly"} },
      { "check", "Hide Blizzard XP floating text", {"nameplates","hide_blizzard_xp"} },
      { "check", "Disable hostile plates in friendly zones", {"nameplates","disable_hostile_in_friendly"} },
      { "check", "Disable friendly plates in friendly zones", {"nameplates","disable_friendly_in_friendly"} },
      { "slider", "Vertical offset", {"nameplates","vertical_offset"}, -100, 100, 1, " px" },
      { "slider", "Inactive alpha", {"nameplates","notargalpha"}, 0, 1, .05, "", 2 },
      { "check", "Glow around target", {"nameplates","targetglow"} },
      { "color", "Target glow color", {"nameplates","glowcolor"} },
      { "check", "Red names while in combat", {"nameplates","namefightcolor"} },
      { "check", "Zoom target nameplate", {"nameplates","targetzoom"} },
      { "slider", "Target zoom factor", {"nameplates","targetzoomval"}, 0, 2, .05, "", 2 },
      { "slider", "Nameplate width", {"nameplates","width"}, 40, 300, 1, " px" },
      { "check", "Enemy player class colors", {"nameplates","enemyclassc"} },
      { "check", "Friendly player class colors", {"nameplates","friendclassc"} },
      { "check", "Class-color friendly names", {"nameplates","friendclassnamec"} },
      { "check", "Show combo points", {"nameplates","cpdisplay"} },
      { "check", "Click-through nameplates", {"nameplates","clickthrough"} },
      { "check", "Click through friendly nameplates", {"nameplates","clickthrough_friendly"} },
      { "check", "Set mouseover unit when hovering plates", {"nameplates","mouseover_unit"} },
      { "check", "Allow enemy nameplate overlap", {"nameplates","overlap_enemy"} },
      { "check", "Allow friendly nameplate overlap", {"nameplates","overlap_friendly"} },
      { "check", "Overlap all plates in friendly areas", {"nameplates","overlap_friendly_area"} },
      { "check", "Never overlap plates in combat with me", {"nameplates","overlap_combat"} },
      { "check", "Replace totems with icons", {"nameplates","totemicons"} },
      { "check", "Show guild/sub-name", {"nameplates","showguildname"} },
      { "check", "Show dummy nameplate cluster", {"nameplates","dummy_preview"} },
      { "slider", "Dummy nameplates", {"nameplates","dummy_count"}, 1, 30, 1, " plates" },
      { "button", "Dummy Damage!", nil, function()
          if Z.PulseDummyDamage then Z.PulseDummyDamage() end
        end },
    },
  },
  {
    name = "Health",
    items = {
      { "slider", "Healthbar vertical offset", {"nameplates","health","offset"}, -50, 50, 1, " px" },
      { "slider", "Healthbar height", {"nameplates","heighthealth"}, 1, 40, 1, " px" },
      { "select", "Healthbar texture", {"nameplates","healthtexture"}, textures },
      { "check", "Show health text", {"nameplates","showhp"} },
      { "select", "Health text alignment", {"nameplates","hptextpos"}, alignments },
      { "select", "Name text alignment", {"nameplates","nametextpos"}, alignments },
      { "select", "Health text format", {"nameplates","hptextformat"}, healthFormats },
      { "color", "Enemy name color", {"nameplates","enemynamecolor"} },
      { "color", "Friendly name color", {"nameplates","friendlynamecolor"} },
      { "color", "Critter name color", {"nameplates","critternamecolor"} },
      { "check", "Vertical healthbar", {"nameplates","verticalhealth"} },
      { "check", "Hide bar: enemy NPCs", {"nameplates","enemynpc"} },
      { "check", "Hide bar: enemy players", {"nameplates","enemyplayer"} },
      { "check", "Hide bar: neutral NPCs", {"nameplates","neutralnpc"} },
      { "check", "Hide bar: friendly NPCs", {"nameplates","friendlynpc"} },
      { "check", "Hide bar: friendly players", {"nameplates","friendlyplayer"} },
      { "check", "Hide bar: critters", {"nameplates","critters"} },
      { "check", "Hide bar: totems", {"nameplates","totems"} },
      { "check", "Always show if health is missing", {"nameplates","fullhealth"} },
      { "check", "Always show target healthbar", {"nameplates","target"} },
      { "check", "Friendly-player blue outline", {"nameplates","outfriendly"} },
      { "check", "Friendly-NPC green outline", {"nameplates","outfriendlynpc"} },
      { "check", "Neutral yellow outline", {"nameplates","outneutral"} },
      { "check", "Enemy red outline", {"nameplates","outenemy"} },
      { "check", "Highlight target border", {"nameplates","targethighlight"} },
      { "color", "Target border color", {"nameplates","highlightcolor"} },
    },
  },
  {
    name = "Cast & Auras",
    items = {
      { "check", "Enable castbars", {"nameplates","showcastbar"} },
      { "check", "Only show target castbar", {"nameplates","targetcastbar"} },
      { "check", "Show spell name", {"nameplates","spellname"} },
      { "slider", "Castbar height", {"nameplates","heightcast"}, 1, 40, 1, " px" },
      { "select", "Castbar texture", {"appearance","castbar","texture"}, textures },
      { "color", "Cast color", {"appearance","castbar","castbarcolor"} },
      { "color", "Channel color", {"appearance","castbar","channelcolor"} },
      { "slider", "Castbar decimal places", {"unitframes","castbardecimals"}, 0, 3, 1, "" },
      { "check", "Enable debuffs", {"nameplates","showdebuffs"} },
      { "check", "Show debuffs on hostile units", {"nameplates","showdebuffs_hostile"} },
      { "check", "Show debuffs on friendly units", {"nameplates","showdebuffs_friendly"} },
      { "check", "Only show your debuffs", {"nameplates","owndebuffs"} },
      { "select", "Debuff position", {"nameplates","debuffs","position"}, {{"Above","TOP"},{"Below","BOTTOM"}} },
      { "slider", "Debuff icon offset", {"nameplates","debuffoffset"}, -50, 50, 1, " px" },
      { "slider", "Debuff icon size", {"nameplates","debuffsize"}, 6, 64, 1, " px" },
      { "check", "Show debuff stacks", {"nameplates","debuffs","showstacks"} },
      { "check", "Enable debuff timers", {"nameplates","debufftimers"} },
      { "check", "Show timer text", {"nameplates","debufftext"} },
      { "check", "Show timer animation", {"nameplates","debuffanim"} },
      { "select", "Debuff filter mode", {"nameplates","debuffs","filter"}, filters },
      { "input", "Blacklist (spell names, separated by #)", {"nameplates","debuffs","blacklist"}, 185 },
      { "input", "Whitelist (spell names, separated by #)", {"nameplates","debuffs","whitelist"}, 185 },
      { "check", "Dynamic cooldown text size", {"appearance","cd","dynamicsize"} },
    },
  },
  {
    name = "Text",
    items = {
      { "check", "Use separate unit font", {"nameplates","use_unitfonts"} },
      { "select", "Default font", {"global","font_default"}, fonts, "font" },
      { "slider", "Default font size", {"global","font_size"}, 6, 40, 1, " pt" },
      { "select", "Unit font", {"global","font_unit"}, fonts, "font" },
      { "slider", "Unit font size", {"global","font_unit_size"}, 6, 40, 1, " pt" },
      { "slider", "Hostile font size", {"nameplates","name","fontsize"}, 6, 40, 1, " pt" },
      { "slider", "Friendly font size", {"nameplates","name","fontsize_friendly"}, 6, 40, 1, " pt" },
      { "select", "Hostile font style", {"nameplates","name","fontstyle"}, fontStyles },
      { "select", "Friendly font style", {"nameplates","name","fontstyle_friendly"}, fontStyles },
      { "check", "Override font style in combat", {"nameplates","name","fontstyle_combat_enabled"} },
      { "select", "Combat font style", {"nameplates","name","fontstyle_combat"}, fontStyles },
      { "select", "Cooldown font", {"appearance","cd","font"}, fonts, "font" },
      { "slider", "Cooldown text size", {"appearance","cd","font_size"}, 6, 48, 1, " pt" },
      { "check", "Abbreviate long names", {"unitframes","abbrevname"} },
      { "select", "Number abbreviation", {"unitframes","abbrevnum"}, {{"Off","0"},{"Precise","1"},{"Compact","2"}} },
      { "preview", "Hostile Text Preview", nil, "hostile" },
      { "preview", "Friendly Text Preview", nil, "friendly" },
      { "preview", "Combat Text Preview", nil, "combat" },
    },
  },
  {
    name = "Appearance",
    items = {
      { "check", "Use Blizzard raid icons", {"unitframes","blizzard_raidicons"} },
      { "select", "Raid icon position", {"nameplates","raidiconpos"}, positions },
      { "slider", "Raid icon X offset", {"nameplates","raidiconoffx"}, -100, 100, 1, " px" },
      { "slider", "Raid icon Y offset", {"nameplates","raidiconoffy"}, -100, 100, 1, " px" },
      { "slider", "Raid icon size", {"nameplates","raidiconsize"}, 6, 64, 1, " px" },
      { "check", "Show quest-giver icons", {"nameplates","questicons"} },
      { "check", "Show unknown flight path icons", {"nameplates","flighticons"} },
      { "slider", "Quest icon size", {"nameplates","questiconsize"}, 8, 64, 1, " px" },
      { "slider", "Quest icon vertical offset", {"nameplates","questiconoffset"}, -100, 100, 1, " px" },
      { "color", "Border color", {"appearance","border","color"} },
      { "color", "Border background", {"appearance","border","background"} },
      { "slider", "Default border size", {"appearance","border","default"}, 0, 8, 1, " px" },
      { "slider", "Nameplate border size", {"appearance","border","nameplates"}, -1, 8, 1, " px" },
      { "check", "Pixel-perfect borders", {"appearance","border","pixelperfect"} },
      { "check", "HiDPI border correction", {"appearance","border","hidpi"} },
      { "select", "Level text relative to", {"nameplates","levelreference"}, {{"Automatic","AUTO"},{"Name","NAME"},{"Health bar","HEALTH"}} },
      { "select", "Level text position", {"nameplates","levelposition"}, {{"Left","LEFT"},{"Right","RIGHT"},{"Above","TOP"},{"Below","BOTTOM"}} },
      { "slider", "Level text X offset", {"nameplates","levelx"}, -100, 100, 1, " px" },
      { "slider", "Level text Y offset", {"nameplates","levely"}, -100, 100, 1, " px" },
    },
  },
  {
    name = "Chat",
    items = {
      { "check", "Enable nameplate chat", {"platechat","enabled"} },
      { "check", "Show chat when player nameplates are hidden", {"platechat","show_without_plate"} },
      { "select", "Chat position", {"platechat","position"}, {{"Beside name (right)","RIGHT"},{"Beside name (left)","LEFT"},{"Above name","TOP"},{"Below name","BOTTOM"}} },
      { "slider", "Chat X offset", {"platechat","x"}, -200, 200, 1, " px" },
      { "slider", "Chat Y offset", {"platechat","y"}, -200, 200, 1, " px" },
      { "slider", "Chat duration", {"platechat","duration"}, 1, 30, .1, " sec", 1 },
      { "slider", "Fade duration", {"platechat","fade"}, 0, 5, .1, " sec", 1 },
      { "slider", "Chat scale", {"platechat","scale"}, .5, 2, .01, "", 2 },
      { "slider", "Chat font size", {"platechat","fontsize"}, 6, 30, 1, " pt" },
      { "slider", "Chat text width", {"platechat","width"}, 80, 400, 1, " px" },
      { "slider", "Chat opacity", {"platechat","opacity"}, .1, 1, .05, "", 2 },
      { "color", "Chat background colour", {"platechat","background_color"}, nil, "rgb" },
      { "slider", "Chat background opacity", {"platechat","background_opacity"}, 0, 1, .01, "", 2 },
      { "select", "Chat font style", {"platechat","fontstyle"}, fontStyles },
      { "check", "Show say", {"platechat","say"} },
      { "check", "Show yell", {"platechat","yell"} },
      { "check", "Show party chat", {"platechat","party"} },
      { "check", "Show raid chat", {"platechat","raid"} },
      { "check", "Show guild / officer chat", {"platechat","guild"} },
      { "check", "Show whispers", {"platechat","whisper"} },
      { "check", "Show battleground chat", {"platechat","battleground"} },
      { "check", "Show instance chat", {"platechat","instance"} },
      { "check", "Show emotes", {"platechat","emote"} },
      { "check", "Show NPC speech", {"platechat","npc"} },
    },
  },
  {
    name = "Threat",
    items = {
      { "check", "Combat state colors on border", {"nameplates","outcombatstate"} },
      { "check", "Combat state colors on healthbar", {"nameplates","barcombatstate"} },
      { "check", "State: unit attacking you", {"nameplates","ccombatthreat"} },
      { "color", "Attacking-you color", {"nameplates","combatthreat"} },
      { "check", "State: unit attacking off-tank", {"nameplates","ccombatofftank"} },
      { "color", "Off-tank color", {"nameplates","combatofftank"} },
      { "check", "State: unit attacking others", {"nameplates","ccombatnothreat"} },
      { "color", "Attacking-others color", {"nameplates","combatnothreat"} },
      { "check", "State: unit attacking nobody", {"nameplates","ccombatstun"} },
      { "color", "No-target/stunned color", {"nameplates","combatstun"} },
      { "check", "State: unit casting", {"nameplates","ccombatcasting"} },
      { "color", "Casting color", {"nameplates","combatcasting"} },
      { "input", "Off-tank names (separated by #)", {"nameplates","combatofftanks"}, 185 },
    },
  },
  {
    name = "Distance",
    items = {
      { "check", "Cluster similar enemies above 30 plates", {"nameplates","cluster_enabled"} },
      { "slider", "Cluster health-band width", {"nameplates","cluster_health_band"}, 10, 20, 1, "%" },
      { "check", "Smooth nameplate transitions", {"nameplates","smooth_transitions"} },
      { "slider", "Transition duration", {"nameplates","transition_duration"}, .05, .5, .01, " sec", 2 },
      { "slider", "Extended nameplate range", {"nameplates","nameplate_range"}, 10, 80, 1, " yd" },
      { "check", "Scale nameplates by exact distance", {"nameplates","distance_scale"} },
      { "slider", "Minimum distant size", {"nameplates","distance_min_scale"}, 20, 100, .01, "%", 2 },
      { "check", "Fade nameplates by exact distance", {"nameplates","distance_alpha"} },
      { "slider", "Minimum distant opacity", {"nameplates","distance_min_alpha"}, 20, 100, 1 },
      { "check", "Fade and desaturate out-of-sight plates", {"nameplates","los_fade"} },
      { "slider", "Out-of-sight desaturation", {"nameplates","los_desaturation"}, 0, 100, 1 },
    },
  },
  {
    name = "Advanced",
    items = {
      { "check", "Right-click mouselook/attack", {"nameplates","rightclick"} },
      { "slider", "Right-click threshold", {"nameplates","clickthreshold"}, .1, 2, .05, " sec", 2 },
      { "slider", "Normal update rate", {"throttle","nameplates"}, 1, 60, 1, "/sec" },
      { "slider", "Target update rate", {"throttle","nameplates_target"}, 1, 100, 1, "/sec" },
      { "slider", "Castbar update rate", {"throttle","nameplates_castbar"}, 1, 200, 1, "/sec" },
      { "slider", "Mass-nameplate update rate", {"throttle","nameplates_mass"}, 1, 60, 1, "/sec" },
    },
  },
}

-- Preserve the original setting definitions/paths while grouping them by task.
local destinations = {
  enemynamecolor="Text", friendlynamecolor="Text", critternamecolor="Text",
  enemyclassc="Text", friendclassc="Text", friendclassnamec="Text",
  namefightcolor="Text", showguildname="Text", nametextpos="Text",
  width="Health", vertical_offset="Health", totemicons="Appearance",
  targetglow="Health", glowcolor="Health", targetzoom="Health", targetzoomval="Health",
  dummy_preview="Preview", dummy_count="Preview", rightclick="General", clickthreshold="General",
  cluster_enabled="Crowds", cluster_health_band="Crowds",
}
local descriptions = {
  General="Visibility, interaction and stacking behaviour.",
  Health="Bar layout, health labels and visibility rules.",
  ["Cast & Auras"]="Cast information, debuff placement and spell filters.",
  Text="Fonts, readable labels and unit colours.",
  Appearance="Borders, raid markers, quest icons and level placement.",
  Chat="Speech attached to nearby speakers, with channel filters.",
  Threat="Colour rules for combat, targeting and tag ownership.",
  Distance="Range, smooth movement, distance size and visibility.",
  Crowds="Reduce duplicate plates in large packs without losing targets.",
  List="The movable nearby-enemy list (/znp list).",
  Preview="Test your appearance settings without a real encounter.",
  Advanced="Update rates and troubleshooting tools.",
  Profiles="Independent settings per character. Copying never changes another character.",
}
local sectionRules = {
  General={{"Visibility","showhostile showfriendly hide_blizzard_xp disable_hostile_in_friendly disable_friendly_in_friendly"},
    {"Interaction","clickthrough clickthrough_friendly mouseover_unit rightclick clickthreshold"},{"Stacking","overlap_enemy overlap_friendly overlap_friendly_area overlap_combat"}},
  Health={{"Layout","width vertical_offset offset heighthealth healthtexture verticalhealth"},
    {"Health labels","showhp hptextpos hptextformat"},{"Visibility rules","enemynpc enemyplayer neutralnpc friendlynpc friendlyplayer critters totems fullhealth target"},
    {"Target emphasis","targetglow glowcolor targetzoom targetzoomval targethighlight highlightcolor"}},
  ["Cast & Auras"]={{"Cast bars","showcastbar targetcastbar spellname heightcast texture castbarcolor channelcolor castbardecimals"},
    {"Debuff visibility","showdebuffs showdebuffs_hostile showdebuffs_friendly owndebuffs"},
    {"Placement & timers","position debuffoffset debuffsize showstacks debufftimers debufftext debuffanim dynamicsize"},
    {"Spell filters","filter blacklist whitelist"}},
  Text={{"Fonts","use_unitfonts font_default font_size font_unit font_unit_size fontsize fontsize_friendly fontstyle fontstyle_friendly"},
    {"Combat style","fontstyle_combat_enabled fontstyle_combat namefightcolor"},
    {"Name colours","enemynamecolor friendlynamecolor critternamecolor enemyclassc friendclassc friendclassnamec"},
    {"Labels & cooldowns","showguildname nametextpos abbrevname abbrevnum font"}},
  Appearance={{"Raid markers","blizzard_raidicons raidiconpos raidiconoffx raidiconoffy raidiconsize"},
    {"Quest & special icons","questicons flighticons questiconsize questiconoffset totemicons"},
    {"Borders","color background default nameplates pixelperfect hidpi"},
    {"Level placement","levelreference levelposition levelx levely"}},
  Chat={{"Enable & placement","enabled show_without_plate position x y"},
    {"Appearance & timing","duration fade scale fontsize width opacity background_color background_opacity fontstyle"},
    {"Channels","say yell party raid guild whisper battleground instance emote npc"}},
  Distance={{"Movement & range","smooth_transitions transition_duration nameplate_range"},
    {"Distance sizing","distance_scale distance_min_scale"},{"Distance & line of sight","distance_alpha distance_min_alpha los_fade los_desaturation"}},
}
local help = {
  clickthrough="Ignore normal plate clicks. Clusters remain clickable; interface windows always take priority.",
  clickthrough_friendly="Ignore friendly plate clicks and hover events. Turn off the general Click-through nameplates option to keep hostile plates clickable. Neutral NPCs are unaffected.",
  mouseover_unit="Requires SetMouseoverUnit (SuperWoW / Nampower). Normal plates need click-through off to receive hover events. Targets are never changed.",
  namefightcolor="Hostile enemies only. Friendly names keep their class/reaction colour; neutral names stay yellow.",
  overlap_combat="Combat plates take priority over friendly-area overlap rules.",
  neutralnpc="Unprovoked neutrals follow friendly visibility; provoked neutrals retain their health bar.",
  nameplate_range="41 yd is the standard default. Extended range requires zAPI; maximum 80 yd.",
  distance_min_scale="Minimum size reached at the nameplate-range limit. Full size within 8 yards.",
  distance_min_alpha="Also sets the out-of-sight opacity floor. Distance and LOS fading do not compound.",
  los_fade="Requires UnitXP sight checks. Controls opacity and colour independently of distance size.",
  show_without_plate="Includes your own chat. Requires zAPI and a nearby, locatable player; not remote guild members.",
  blacklist="Separate exact spell names with #. Used only when the blacklist filter is selected.",
  whitelist="Separate exact spell names with #. Used only when the whitelist filter is selected.",
  combatofftanks="Separate player names with #. These names identify your off-tanks.",
  fontstyle_combat="Used only when the combat-style override is enabled.",
  cluster_enabled="Targets, raid marks, players, friendly units and critters remain separate. Click a cluster for its lowest-HP member.",
  cluster_health_band="Members move between health bands as their HP changes; displayed health is the average percentage.",
  shown="Keep a compact frame visible even with no nearby enemies. You can drag its header.",
  dummy_preview="Live test plates use your actual settings. Camera-aware placement requires zAPI.",
  nameplates_mass="Background data rate in crowds. Position and distance animations remain per-frame.",
    nameplates="An inherited border size of -1 uses the default border setting.",
}
local byName = {}
for _, page in ipairs(pages) do byName[page.name] = {name=page.name,items={}} end
for _, name in ipairs({"Crowds","List","Preview","Profiles"}) do byName[name] = {name=name,items={}} end
for _, page in ipairs(pages) do
  for _, item in ipairs(page.items) do
    local key = item[3] and item[3][2]
    local destination = item[3] and item[3][1]=="nameplates" and key and destinations[key]
      or (item[1]=="button" and "Preview") or page.name
    table.insert(byName[destination].items,item)
  end
end
byName.Crowds.items[1][2] = "Cluster similar enemies"
table.insert(byName.Crowds.items,{"slider","Start above this visible-plate count",{"nameplates","cluster_threshold"},10,100,1," plates"})
table.insert(byName.Crowds.items,{"slider","Count badge size multiplier",{"nameplates","cluster_count_scale"},1,3,.05,"x",2})
table.insert(byName.Crowds.items,{"color","Count badge colour / opacity",{"nameplates","cluster_count_color"}})
byName.List.items = {
  {"check","Show nearby-enemy list",{"combatlist","shown"}},
  {"check","Collapse the list",{"combatlist","collapsed"}},
  {"slider","List scale",{"combatlist","scale"},.5,2,.05,"x",2},
  {"slider","List opacity",{"combatlist","opacity"},.2,1,.05,"",2},
  {"slider","List width (0 = automatic)",{"combatlist","width"},0,420,10," px"},
}
table.insert(byName.Advanced.items,{"button","Dump target / mouseover layers",nil,function() if SlashCmdList.ZNPDUMP then SlashCmdList.ZNPDUMP() end end})
byName.Profiles.items={
  {"select","Copy settings from",{"profiles","source"},{{"New-character default","@default"}},"profiles"},
  {"button","Copy selected settings...",nil,function() Z.ShowSettingsConfirmation("ZNP_COPY_PROFILE") end},
  {"button","Use my settings as the default...",nil,function() Z.ShowSettingsConfirmation("ZNP_DEFAULT_PROFILE") end},
  {"button","Restore my pre-profile settings...",nil,function() Z.ShowSettingsConfirmation("ZNP_RESTORE_PROFILE") end},
}
byName.Profiles.items[1].help="Each character keeps its own saves. Other characters appear here after logging in with this version. Copies create restore points."
pages={}
for _, name in ipairs({"General","Health","Cast & Auras","Text","Appearance","Chat","Threat","Distance","Crowds","List","Preview","Profiles","Advanced"}) do
  local page=byName[name]
  local sections=sectionRules[name] or {{"Settings",""}}
  for _, item in ipairs(page.items) do
    local path=item[3]; local key=path and path[table.getn(path)]
    item.section=sections[table.getn(sections)][1]
    for _, rule in ipairs(sections) do
      if key and string.find(" "..rule[2].." "," "..key.." ",1,true) then item.section=rule[1]; break end
    end
    item.help=item.help or key and help[key]
    item[2]=string.gsub(item[2],"color","colour")
    if key=="notargalpha" then item[2]="Non-target opacity" end
    if path and path[1]=="throttle" then item.help="Data updates per second. Higher rates cost more CPU; visual movement remains smooth." end
    if path and path[1]=="nameplates" and key=="namefightcolor" then item[2]="Red names on hostile enemies in combat" end
  end
  local ordered={}
  for _, rule in ipairs(sections) do
    for _, item in ipairs(page.items) do if item.section==rule[1] then table.insert(ordered,item) end end
  end
  page.items=ordered; table.insert(pages,page)
end
Z.settingsPages=pages

local function GetValue(path)
  local value = Z.config
  if not value then return "" end
  for i = 1, table.getn(path) do value = value[path[i]] end
  return value
end

local history = {}
local function SetValue(path, value)
  local oldValue = GetValue(path)
  if tostring(oldValue)==tostring(value) then return end
  table.insert(history,{path=path,value=oldValue})
  if table.getn(history)>50 then table.remove(history,1) end
  local target = Z.config
  for i = 1, table.getn(path) - 1 do target = target[path[i]] end
  target[path[table.getn(path)]] = tostring(value)
  Z.Refresh()
end

local function DependencyEnabled(widget)
  local path=widget.path
  if not path then return true end
  local key=path[table.getn(path)]
  if path[1]=="platechat" and key~="enabled" then return GetValue({"platechat","enabled"})=="1" end
  local dependencies={
    targetzoomval="targetzoom", glowcolor="targetglow", highlightcolor="targethighlight",
    hptextpos="showhp", hptextformat="showhp", targetcastbar="showcastbar", spellname="showcastbar", heightcast="showcastbar",
    fontsize_friendly=nil, distance_min_scale="distance_scale", transition_duration="smooth_transitions", los_desaturation="los_fade",
    cluster_threshold="cluster_enabled", cluster_health_band="cluster_enabled", cluster_count_scale="cluster_enabled", cluster_count_color="cluster_enabled",
    showdebuffs_hostile="showdebuffs", showdebuffs_friendly="showdebuffs", owndebuffs="showdebuffs", debuffsize="showdebuffs", debuffoffset="showdebuffs",
  }
  if path[1]=="nameplates" and dependencies[key] then return GetValue({"nameplates",dependencies[key]})=="1" end
  if key=="fontstyle_combat" then return GetValue({"nameplates","name","fontstyle_combat_enabled"})=="1" end
  if path[1]=="global" and (key=="font_unit" or key=="font_unit_size") then return GetValue({"nameplates","use_unitfonts"})=="1" end
  if path[2]=="debuffs" and key=="blacklist" then return GetValue({"nameplates","debuffs","filter"})=="blacklist" end
  if path[2]=="debuffs" and key=="whitelist" then return GetValue({"nameplates","debuffs","filter"})=="whitelist" end
  return true
end

local frame = CreateFrame("Frame", "zNameplatesOptions", UIParent)
frame:SetWidth(820)
frame:SetHeight(560)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
-- Depth-sorted plates and their chat labels can reach DIALOG. An opaque panel
-- on FULLSCREEN occludes them without changing any world-plate depth ordering.
frame:SetFrameStrata("FULLSCREEN")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
frame:SetBackdrop({ bgFile="Interface\\BUTTONS\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=false, edgeSize=12, insets={left=4,right=4,top=4,bottom=4} })
frame:SetBackdropColor(.035,.045,.06,1)
frame:SetBackdropBorderColor(.2,.25,.3,1)
if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
title:SetText("zNameplates")
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
subtitle:SetText("Settings apply immediately")
subtitle:SetTextColor(0.75, 0.75, 0.75, 1)

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetTexture("Interface\\BUTTONS\\WHITE8X8")
divider:SetVertexColor(0.55, 0.55, 0.55, 0.25)
divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 158, -56)
divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 158, 50)
divider:SetWidth(1)

local closeX = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeX:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

local tabFrames = {}
local tabButtons = {}
local widgets = {}
local activeTab = 1
local searchText = ""
local scroll = CreateFrame("ScrollFrame","zNameplatesSettingsScroll",frame,"UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",170,-100)
scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-30,52)
local content=CreateFrame("Frame",nil,scroll)
content:SetWidth(620); content:SetHeight(1)
scroll:SetScrollChild(content)
local pageTitle=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
pageTitle:SetPoint("TOPLEFT",frame,"TOPLEFT",178,-60)
local pageDescription=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
pageDescription:SetPoint("TOPLEFT",pageTitle,"BOTTOMLEFT",0,-4)
pageDescription:SetWidth(600); pageDescription:SetJustifyH("LEFT")
pageDescription:SetTextColor(.65,.72,.8,1)
local search=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
search:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-60,-16)
search:SetWidth(225); search:SetHeight(24); search:SetAutoFocus(false)
local searchHint=search:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
searchHint:SetPoint("LEFT",search,"LEFT",5,0); searchHint:SetText("Search all settings...")
local clearSearch=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
clearSearch:SetPoint("LEFT",search,"RIGHT",4,0); clearSearch:SetWidth(22); clearSearch:SetHeight(22); clearSearch:SetText("x")
clearSearch:SetScript("OnClick",function() search:SetText(""); search:ClearFocus() end)
local sectionHeaders={}
local LayoutSettings
local function SkinButton(button)
  button:SetNormalTexture(""); button:SetPushedTexture(""); button:SetDisabledTexture("")
  button:SetBackdrop({bgFile="Interface\\BUTTONS\\WHITE8X8",edgeFile="Interface\\BUTTONS\\WHITE8X8",edgeSize=1})
  button:SetBackdropColor(.09,.12,.16,1); button:SetBackdropBorderColor(.22,.28,.35,1)
  button:SetHighlightTexture("Interface\\BUTTONS\\WHITE8X8")
  local highlight=button:GetHighlightTexture()
  if highlight then highlight:SetVertexColor(.25,.7,.65,.14) end
  local caption=button:GetFontString()
  if caption then caption:SetTextColor(.9,.94,.98,1) end
end
title:SetTextColor(.92,.97,1,1)

local function Label(parent, text, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetWidth(295)
  label:SetHeight(24)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetTextColor(0.95, 0.95, 0.95, 1)
  label:SetText(text)
  return label
end

local dropdown = CreateFrame("Frame", "zNameplatesOptionDropdown", frame)
dropdown:SetFrameStrata("TOOLTIP")
dropdown:SetFrameLevel(frame:GetFrameLevel() + 30)
dropdown:SetWidth(265)
if dropdown.SetClampedToScreen then dropdown:SetClampedToScreen(true) end
dropdown:SetBackdrop({
  bgFile = "Interface\\BUTTONS\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
dropdown:SetBackdropColor(.025, .025, .025, .97)
dropdown:SetBackdropBorderColor(.65, .65, .65, 1)
dropdown:EnableMouse(true)
dropdown:Hide()
local dropdownRows = {}

local function DropdownRowClick()
  if dropdown.path and this.value ~= nil then SetValue(dropdown.path, this.value) end
  dropdown:Hide()
end

local function OpenDropdown(widget)
  if dropdown:IsShown() and dropdown.owner == widget.control then
    dropdown:Hide()
    return
  end

  local values = widget.values or {}
  local count = table.getn(values)
  local height = count * 22 + 8
  dropdown.owner = widget.control
  dropdown.path = widget.path
  dropdown:SetHeight(height)
  dropdown:ClearAllPoints()
  local bottom = widget.control.GetBottom and widget.control:GetBottom()
  if bottom and bottom < height + 15 then
    dropdown:SetPoint("BOTTOMRIGHT", widget.control, "TOPRIGHT", 0, 2)
  else
    dropdown:SetPoint("TOPRIGHT", widget.control, "BOTTOMRIGHT", 0, -2)
  end

  for i = 1, count do
    local row = dropdownRows[i]
    if not row then
      row = CreateFrame("Button", nil, dropdown)
      row:SetHeight(22)
      row:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, -4 - (i - 1) * 22)
      row:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, -4 - (i - 1) * 22)
      row.highlight = row:CreateTexture(nil, "BACKGROUND")
      row.highlight:SetAllPoints(row)
      row.highlight:SetTexture("Interface\\BUTTONS\\WHITE8X8")
      row.highlight:SetVertexColor(.8, .58, .12, .18)
      row.highlight:Hide()
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", row, "LEFT", 7, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -7, 0)
      row.text:SetJustifyH("LEFT")
      row:SetScript("OnEnter", function() this.highlight:Show() end)
      row:SetScript("OnLeave", function() this.highlight:Hide() end)
      row:SetScript("OnClick", DropdownRowClick)
      dropdownRows[i] = row
    end
    row.value = values[i][2]
    row.text:SetText(values[i][1])
    row.text:SetTextColor(values[i][2] == GetValue(widget.path) and 1 or .9,
      values[i][2] == GetValue(widget.path) and .78 or .9,
      values[i][2] == GetValue(widget.path) and .2 or .9, 1)
    if widget.fontSelect then
      row.text:SetFont(values[i][2], 12, "")
    else
      if row.text.SetFontObject then row.text:SetFontObject(GameFontHighlightSmall)
      else row.text:SetFont(Z.font_default, 11, "") end
    end
    row:Show()
  end
  for i = count + 1, table.getn(dropdownRows) do dropdownRows[i]:Hide() end
  dropdown:Show()
end

frame:SetScript("OnHide", function() dropdown:Hide() end)

local function ApplyColor(path, oldValue, rgbOnly)
  local r, g, b = ColorPickerFrame:GetColorRGB()
  local a = rgbOnly and 1 or 1 - (ColorPickerFrame.opacity or 0)
  if oldValue and not r then SetValue(path, oldValue) else SetValue(path, r .. "," .. g .. "," .. b .. "," .. a) end
end

local function CreateWidget(parent, item, index)
  -- One bounded label/control row inside the clipped scroll viewport.
  local rowFrame=CreateFrame("Frame",nil,parent)
  rowFrame:SetWidth(620); rowFrame:SetHeight(item[1]=="preview" and 60 or item[1]=="slider" and 38 or 32)
  local separator=rowFrame:CreateTexture(nil,"BACKGROUND")
  separator:SetTexture("Interface\\BUTTONS\\WHITE8X8"); separator:SetVertexColor(.35,.4,.5,.13)
  separator:SetPoint("BOTTOMLEFT",rowFrame,"BOTTOMLEFT",8,0)
  separator:SetPoint("BOTTOMRIGHT",rowFrame,"BOTTOMRIGHT",-8,0); separator:SetHeight(1)
  parent=rowFrame
  local x,y=8,-7
  local kind, text, path, extra = item[1], item[2], item[3], item[4]
  local widget = { kind=kind, path=path, extra=extra, row=rowFrame, item=item }

  if kind == "check" then
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y + 5)
    check:SetWidth(22); check:SetHeight(22)
    local label = Label(parent, text, x + 27, y)
    label:SetWidth(545)
    check:SetScript("OnClick", function() SetValue(path, this:GetChecked() and "1" or "0") end)
    widget.control = check
    local labelButton=CreateFrame("Button",nil,parent)
    labelButton:SetPoint("TOPLEFT",parent,"TOPLEFT",x+27,y+5)
    labelButton:SetWidth(550); labelButton:SetHeight(28)
    labelButton:SetScript("OnClick",function() SetValue(path,GetValue(path)=="1" and "0" or "1") end)
    widget.labelButton=labelButton
  elseif kind == "button" then
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y + 2)
    button:SetWidth(260); button:SetHeight(24)
    button:SetText(text)
    button:SetScript("OnClick", function()
      if type(extra) == "function" then extra() end
    end)
    widget.control = button
    SkinButton(button)
  elseif kind == "slider" then
    local suffix = item[7] or "%"
    local decimals = item[8] or 0
    local multiplier = 10 ^ decimals
    local label = Label(parent, text, x, y)
    label:SetWidth(295)
    local sliderName = "zNameplatesOptionSlider" .. tostring(table.getn(widgets) + 1)
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 495, y + 2)
    slider:SetWidth(165); slider:SetHeight(16)
    slider:SetMinMaxValues(item[4] or 0, item[5] or 100)
    slider:SetValueStep(item[6] or 1)
    if getglobal then
      local low = getglobal(sliderName .. "Low")
      local high = getglobal(sliderName .. "High")
      local title = getglobal(sliderName .. "Text")
      if low then low:SetText((item[4] or 0) .. suffix); low:SetTextColor(.6,.66,.73,1) end
      if high then high:SetText((item[5] or 100) .. suffix); high:SetTextColor(.6,.66,.73,1) end
      if title then title:SetText("") end
    end
    slider:SetScript("OnValueChanged", function()
      local raw = tonumber(arg1) or this:GetValue() or 0
      local step = item[6] or 1
      local value = math.floor(raw / step + .5) * step
      value = math.floor(value * multiplier + .5) / multiplier
      local shown = decimals > 0 and string.format("%." .. decimals .. "f", value)
        or tostring(math.floor(value + .5))
      if widget.valueControl and not widget.valueControl.zNameplatesEditing then widget.valueControl:SetText(shown) end
      if not this.zNameplatesUpdating then SetValue(path, value) end
    end)
    widget.control = slider
    widget.label = label
    widget.text = text
    widget.suffix = suffix
    widget.decimals = decimals
    local exact=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    exact:SetPoint("TOPRIGHT",parent,"TOPLEFT",x+590,y+5)
    exact:SetWidth(70); exact:SetHeight(22); exact:SetAutoFocus(false)
    local function CommitNumber()
      local number=tonumber(exact:GetText())
      if number then
        number=math.max(item[4],math.min(item[5],number))
        number=math.floor(number/(item[6] or 1)+.5)*(item[6] or 1)
        SetValue(path,math.floor(number*multiplier+.5)/multiplier)
      else exact:SetText(GetValue(path)) end
    end
    exact:SetScript("OnEditFocusGained",function() this.zNameplatesEditing=true end)
    exact:SetScript("OnEnterPressed",function() CommitNumber(); exact:ClearFocus() end)
    exact:SetScript("OnEscapePressed",function() exact:SetText(GetValue(path)); exact:ClearFocus() end)
    exact:SetScript("OnEditFocusLost",function() exact.zNameplatesEditing=nil; CommitNumber() end)
    widget.valueControl=exact
  elseif kind == "input" then
    Label(parent, text, x, y)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 590, y + 5)
    input:SetWidth(265); input:SetHeight(24)
    input:SetAutoFocus(false)
    input:SetTextColor(1, 1, 1, 1)
    input:SetJustifyH("LEFT")
    local function Commit() SetValue(path, input:GetText()) end
    input:SetScript("OnEditFocusGained", function() this.zNameplatesEditing = true end)
    input:SetScript("OnEnterPressed", function() Commit(); this:ClearFocus() end)
    input:SetScript("OnEscapePressed", function() this:SetText(GetValue(path)); this:ClearFocus() end)
    input:SetScript("OnEditFocusLost", function()
      this.zNameplatesEditing = nil
      Commit()
    end)
    widget.control = input
  elseif kind == "select" then
    Label(parent, text, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 590, y + 3)
    button:SetWidth(265); button:SetHeight(24)
    local caption=button:GetFontString()
    if caption then caption:ClearAllPoints(); caption:SetPoint("LEFT",button,"LEFT",10,0); caption:SetPoint("RIGHT",button,"RIGHT",-24,0); caption:SetJustifyH("LEFT") end
    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    arrow:SetText("v")
    widget.values = item[4]
    widget.control = button
    widget.fontSelect = item[5] == "font"
    SkinButton(button)
    button:SetScript("OnClick", function() OpenDropdown(widget) end)
  elseif kind == "color" then
    Label(parent, text, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + 590, y + 3)
    button:SetWidth(265); button:SetHeight(24)
    button:SetText("   Edit colour")
    local swatchBorder = button:CreateTexture(nil, "ARTWORK")
    swatchBorder:SetPoint("LEFT", button, "LEFT", 7, 0)
    swatchBorder:SetWidth(18); swatchBorder:SetHeight(18)
    swatchBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    swatchBorder:SetVertexColor(.08, .08, .08, 1)
    local swatch = button:CreateTexture(nil, "OVERLAY")
    swatch:SetPoint("CENTER", swatchBorder, "CENTER", 0, 0); swatch:SetWidth(14); swatch:SetHeight(14)
    swatch:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    button:SetScript("OnClick", function()
      local oldValue = GetValue(path)
      local r, g, b, a = Z.GetStringColor(oldValue)
      local rgbOnly = item[5] == "rgb"
      ColorPickerFrame.func = function() ApplyColor(path, nil, rgbOnly) end
      ColorPickerFrame.opacityFunc = not rgbOnly and function() ApplyColor(path) end or nil
      ColorPickerFrame.cancelFunc = function() SetValue(path, oldValue) end
      ColorPickerFrame.hasOpacity = not rgbOnly
      ColorPickerFrame.opacity = 1 - (tonumber(a) or 1)
      ColorPickerFrame:SetColorRGB(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
      RaiseSettingsDialog(ColorPickerFrame)
      ColorPickerFrame:Show()
    end)
    widget.control = button
    widget.swatch = swatch
    SkinButton(button)
  elseif kind == "preview" then
    local preview = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    preview:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)
    preview:SetWidth(585); preview:SetHeight(48)
    preview:SetJustifyH("CENTER")
    preview:SetText(text)
    widget.control = preview
  end
  if kind~="preview" then
    widget.control:SetScript("OnEnter",function()
      GameTooltip:SetOwner(widget.control,"ANCHOR_RIGHT")
      GameTooltip:SetText(text)
      if item.help then GameTooltip:AddLine(item.help,.7,.78,.86,true) end
      if path then GameTooltip:AddLine(table.concat(path," / "),.45,.5,.6,true) end
      GameTooltip:Show()
    end)
    widget.control:SetScript("OnLeave",function() GameTooltip:Hide() end)
  end
  table.insert(widgets, widget)
  return widget
end

local function ShowTab(index)
  dropdown:Hide()
  activeTab = index
  if searchText~="" then search:SetText("") end
  for i = 1, table.getn(tabFrames) do
    local selected=i==index
    tabButtons[i].selected:SetShown(selected)
  end
  scroll:SetVerticalScroll(0)
  if LayoutSettings then LayoutSettings() end
  frame:Refresh()
end

for pageIndex = 1, table.getn(pages) do
  local tabIndex = pageIndex
  local pageData = pages[pageIndex]
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -60-(pageIndex-1)*30)
  button:SetWidth(136); button:SetHeight(26); button:SetText(pageData.name)
  SkinButton(button)
  button.selected=button:CreateTexture(nil,"OVERLAY")
  button.selected:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  button.selected:SetVertexColor(.2,.82,.72,1)
  button.selected:SetPoint("TOPLEFT",button,"TOPLEFT",0,0); button.selected:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",0,0); button.selected:SetWidth(3)
  button:SetScript("OnClick", function() ShowTab(tabIndex) end)
  tabButtons[pageIndex] = button

  tabFrames[pageIndex] = content
  for itemIndex = 1, table.getn(pageData.items) do
    local widget=CreateWidget(content,pageData.items[itemIndex],itemIndex)
    widget.page=pageIndex
  end
end

LayoutSettings=function()
  local y,headers,matches=0,0,0
  local previousSection
  for _, widget in ipairs(widgets) do
    local page=pages[widget.page]
    local haystack=string.lower(page.name.." "..widget.item.section.." "..widget.item[2].." "..(widget.item.help or "")
      .." "..(widget.path and table.concat(widget.path," ") or ""))
    local visible=searchText~="" and string.find(haystack,searchText,1,true) or (searchText=="" and widget.page==activeTab)
    if visible then
      local section=page.name.." / "..widget.item.section
      if section~=previousSection then
        headers=headers+1
        local header=sectionHeaders[headers]
        if not header then header=Label(content,"",12,0); sectionHeaders[headers]=header end
        header:ClearAllPoints(); header:SetPoint("TOPLEFT",content,"TOPLEFT",8,-y-4)
        header:SetWidth(600); header:SetHeight(18); header:SetText(searchText~="" and section or widget.item.section)
        header:SetTextColor(.3,.86,.76,1); header:Show()
        y=y+22; previousSection=section
      end
      widget.row:ClearAllPoints(); widget.row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y)
      widget.row:Show(); y=y+widget.row:GetHeight(); matches=matches+1
    else widget.row:Hide() end
  end
  for i=headers+1,table.getn(sectionHeaders) do sectionHeaders[i]:Hide() end
  content:SetHeight(math.max(1,y+12))
  pageTitle:SetText(searchText~="" and "Search results" or pages[activeTab].name)
  pageDescription:SetText(searchText~="" and (matches.." matching controls across all categories") or descriptions[pages[activeTab].name])
end
search:SetScript("OnTextChanged",function()
  searchText=string.lower(search:GetText() or "")
  if searchText=="" then searchHint:Show() else searchHint:Hide() end
  dropdown:Hide(); scroll:SetVerticalScroll(0); LayoutSettings()
end)
search:SetScript("OnEscapePressed",function() search:SetText(""); search:ClearFocus() end)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel",function()
  dropdown:Hide()
  local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
  scroll:SetVerticalScroll(math.max(0,math.min(maximum,scroll:GetVerticalScroll()-(arg1 or 0)*56)))
end)

local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
reset:SetWidth(104); reset:SetHeight(24); reset:SetText("Reset all...")
local pendingPage
StaticPopupDialogs=StaticPopupDialogs or {}
StaticPopupDialogs.ZNP_RESET_ALL={text="Reset all zNameplates settings? Your current settings will be replaced.",button1="Reset all",button2="Cancel",
  OnAccept=function() table.wipe(history); Z.Reset() end,timeout=0,whileDead=1,hideOnEscape=1}
StaticPopupDialogs.ZNP_COPY_PROFILE={text="Copy the selected settings into this character? A restore point is kept; the source character is not changed.",button1="Copy settings",button2="Cancel",
  OnAccept=function() table.wipe(history); Z.CopyCharacterProfile(GetValue({"profiles","source"})) end,timeout=0,whileDead=1,hideOnEscape=1}
StaticPopupDialogs.ZNP_DEFAULT_PROFILE={text="Use this character's settings as the default for new characters? Existing characters will keep their own settings.",button1="Set default",button2="Cancel",
  OnAccept=function() Z.SetNewCharacterDefault() end,timeout=0,whileDead=1,hideOnEscape=1}
StaticPopupDialogs.ZNP_RESTORE_PROFILE={text="Restore the settings this character had before profiles were added? The current settings are kept as a restore point.",button1="Restore",button2="Cancel",
  OnAccept=function() table.wipe(history); Z.RestoreOriginalCharacterProfile() end,timeout=0,whileDead=1,hideOnEscape=1}
StaticPopupDialogs.ZNP_RESET_PAGE={text="Reset this category's settings to their defaults? Other categories will not change.",button1="Reset category",button2="Cancel",
  OnAccept=function()
    local page=pages[pendingPage]
    if not page then return end
    for _, item in ipairs(page.items) do
      if item[3] then
        local value=Z.GetDefaultSetting(item[3])
        if value~=nil then
          local target=Z.config
          for i=1,table.getn(item[3])-1 do target=target[item[3][i]] end
          target[item[3][table.getn(item[3])]]=tostring(value)
        end
      end
    end
    table.wipe(history); Z.Refresh()
  end,timeout=0,whileDead=1,hideOnEscape=1}
reset:SetScript("OnClick",function() Z.ShowSettingsConfirmation("ZNP_RESET_ALL") end)
local resetPage=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
resetPage:SetPoint("LEFT",reset,"RIGHT",6,0); resetPage:SetWidth(120); resetPage:SetHeight(24); resetPage:SetText("Reset category...")
resetPage:SetScript("OnClick",function() pendingPage=activeTab; Z.ShowSettingsConfirmation("ZNP_RESET_PAGE") end)
local undo=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
undo:SetPoint("LEFT",resetPage,"RIGHT",6,0); undo:SetWidth(88); undo:SetHeight(24); undo:SetText("Undo last")
undo:SetScript("OnClick",function()
  local entry=table.remove(history)
  if not entry then return end
  local target=Z.config
  for i=1,table.getn(entry.path)-1 do target=target[entry.path[i]] end
  target[entry.path[table.getn(entry.path)]]=entry.value
  Z.Refresh()
end)

local reload = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reload:SetPoint("LEFT", undo, "RIGHT", 6, 0)
reload:SetWidth(88); reload:SetHeight(24); reload:SetText("Reload UI")
reload:SetScript("OnClick", ReloadUI)

local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
close:SetWidth(88); close:SetHeight(24); close:SetText("Close")
close:SetScript("OnClick", function() frame:Hide() end)
for _,button in ipairs({reset,resetPage,undo,reload,close,clearSearch}) do SkinButton(button) end
local status=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
status:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",12,42)
status:SetTextColor(.55,.64,.72,1)

local function MediaKey(value)
  value=string.lower(tostring(value or ""))
  value=string.gsub(value,"%.tga$",""); value=string.gsub(value,"%.blp$","")
  return value
end

function frame:Refresh()
  if not Z.config then return end
  frame:SetScale(math.min(1,(UIParent:GetWidth()-24)/820,(UIParent:GetHeight()-24)/560))
  if table.getn(history)>0 then undo:Enable() else undo:Disable() end
  status:SetText("Profile: "..(Z.activeCharacterProfile or "this character").."  |  zAPI: "..(type(zAPI)=="function" and "available" or "not loaded").."  |  LOS: "..(type(UnitXP)=="function" and "available" or "not loaded"))
  for i = 1, table.getn(widgets) do
    local widget = widgets[i]
    local enabled=DependencyEnabled(widget)
    widget.row:SetAlpha(enabled and 1 or .45)
    if widget.control.Enable and widget.control.Disable then
      if enabled then widget.control:Enable() else widget.control:Disable() end
    end
    if widget.control.EnableMouse and widget.kind~="preview" then widget.control:EnableMouse(enabled) end
    if widget.valueControl then widget.valueControl:EnableMouse(enabled) end
    if widget.labelButton then widget.labelButton:EnableMouse(enabled) end
    if widget.path then
      local value = GetValue(widget.path)
      if widget.kind == "check" then widget.control:SetChecked(value == "1")
      elseif widget.kind == "slider" then
        local amount = tonumber(value) or 60
        widget.control.zNameplatesUpdating = true
        widget.control:SetValue(amount)
        widget.control.zNameplatesUpdating = nil
        local shown = widget.decimals > 0 and string.format("%." .. widget.decimals .. "f", amount)
          or tostring(math.floor(amount + .5))
        widget.label:SetText(widget.text)
        if widget.valueControl and not widget.valueControl.zNameplatesEditing then widget.valueControl:SetText(shown) end
      elseif widget.kind == "input" and not widget.control.zNameplatesEditing then widget.control:SetText(value or "")
      elseif widget.kind == "select" then
        if widget.item[5]=="profiles" and Z.GetCharacterProfileChoices then widget.values=Z.GetCharacterProfileChoices() end
        local label = tostring(value or "")
        for j = 1, table.getn(widget.values) do if MediaKey(widget.values[j][2]) == MediaKey(value) then label = widget.values[j][1] end end
        if string.find(label,"\\",1,true) then label=string.gsub(label,"^.*\\",""); label=string.gsub(label,"%.[^%.]+$","") end
        widget.control:SetText(label)
        if widget.fontSelect and widget.control.GetFontString then
          local selection = widget.control:GetFontString()
          if selection then selection:SetFont(value, 11, "") end
        end
      elseif widget.kind == "color" then
        local r, g, b = Z.GetStringColor(value)
        widget.swatch:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
      end
    elseif widget.kind == "preview" then
      local useUnit = Z.config.nameplates.use_unitfonts == "1"
      local font = useUnit and Z.font_unit or Z.font_default
      local isFriendly = widget.extra == "friendly"
      local isCombat = widget.extra == "combat"
      local customSize = isFriendly
        and (Z.config.nameplates.name.fontsize_friendly or Z.config.nameplates.name.fontsize)
        or Z.config.nameplates.name.fontsize
      local size = tonumber(customSize)
        or tonumber(useUnit and Z.config.global.font_unit_size or Z.config.global.font_size)
        or 10
      local style = isCombat
        and (Z.config.nameplates.name.fontstyle_combat or Z.config.nameplates.name.fontstyle or "")
        or (isFriendly
          and (Z.config.nameplates.name.fontstyle_friendly or Z.config.nameplates.name.fontstyle or "")
          or (Z.config.nameplates.name.fontstyle or ""))
      widget.control:SetFont(font, size, style)
      widget.control:SetAlpha(isCombat and Z.config.nameplates.name.fontstyle_combat_enabled ~= "1" and .45 or 1)
    end
  end
end

frame:SetScript("OnShow", function() frame:Refresh() end)
ShowTab(activeTab)
Z.options = frame

SLASH_ZNAMEPLATES1 = "/znp"
SLASH_ZNAMEPLATES2 = "/znameplates"
SlashCmdList["ZNAMEPLATES"] = function(message)
  local command = string.lower(message or "")
  command = string.gsub(command, "^%s+", "")
  command = string.gsub(command, "%s+$", "")
  if command == "list" then
    if Z.ToggleCombatList then Z.ToggleCombatList() end
  elseif frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

-- Keep the combat-list implementation inside an existing addon file. The
-- OctoWoW client can reject Lua filenames created after the game started,
-- even when /reload successfully picks up edits to files it already knows.
do
  local listTotemButtons = {}
  local listTotemEntries = {}
  local listTotemCount = 0
  local listMainEntries = {}
  local listMainCount = 0
  local listTaggedEntries = {}
  local listTaggedCount = 0
  local listRows = {}
  local LIST_HEADER_HEIGHT = 18
  local LIST_PADDING = 4

  local list = CreateFrame("Frame", "zNameplatesCombatList", UIParent)
  list:SetFrameStrata("MEDIUM")
  list:SetWidth(160)
  list:SetHeight(LIST_HEADER_HEIGHT + 18)
  list:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -32, -180)
  list:SetMovable(true)
  list:EnableMouse(true)
  if list.SetClampedToScreen then list:SetClampedToScreen(true) end
  list:Hide()

  local listHeader = CreateFrame("Button", nil, list)
  listHeader:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1)
  listHeader:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, -1)
  listHeader:SetHeight(LIST_HEADER_HEIGHT - 1)
  listHeader:RegisterForDrag("LeftButton")
  listHeader:SetScript("OnDragStart", function() list:StartMoving() end)

  local listCount = listHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listCount:SetPoint("LEFT", listHeader, "LEFT", 4, 0)
  listCount:SetTextColor(.75, .75, .75, 1)
  listCount:SetText("(0)")

  local listCollapse = CreateFrame("Button", nil, listHeader)
  listCollapse:SetPoint("RIGHT", listHeader, "RIGHT", -19, 0)
  listCollapse:SetWidth(17)
  listCollapse:SetHeight(16)
  listCollapse.text = listCollapse:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  listCollapse.text:SetAllPoints(listCollapse)
  listCollapse.text:SetText("-")

  local listClose = CreateFrame("Button", nil, listHeader)
  listClose:SetPoint("RIGHT", listHeader, "RIGHT", -2, 0)
  listClose:SetWidth(16)
  listClose:SetHeight(16)
  listClose.text = listClose:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  listClose.text:SetAllPoints(listClose)
  listClose.text:SetText("x")
  listClose.text:SetTextColor(.9, .38, .38, 1)
  listClose:SetScript("OnClick", function() list:Hide() end)

  local listDivider = list:CreateTexture(nil, "ARTWORK")
  listDivider:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  listDivider:SetVertexColor(.45, .45, .45, .45)
  listDivider:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -LIST_HEADER_HEIGHT)
  listDivider:SetPoint("TOPRIGHT", list, "TOPRIGHT", -3, -LIST_HEADER_HEIGHT)
  listDivider:SetHeight(1)

  local listTaggedDivider = list:CreateTexture(nil, "ARTWORK")
  listTaggedDivider:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  listTaggedDivider:SetVertexColor(.45, .45, .45, .4)
  listTaggedDivider:SetHeight(1)
  listTaggedDivider:Hide()

  local listEmpty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  listEmpty:SetPoint("TOP", list, "TOP", 0, -LIST_HEADER_HEIGHT - 5)
  listEmpty:SetText("No enemies in combat")

  local function ListSettings()
    return Z.config and Z.config.combatlist
  end

  listHeader:SetScript("OnDragStop", function()
    list:StopMovingOrSizing()
    local settings = ListSettings()
    if not settings or not list.GetPoint then return end
    local point, _, relativePoint, x, y = list:GetPoint()
    settings.point = point or "TOPRIGHT"
    settings.relativePoint = relativePoint or settings.point
    settings.x = tostring(x or -32)
    settings.y = tostring(y or -180)
  end)

  local TOTEM_ICONS = {
    ["strength of earth totem"] = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    ["stoneskin totem"] = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    ["stoneclaw totem"] = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
    ["earthbind totem"] = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    ["tremor totem"] = "Interface\\Icons\\Spell_Nature_TremorTotem",
    ["searing totem"] = "Interface\\Icons\\Spell_Fire_SearingTotem",
    ["magma totem"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    ["fire nova totem"] = "Interface\\Icons\\Spell_Fire_SealOfFire",
    ["flametongue totem"] = "Interface\\Icons\\Spell_Nature_GuardianWard",
    ["frost resistance totem"] = "Interface\\Icons\\Spell_FrostResistanceTotem_01",
    ["healing stream totem"] = "Interface\\Icons\\INV_Spear_04",
    ["mana spring totem"] = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    ["mana tide totem"] = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    ["poison cleansing totem"] = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
    ["disease cleansing totem"] = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem",
    ["fire resistance totem"] = "Interface\\Icons\\Spell_FireResistanceTotem_01",
    ["grounding totem"] = "Interface\\Icons\\Spell_Nature_GroundingTotem",
    ["windfury totem"] = "Interface\\Icons\\Spell_Nature_Windfury",
    ["grace of air totem"] = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
    ["nature resistance totem"] = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",
    ["windwall totem"] = "Interface\\Icons\\Spell_Nature_EarthBind",
    ["tranquil air totem"] = "Interface\\Icons\\Spell_Nature_Brilliance",
  }

  local function GetTotemTexture(plate, name)
    if plate and plate.totemIcon and plate.totemIcon ~= "" then return plate.totemIcon end
    if plate and plate.totem and plate.totem.icon and plate.totem.icon.GetTexture then
      local tex = plate.totem.icon:GetTexture()
      if tex and tex ~= "" then return tex end
    end
    if plate and plate.cachedGuid and C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
      local aura = C_UnitAuras.GetBuffDataByIndex(plate.cachedGuid, 1)
      if aura and aura.icon and aura.icon ~= "" then return aura.icon end
    end
    local cleanName = string.lower(name or "")
    cleanName = string.gsub(cleanName, "%s+[%d%a]+$", "")
    cleanName = string.gsub(cleanName, "^%s+", "")
    cleanName = string.gsub(cleanName, "%s+$", "")
    if TOTEM_ICONS[cleanName] then return TOTEM_ICONS[cleanName] end
    for key, tex in pairs(TOTEM_ICONS) do
      if string.find(cleanName, key, 1, true) then return tex end
    end
    if string.find(cleanName, "heal", 1, true) then return "Interface\\Icons\\INV_Spear_04" end
    return "Interface\\Icons\\Spell_Nature_EarthBindTotem"
  end

  local function IsPlateTotem(plate, name)
    if not plate then return false end
    if plate.isTotem then return true end
    if plate.cachedGuid and UnitCreatureTypeID and UnitCreatureTypeID(plate.cachedGuid) == 11 then return true end
    local unit = plate.unit
    if unit and UnitCreatureType and UnitCreatureType(unit) == "Totem" then return true end
    if name and string.find(name, "Totem", 1, true) then return true end
    return false
  end

  local function StartTargetAttack()
    if SlashCmdList and SlashCmdList.STARTATTACK then SlashCmdList.STARTATTACK("")
    else
      local inCombat = (PlayerFrame and PlayerFrame.inCombat) or (Z.nameplates and Z.nameplates.combat and Z.nameplates.combat.inCombat)
      if AttackTarget and UnitCanAttack("player", "target") and not inCombat then AttackTarget() end
    end
  end

  local function SendPetAttack(unit)
    if not UnitExists("pet") or (UnitIsDead and UnitIsDead("pet")) then return end
    if not unit or not UnitExists(unit) then return end
    if UnitIsUnit and UnitIsUnit("target", unit) then
      if PetAttack then PetAttack() end
      return
    end
    local hadTarget = UnitExists("target")
    TargetUnit(unit)
    if PetAttack then PetAttack() end
    if hadTarget then TargetLastTarget() else ClearTarget() end
  end

  local function HandleRowClick(unit)
    if not unit or not UnitExists(unit) then return end
    if arg1 == "RightButton" then SendPetAttack(unit)
    else TargetUnit(unit); StartTargetAttack() end
  end

  local function ListPlateLevel(plate)
    local level = plate.unit and UnitLevel and UnitLevel(plate.unit)
    if level and level > 0 then return level end
    local label = plate.level and plate.level.GetText and plate.level:GetText()
    local _, _, number = string.find(label or "", "(%d+)")
    if number then return tonumber(number) end
    if level == -1 or (label and string.find(label, "?", 1, true)) then return 999 end
    return 0
  end

  local function TotemCompare(left, right)
    local leftHeal = string.find(left.name, "heal", 1, true) and 1 or 0
    local rightHeal = string.find(right.name, "heal", 1, true) and 1 or 0
    if leftHeal ~= rightHeal then return leftHeal > rightHeal end
    if left.name ~= right.name then return left.name < right.name end
    return left.guid < right.guid
  end

  local function ListCompare(left, right)
    if left.tagged ~= right.tagged then return left.tagged < right.tagged end
    if left.level ~= right.level then return left.level > right.level end
    if left.name ~= right.name then return left.name < right.name end
    return left.guid < right.guid
  end

  local function SortEntries(entries, count, compareFunc)
    for i = 2, count do
      local entry = entries[i]
      local index = i - 1
      while index >= 1 and compareFunc(entry, entries[index]) do
        entries[index + 1] = entries[index]
        index = index - 1
      end
      entries[index + 1] = entry
    end
  end

  local function IsEnemyAttackable(plate, unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDead and UnitIsDead(unit) then return false end
    if plate and plate.isCritter then return false end
    if plate and plate.isFriendly then return false end
    if UnitCanAttack and not UnitCanAttack("player", unit) then return false end
    if UnitIsFriend and UnitIsFriend("player", unit) then return false end
    if UnitCanAssist and UnitCanAssist("player", unit) then return false end
    if UnitPlayerOrPetInParty and UnitPlayerOrPetInParty(unit) then return false end
    if UnitPlayerOrPetInRaid and UnitPlayerOrPetInRaid(unit) then return false end
    if UnitIsUnit and (UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet")) then return false end
    if UnitReaction then
      local reaction = UnitReaction("player", unit)
      if reaction and reaction >= 5 then return false end
    end
    return true
  end

  local function BuildCombatList()
    for index = listTotemCount, 1, -1 do listTotemEntries[index] = nil end
    listTotemCount = 0
    for index = listMainCount, 1, -1 do listMainEntries[index] = nil end
    listMainCount = 0
    for index = listTaggedCount, 1, -1 do listTaggedEntries[index] = nil end
    listTaggedCount = 0

    local visible = Z.nameplates and Z.nameplates.visiblePlates
    if not visible then return 0 end
    for base in pairs(visible) do
      local plate = base and base.nameplate
      if plate and plate.unit and (not base.IsVisible or base:IsVisible()) then
        local unit = plate.unit
        if IsEnemyAttackable(plate, unit) then
          local guid = plate.cachedGuid or plate.unit
          local name = (plate.name and plate.name.GetText and plate.name:GetText()) or (UnitName and UnitName(unit)) or "Unknown"
          if IsPlateTotem(plate, name) then
            listTotemCount = listTotemCount + 1
            listTotemEntries[listTotemCount] = { plate=plate, guid=tostring(guid), name=string.lower(name), icon=GetTotemTexture(plate, name), unit=unit }
          elseif UnitAffectingCombat and UnitAffectingCombat(unit) then
            local isTaggedOther = plate.taggedByOther or (UnitIsTapped and UnitIsTappedByPlayer and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit))
            local entry = { plate=plate, guid=tostring(guid), name=string.lower(name), level=ListPlateLevel(plate), tagged=(plate.taggedByPlayer or plate.taggedByOther) and 1 or 0 }
            if isTaggedOther then
              listTaggedCount = listTaggedCount + 1
              listTaggedEntries[listTaggedCount] = entry
            else
              listMainCount = listMainCount + 1
              listMainEntries[listMainCount] = entry
            end
          end
        end
      end
    end
    SortEntries(listTotemEntries, listTotemCount, TotemCompare)
    SortEntries(listMainEntries, listMainCount, ListCompare)
    SortEntries(listTaggedEntries, listTaggedCount, ListCompare)
    return listTotemCount + listMainCount + listTaggedCount
  end

  local function SetListFont(text, source, fallbackSize)
    local font, size, flags
    if source and source.GetFont then font, size, flags = source:GetFont() end
    -- Plate labels use 4x glyphs on a quarter-scale surface. List rows are
    -- unscaled: copy the logical text size, not that backing font size.
    if source and source.zSmoothFrame and tonumber(size) then size = tonumber(size) / 4 end
    if not font then
      local useUnit = Z.config.nameplates.use_unitfonts == "1"
      font = useUnit and Z.font_unit or Z.font_default
      size = tonumber(useUnit and Z.config.global.font_unit_size or Z.config.global.font_size)
      flags = Z.config.nameplates.name.fontstyle
    end
    if font and font ~= "" then text:SetFont(font, math.max(8, tonumber(size) or fallbackSize or 11), flags or "") end
  end

  local function SetListTextColor(destination, source, r, g, b, a)
    if source and source.GetTextColor then
      local sr, sg, sb, sa = source:GetTextColor()
      if sr then r, g, b, a = sr, sg, sb, sa end
    end
    destination:SetTextColor(r or 1, g or 1, b or 1, a or 1)
  end

  local function UpdateListRaidIcon(row, plate)
    local icon = row.raidicon
    local raidIndex
    if GetRaidTargetIndex and plate.unit then raidIndex = GetRaidTargetIndex(plate.unit) end
    if not raidIndex and plate.raidIndex then raidIndex = plate.raidIndex end
    if raidIndex then
      icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
      if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(icon, raidIndex)
      else
        local left = math.mod(raidIndex - 1, 4) * .25
        local top = math.floor((raidIndex - 1) / 4) * .25
        icon:SetTexCoord(left, left + .25, top, top + .25)
      end
      icon:Show()
      return
    end
    local source = plate.raidicon
    if source and source.IsShown and source:IsShown() and source.GetTexture and source:GetTexture() then
      icon:SetTexture(source:GetTexture())
      if source.GetTexCoord then icon:SetTexCoord(source.GetTexCoord()) end
      icon:Show()
    else icon:Hide() end
  end

  local function CreateTotemButton(index)
    local btn = CreateFrame("Button", nil, list)
    btn:SetWidth(26); btn:SetHeight(26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(.078, .92, .079, .937)
    Z.CreateBackdrop(btn, 1)
    btn:SetScript("OnClick", function() HandleRowClick(this.unit) end)
    btn:SetScript("OnEnter", function()
      if this.unit and UnitExists(this.unit) then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(this.unit)
        GameTooltip:Show()
      elseif this.name then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.name, 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    listTotemButtons[index] = btn
    return btn
  end

  local function CreateListRow(index)
    local row = CreateFrame("Button", nil, list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function() HandleRowClick(this.unit) end)
    row.health = CreateFrame("StatusBar", nil, row)
    row.health:SetFrameLevel(row:GetFrameLevel() + 1)
    row.health:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 20, 2)
    row.health:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 2)
    Z.CreateBackdrop(row.health, 1)
    row.raidicon = row:CreateTexture(nil, "OVERLAY")
    row.raidicon:SetPoint("BOTTOMRIGHT", row.health, "TOPRIGHT", -1, 1)
    row.raidicon:SetWidth(10); row.raidicon:SetHeight(10); row.raidicon:SetAlpha(.55); row.raidicon:Hide()
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("BOTTOMLEFT", row.health, "TOPLEFT", 0, 1)
    row.name:SetPoint("BOTTOMRIGHT", row.health, "TOPRIGHT", -13, 1)
    row.name:SetJustifyH("CENTER")
    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.level:SetPoint("RIGHT", row.health, "LEFT", -2, 0)
    row.level:SetJustifyH("RIGHT")
    row.healthText = row.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.healthText:SetAllPoints(row.health)
    row.healthText:SetJustifyH("CENTER")
    listRows[index] = row
    return row
  end

  local function UpdateListRow(row, entry, topOffset, rowHeight, width)
    local plate, health = entry.plate, entry.plate.health
    row.unit, row.plate = plate.unit, plate
    row:SetWidth(width - LIST_PADDING * 2)
    row:SetHeight(rowHeight)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PADDING, topOffset)
    row.health:SetHeight(math.max(5, tonumber(Z.config.nameplates.heighthealth) or 8))
    row.health:SetStatusBarTexture(Z.media[Z.config.nameplates.healthtexture])
    if health and health.GetMinMaxValues and health.GetValue then
      local minimum, maximum = health:GetMinMaxValues()
      if not maximum or maximum <= (minimum or 0) then minimum, maximum = 0, 1 end
      row.health:SetMinMaxValues(minimum or 0, maximum)
      row.health:SetValue(health:GetValue() or minimum or 0)
    else row.health:SetMinMaxValues(0, 1); row.health:SetValue(1) end
    if health and health.GetStatusBarColor then
      local r, g, b, a = health:GetStatusBarColor()
      row.health:SetStatusBarColor(r or .9, g or .2, b or .3, a or 1)
    end
    if health and health.backdrop and health.backdrop.GetBackdropBorderColor then
      local r, g, b, a = health.backdrop:GetBackdropBorderColor()
      row.health.backdrop:SetBackdropBorderColor(r or .2, g or .2, b or .2, a or 1)
    elseif plate.taggedByPlayer then row.health.backdrop:SetBackdropBorderColor(.35, 1, .05, .75)
    else row.health.backdrop:SetBackdropBorderColor(Z.GetStringColor(Z.config.appearance.border.color)) end
    SetListFont(row.name, plate.name, 11)
    SetListFont(row.level, plate.level, 10)
    SetListFont(row.healthText, health and health.text, 9)
    row.name:SetText(plate.name and plate.name:GetText() or UnitName(plate.unit) or "Unknown")
    row.level:SetText(plate.level and plate.level:GetText() or (entry.level == 999 and "??" or entry.level))
    SetListTextColor(row.name, plate.name, 1, 1, 1, 1)
    SetListTextColor(row.level, plate.level, 1, 1, .2, 1)
    UpdateListRaidIcon(row, plate)
    local sourceText = health and health.text
    local healthText = sourceText and sourceText.GetText and sourceText:GetText()
    if Z.config.nameplates.showhp == "1" and healthText and healthText ~= "" then
      row.healthText:SetText(healthText)
      SetListTextColor(row.healthText, sourceText, 1, 1, 1, 1)
      row.healthText:Show()
    else row.healthText:Hide() end
    row:Show()
  end

  function list:Refresh()
    local settings = ListSettings()
    if not settings then return end
    if settings.shown=="1" and not self:IsShown() then self:Show()
    elseif settings.shown=="0" and self:IsShown() then self:Hide(); return end
    self:SetScale(tonumber(settings.scale) or 1)
    self:SetAlpha(tonumber(settings.opacity) or 1)
    local customWidth=tonumber(settings.width) or 0
    local width = customWidth>0 and math.max(160,customWidth)
      or math.max(160, math.max(75, tonumber(Z.config.nameplates.width) or 120) + 20 + LIST_PADDING * 2 + 1)
    local fontSize = tonumber((Z.config.nameplates.use_unitfonts == "1") and Z.config.global.font_unit_size or Z.config.global.font_size) or 12
    local rowHeight = fontSize + math.max(5, tonumber(Z.config.nameplates.heighthealth) or 8) + 5
    local total = BuildCombatList()
    self:SetWidth(width)
    listCount:SetText("(" .. total .. ")")
    Z.CreateBackdrop(self, 0)
    if settings.collapsed == "1" then
      listCollapse.text:SetText("+")
      listDivider:Hide()
      listEmpty:Hide()
      listTaggedDivider:Hide()
      self:SetHeight(LIST_HEADER_HEIGHT + 1)
      for i = 1, table.getn(listTotemButtons) do listTotemButtons[i]:Hide() end
      for i = 1, table.getn(listRows) do listRows[i]:Hide() end
      return
    end
    listCollapse.text:SetText("-")
    listDivider:Show()
    if total == 0 then
      self:SetHeight(LIST_HEADER_HEIGHT + 18)
      listEmpty:Show()
      listTaggedDivider:Hide()
      for i = 1, table.getn(listTotemButtons) do listTotemButtons[i]:Hide() end
      for i = 1, table.getn(listRows) do listRows[i]:Hide() end
      return
    end
    listEmpty:Hide()
    local currentY = -LIST_HEADER_HEIGHT - 4
    if listTotemCount > 0 then
      local totemSize, totemGap = 26, 4
      local totemStartX = LIST_PADDING + math.max(0, math.floor((width - LIST_PADDING * 2 - (4 * totemSize + 3 * totemGap)) / 2))
      for i = 1, listTotemCount do
        local btn = listTotemButtons[i] or CreateTotemButton(i)
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self, "TOPLEFT", totemStartX + col * (totemSize + totemGap), currentY - row * (totemSize + totemGap))
        btn.unit, btn.name = listTotemEntries[i].unit, (listTotemEntries[i].plate.name and listTotemEntries[i].plate.name:GetText() or listTotemEntries[i].name)
        btn.icon:SetTexture(listTotemEntries[i].icon)
        btn:Show()
      end
      currentY = currentY - (math.ceil(listTotemCount / 4) * (totemSize + totemGap)) - 2
    end
    for i = listTotemCount + 1, table.getn(listTotemButtons) do listTotemButtons[i]:Hide() end
    for i = 1, listMainCount do
      local row = listRows[i] or CreateListRow(i)
      UpdateListRow(row, listMainEntries[i], currentY - (i - 1) * rowHeight, rowHeight, width)
    end
    currentY = currentY - (listMainCount * rowHeight)
    if listTaggedCount > 0 then
      if listMainCount > 0 or listTotemCount > 0 then
        listTaggedDivider:ClearAllPoints()
        listTaggedDivider:SetPoint("TOPLEFT", self, "TOPLEFT", LIST_PADDING + 4, currentY - 2)
        listTaggedDivider:SetPoint("TOPRIGHT", self, "TOPRIGHT", -LIST_PADDING - 4, currentY - 2)
        listTaggedDivider:Show()
        currentY = currentY - 5
      else listTaggedDivider:Hide() end
      for j = 1, listTaggedCount do
        local row = listRows[listMainCount + j] or CreateListRow(listMainCount + j)
        UpdateListRow(row, listTaggedEntries[j], currentY - (j - 1) * rowHeight, rowHeight, width)
      end
      currentY = currentY - (listTaggedCount * rowHeight)
    else listTaggedDivider:Hide() end
    for i = listMainCount + listTaggedCount + 1, table.getn(listRows) do listRows[i]:Hide() end
    self:SetHeight(-currentY + 4)
  end

  listCollapse:SetScript("OnClick", function()
    local settings = ListSettings()
    if not settings then return end
    settings.collapsed = settings.collapsed == "1" and "0" or "1"
    list:Refresh()
  end)

  list:SetScript("OnShow", function()
    local settings = ListSettings()
    if settings then settings.shown = "1"; list:Refresh() end
  end)
  list:SetScript("OnHide", function()
    local settings = ListSettings()
    if settings then settings.shown = "0" end
  end)
  list:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.lastRefresh or 0) + .12 > now then return end
    this.lastRefresh = now
    this:Refresh()
  end)

  list:RegisterEvent("ADDON_LOADED")
  list:RegisterEvent("PLAYER_REGEN_DISABLED")
  list:RegisterEvent("PLAYER_REGEN_ENABLED")
  list:RegisterEvent("PLAYER_TARGET_CHANGED")
  pcall(list.RegisterEvent, list, "NAME_PLATE_UNIT_ADDED")
  pcall(list.RegisterEvent, list, "NAME_PLATE_UNIT_REMOVED")
  list:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
      if arg1 ~= "z_Nameplates" then return end
      this:UnregisterEvent("ADDON_LOADED")
      local settings = ListSettings()
      if not settings then return end
      this:ClearAllPoints()
      this:SetPoint(settings.point or "TOPRIGHT", UIParent,
        settings.relativePoint or "TOPRIGHT", tonumber(settings.x) or -32, tonumber(settings.y) or -180)
      if settings.shown == "1" then this:Show() end
    end
    if this:IsShown() then this:Refresh() end
  end)

  function Z.ToggleCombatList()
    if list:IsShown() then list:Hide() else list:Show() end
  end
  Z.combatList = list
end
