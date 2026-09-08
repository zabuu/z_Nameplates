function zNameplates.StartNameplates()
  if zNameplates.nameplates then return end
  -- C and the compatibility helpers live in this function's private
  -- environment. Keeping them out of the lexical scope is important on the
  -- Vanilla Lua compiler, which allows only 32 upvalues per nested function.
  getfenv(1).C = zNameplates.config
  getfenv(1).DEPTH_STRATAS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
  getfenv(1).depthPlates = {}
  getfenv(1).plateLeft = {}
  getfenv(1).plateRight = {}
  getfenv(1).plateTop = {}
  getfenv(1).plateBottom = {}
  getfenv(1).plateStrata = {}
  getfenv(1).plateRank = {}

  -- disable original castbars
  pcall(SetCVar, "ShowVKeyCastbar", 0)

  local mathmod = math.mod or mathmod

  local unitcolors = {
    ["ENEMY_NPC"] = { .9, .2, .3, .8 },
    ["NEUTRAL_NPC"] = { 1, 1, .3, .8 },
    ["FRIENDLY_NPC"] = { .6, 1, 0, .8 },
    ["ENEMY_PLAYER"] = { .9, .2, .3, .8 },
    ["FRIENDLY_PLAYER"] = { .2, .6, 1, .8 }
  }
  -- Happiness colours used for the player's pet nameplate.
  getfenv(1).PET_HAPPINESS_NAME_COLORS = {
    [1] = { 1, .15, .15, 1 },
    [2] = { 1, .85, .15, 1 },
    [3] = { .2, 1, .2, 1 },
  }
  getfenv(1).REACTION_NAME_COLORS = {
    [1] = { .8, .1, .1, 1 }, [2] = { .9, .2, .1, 1 },
    [3] = { 1, .5, .1, 1 }, [4] = { 1, 1, .1, 1 },
    [5] = { .2, 1, .2, 1 }, [6] = { .2, 1, .2, 1 },
    [7] = { .2, 1, .2, 1 }, [8] = { .3, .7, 1, 1 },
  }

  local offtanks = {}

  local combatstate = {
    -- gets overwritten by user config
    ["OFFTANK"]  = { r = .7, g = .4, b = .2, a = 1 },
    ["NOTHREAT"] = { r = .7, g = .7, b = .2, a = 1 },
    ["THREAT"]   = { r = .7, g = .2, b = .2, a = 1 },
    ["CASTING"]  = { r = .7, g = .2, b = .7, a = 1 },
    ["STUN"]     = { r = .2, g = .7, b = .7, a = 1 },
    ["NONE"]     = { r = .2, g = .2, b = .2, a = 1 },
  }

  local elitestrings = {
    ["elite"] = "+",
    ["rareelite"] = "R+",
    ["rare"] = "R",
    ["boss"] = "B"
  }

  -- Friendly zone nameplate disable state
  local savedHostileState = nil
  local savedFriendlyState = nil
  local inFriendlyZone = false
  local inFriendlyArea = false
  local neutralFriendlySubzones = {
    ["gadgetzan"] = true,
    ["booty bay"] = true,
    ["everlook"] = true,
    ["ratchet"] = true,
    ["steamwheedle port"] = true,
    ["cenarion hold"] = true,
    ["light's hope chapel"] = true,
    ["marshal's refuge"] = true,
  }

  local function IsPlayerFriendlyArea()
    local pvpType = GetZonePVPInfo and GetZonePVPInfo()
    if pvpType == "friendly" or pvpType == "sanctuary" then return true end
    if IsResting and IsResting() then return true end
    local subzone = GetSubZoneText and GetSubZoneText()
    return subzone and neutralFriendlySubzones[strlower(subzone)] or false
  end
  local myGuild = nil
  local platecount = 0
  local registry = {}
  -- Subset of registry that currently has a unit assigned (between
  -- NAME_PLATE_UNIT_ADDED and _REMOVED). The central loop iterates this instead
  -- of the full pool so hidden pool slots aren't touched every tick.
  local visiblePlates = {}
  local plateByGuid = {}

  local raidGuidCache = {}  -- guid -> name (rebuilt on RAID_ROSTER_UPDATE/PARTY_MEMBERS_CHANGED)
  
  -- Per-GUID cast state, populated from ClassicAPI's UNIT_SPELLCAST_* events
  -- (which now fire for nameplate tokens) and cleared on STOP / plate removal /
  -- expiry. This replaces the old per-tick C_Spell poll on every visible plate:
  -- cast detection is event driven, and GetCastInfo just reads this cache.
  local castState = {}
  -- guid -> nameplate, maintained on NAME_PLATE_UNIT_ADDED/_REMOVED so a cast
  -- event can find its plate in O(1) and only cache casts we actually show.
  -- unit token -> Blizzard plate. OctoWoW may stop resolving a token through
  -- C_NamePlate before NAME_PLATE_UNIT_REMOVED has finished dispatching.
  local plateByUnit = {}

  -- One-shot C_Spell poll. Builds the cast struct for a UNIT_SPELLCAST_* event
  -- (the payload carries no timing) and seeds a plate that spawns while its unit
  -- is already mid-cast (its START fired before the plate existed). Picks cast
  -- vs channel itself. Never called per frame.
  local function PollCastInfo(unit)
    if not unit then return nil end
    local name, _, texture, startMs, endMs, _, _, _, spellID = C_Spell.UnitCastingInfo(unit)
    local isChannel
    if not name then
      name, _, texture, startMs, endMs, _, _, spellID = C_Spell.UnitChannelInfo(unit)
      isChannel = true
    end
    if not name or not startMs or not endMs then return nil end
    return {
      spellName = name,
      spellID   = spellID,
      icon      = texture,
      startTime = startMs / 1000,
      endTime   = endMs / 1000,
      duration  = (endMs - startMs) / 1000,
      isChannel = isChannel,
    }
  end

  -- Read a unit's current cast from the event-driven cache (keyed by GUID).
  -- Returns the cached struct while the cast is still active, else nil (and
  -- prunes the expired entry). Same struct shape and callers as before, minus
  -- the per-tick poll.
  local function GetCastInfo(unit)
    if not unit then return nil end
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local info = castState[guid]
    if info and info.endTime > GetTime() then return info end
    if info then castState[guid] = nil end
    return nil
  end
  
  local debuffCache = {}    -- guid -> { [spellID] = { start, duration } }
  -- Reusable per-plate debuff display buffer (avoid GC churn from per-call table creation)
  local debuffDisplayBuf = {}  -- [i] = { effect, texture, stacks, dtype, duration, timeleft }
  for i = 1, 16 do debuffDisplayBuf[i] = {} end
  local threatMemory = {}   -- guid -> true if mob had player targeted
  -- local debuffSeen = {}     -- reusable table for debuff tracking (avoid GC churn)

  -- PERF: visiblePlateCount maintained event-driven (NAME_PLATE_UNIT_ADDED/_REMOVED)
  local visiblePlateCount = 0

  -- ============================================================================
  -- OPTIMIZATION: Config caching
  -- ============================================================================
  local cfg = {}
  local function CacheConfig()
    cfg.showcastbar = C.nameplates["showcastbar"] == "1"
    cfg.targetcastbar = C.nameplates["targetcastbar"] == "1"
    cfg.notargalpha = tonumber(C.nameplates.notargalpha) or 0.5
    if cfg.notargalpha > 1 then cfg.notargalpha = cfg.notargalpha / 100 end
    -- Clamp to 0.99 so non-target plates never reach 1.0 (used for target detection)
    if cfg.notargalpha > 0.99 then cfg.notargalpha = 0.99 end
    cfg.namefightcolor = C.nameplates.namefightcolor == "1"
    cfg.spellname = C.nameplates.spellname == "1"
    cfg.showhp = C.nameplates.showhp == "1"
    cfg.showdebuffs = C.nameplates["showdebuffs"] == "1"
    cfg.showdebuffs_hostile = C.nameplates["showdebuffs_hostile"] == "1"
    cfg.showdebuffs_friendly = C.nameplates["showdebuffs_friendly"] == "1"
    cfg.owndebuffs = C.nameplates["owndebuffs"] == "1"
    cfg.targetzoom = C.nameplates.targetzoom == "1"
    cfg.zoomval = (tonumber(C.nameplates.targetzoomval) or 0.4) + 1
    cfg.distance_scale = C.nameplates.distance_scale == "1"
    cfg.distance_min_scale = math.max(.20,
      math.min(1, (tonumber(C.nameplates.distance_min_scale) or 60) / 100))
    cfg.distance_alpha = C.nameplates.distance_alpha == "1"
    cfg.distance_min_alpha = math.max(.20,
      math.min(1, (tonumber(C.nameplates.distance_min_alpha) or 40) / 100))
    cfg.los_fade = C.nameplates.los_fade == "1"
    cfg.los_desaturation = math.max(0,
      math.min(1, (tonumber(C.nameplates.los_desaturation) or 100) / 100))
    cfg.distance_unitxp = (cfg.distance_scale or cfg.distance_alpha or cfg.los_fade)
      and type(UnitXP) == "function" or false
    local desiredRange = math.max(10,
      math.min(80, tonumber(C.nameplates.nameplate_range) or 41))
    local foundRange, plateRange = pcall(GetCVar, "NameplateRange")
    if foundRange and plateRange ~= nil then
      if tonumber(plateRange) ~= desiredRange then
        pcall(SetCVar, "NameplateRange", tostring(desiredRange))
      end
      cfg.distance_max_range = desiredRange
    else
      -- A stock client has no adjustable NameplateRange CVar. Keep the
      -- distance effects aligned with its normal range when SuperWoW is absent.
      cfg.distance_max_range = 20
    end
    if not cfg.distance_max_range or cfg.distance_max_range <= 8 then
      cfg.distance_max_range = 20
    end
    cfg.width = tonumber(C.nameplates.width) or 120
    cfg.heighthealth = tonumber(C.nameplates.heighthealth) or 8
    cfg.targetglow = C.nameplates.targetglow == "1"
    cfg.targethighlight = C.nameplates.targethighlight == "1"
    cfg.outcombatstate = C.nameplates.outcombatstate == "1"
    cfg.barcombatstate = C.nameplates.barcombatstate == "1"
    cfg.ccombatcasting = C.nameplates.ccombatcasting == "1"
    cfg.ccombatthreat = C.nameplates.ccombatthreat == "1"
    cfg.ccombatnothreat = C.nameplates.ccombatnothreat == "1"
    cfg.ccombatstun = C.nameplates.ccombatstun == "1"
    cfg.ccombatofftank = C.nameplates.ccombatofftank == "1"
    cfg.use_unitfonts = C.nameplates.use_unitfonts == "1"
    cfg.overlap_enemy = C.nameplates.overlap_enemy == "1"
    cfg.overlap_friendly = C.nameplates.overlap_friendly == "1"
    cfg.overlap_friendly_area = C.nameplates.overlap_friendly_area == "1"
    cfg.overlap_combat = C.nameplates.overlap_combat == "1"
    cfg.font_size = cfg.use_unitfonts and C.global.font_unit_size or C.global.font_size
    cfg.hptextformat = C.nameplates.hptextformat
    -- NEW: Cache debuff config
    cfg.debufftimers = C.nameplates.debufftimers == "1"
    cfg.debuffanim = tonumber(C.nameplates.debuffanim) or 0
    cfg.debufftext = tonumber(C.nameplates.debufftext) or 1

    -- Rebuild offtanks lookup table
    offtanks = {}
    for k, v in pairs({strsplit("#", C.nameplates.combatofftanks)}) do
      if v ~= "" then offtanks[string.lower(v)] = true end
    end
  end

  local function GetNameplateFontSize(isFriendly)
    local custom = isFriendly and (C.nameplates.name.fontsize_friendly or C.nameplates.name.fontsize) or C.nameplates.name.fontsize
    if custom and custom ~= "" and tonumber(custom) and tonumber(custom) > 0 then
      return tonumber(custom)
    end
    local fallback = C.nameplates.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size
    return tonumber(fallback) or 10
  end

  local function RebuildOfftanks()
    offtanks = {}
    for k, v in pairs({strsplit("#", C.nameplates.combatofftanks)}) do
      if v ~= "" then offtanks[string.lower(v)] = true end
    end
  end
  RebuildOfftanks()

  -- ============================================================================
  -- OPTIMIZATION: Frame state cache
  -- ============================================================================
  local frameState = {
    now = 0,
    targetGuid = nil,
    mouseoverGuid = nil,
  }

  -- cache default border color
  local er, eg, eb, ea = GetStringColor(C.appearance.border.color)

  local NULL_GUID           = "0x0000000000000000"

  local function RebuildRaidGuidCache()
    for k in pairs(raidGuidCache) do raidGuidCache[k] = nil end
    for i = 1, GetNumRaidMembers() do
      local g = UnitGUID("raid"..i)
      if g then raidGuidCache[g] = UnitName("raid"..i) end
    end
    for i = 1, GetNumPartyMembers() do
      local g = UnitGUID("party"..i)
      if g then raidGuidCache[g] = UnitName("party"..i) end
    end
    local pg = UnitGUID("player")
    if pg then raidGuidCache[pg] = UnitName("player") end
  end

  local combatColorCache = {}  -- guid -> { color, expires }

  local function GetCombatStateColor(guid, token)
    -- PERF: Quick exit if player not in combat
    if not UnitAffectingCombat("player") then return false end
    if not token or not UnitExists(token) then return false end
    if UnitCanAssist("player", token) then return false end

    -- PERF: 0.2s throttle per guid - color changes are not time-critical
    local now = frameState.now
    local cached = combatColorCache[guid]
    if cached and cached.expires > now then
      return cached.color
    end

    if not UnitAffectingCombat(token) then return false end

    -- The mob's current target via the nameplate token chain (ClassicAPI):
    -- "nameplateNtarget" resolves to whatever this plate's unit is targeting,
    -- so no GetUnitField("target") or SuperWoW "<guid>target" token needed.
    local target = token .. "target"
    local mobTargetGuid = UnitGUID(target)
    local hasTarget = mobTargetGuid and mobTargetGuid ~= NULL_GUID
    local color = false

    local castInfo = GetCastInfo(token)
    local isCasting = castInfo and castInfo.endTime and now < castInfo.endTime
    local targetingPlayer = hasTarget and UnitIsUnit(target, "player")

    if targetingPlayer then
      threatMemory[guid] = true
    elseif hasTarget and not isCasting then
      threatMemory[guid] = nil
    end

    -- PERF: O(1) GUID lookup via raidGuidCache instead of O(40) loop
    local targetName = hasTarget and (UnitName(target) or raidGuidCache[mobTargetGuid])

    if cfg.ccombatcasting and isCasting then
      color = combatstate.CASTING
    elseif cfg.ccombatthreat and (targetingPlayer or threatMemory[guid]) then
      color = combatstate.THREAT
    elseif cfg.ccombatofftank and targetName and offtanks[strlower(targetName)] then
      color = combatstate.OFFTANK
    elseif cfg.ccombatnothreat and hasTarget then
      color = combatstate.NOTHREAT
    elseif cfg.ccombatstun and not hasTarget then
      color = combatstate.STUN
    end

    combatColorCache[guid] = combatColorCache[guid] or {}
    combatColorCache[guid].color = color
    combatColorCache[guid].expires = now + 0.2

    return color
  end

  local function IsCombatWithPlayer(plate)
    if not UnitAffectingCombat("player") then return nil end
    local token = plate and plate.unit
    if not token or not UnitExists(token) or UnitCanAssist("player", token) or not UnitAffectingCombat(token) then return nil end
    local threat = UnitThreatSituation and UnitThreatSituation("player", token)
    if threat and threat > 0 then return true end
    local target = token .. "target"
    return UnitGUID(target) and UnitIsUnit(target, "player") or nil
  end

  local function ShouldOverlap(plate)
    local overlap = plate and plate.overlapEnabled
    if overlap == nil then overlap = cfg.overlap_enemy end
    if cfg.overlap_friendly_area and inFriendlyArea then overlap = true end
    if IsCombatWithPlayer(plate) and (cfg.overlap_combat or (plate and plate.isNeutral)) then overlap = false end
    return overlap
  end

  local function ExactUnitDistance(unit)
    if not unit then return nil end

    if type(UnitXP) == "function" then
      local found, distance = pcall(UnitXP, "distanceBetween", "player", unit)
      if found and type(distance) == "number" and distance >= 0 then return distance end
    end

    if UnitDistanceSquared then
      local found, squared = pcall(UnitDistanceSquared, unit)
      if found and type(squared) == "number" and squared >= 0 then
        return math.sqrt(squared)
      end
    end

    if UnitPosition then
      local foundPlayer, px, py, pz = pcall(UnitPosition, "player")
      local foundUnit, ux, uy, uz = pcall(UnitPosition, unit)
      if foundPlayer and foundUnit and px and py and ux and uy then
        local dx, dy, dz = ux - px, uy - py, (uz or 0) - (pz or 0)
        return math.sqrt(dx * dx + dy * dy + dz * dz)
      end
    end
  end

  local function GetUnitDepth(nameplate)
    if not nameplate then return 40 end
    local guid = nameplate.cachedGuid
    local unit = nameplate.unit

    if not guid and nameplate.parent and nameplate.parent.GetName then
      local ok, g = pcall(nameplate.parent.GetName, nameplate.parent, 1)
      if ok and type(g) == "string" and string.find(g, "^0[xX]%x+$") then
        guid = g
        nameplate.cachedGuid = g
      end
    end
    if not guid and unit and UnitGUID then
      local ok, g = pcall(UnitGUID, unit)
      if ok and type(g) == "string" and string.find(g, "^0[xX]%x+$") then
        guid = g
        nameplate.cachedGuid = g
      end
    end

    -- 1. Native zAPI camera projection (exact 3D depth along camera view vector)
    -- This updates continuously during both camera rotation and player movement.
    if type(zAPI) == "function" and guid then
      local ok, sx, sy, depth, wx, wy, wz = pcall(zAPI, "projectUnit", guid, 0)
      if ok and type(depth) == "number" and depth > 0 then
        return depth
      end
    end

    -- 2. Native zAPI worldToScreen from unitPosition
    if type(zAPI) == "function" and guid then
      local ok1, ux, uy, uz = pcall(zAPI, "unitPosition", guid)
      if ok1 and type(ux) == "number" and type(uy) == "number" and type(uz) == "number" then
        local ok2, sx, sy, depth = pcall(zAPI, "worldToScreen", ux, uy, uz)
        if ok2 and type(depth) == "number" and depth > 0 then
          return depth
        end
      end
    end

    -- 3. Exact 3D distance to player
    if type(zAPI) == "function" and guid then
      local pGuid = UnitGUID("player")
      if pGuid then
        local ok1, px, py, pz = pcall(zAPI, "unitPosition", pGuid)
        local ok2, ux, uy, uz = pcall(zAPI, "unitPosition", guid)
        if ok1 and ok2 and type(px) == "number" and type(ux) == "number" then
          local dx = ux - px
          local dy = uy - py
          local dz = (uz or 0) - (pz or 0)
          local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
          if dist > 0 then return dist end
        end
      end
    end

    -- 4. SuperWoW UnitPosition 3D distance
    if UnitPosition then
      local ok1, px, py, pz = pcall(UnitPosition, "player")
      local ok2, ux, uy, uz = pcall(UnitPosition, unit or guid)
      if ok1 and ok2 and type(px) == "number" and type(ux) == "number" then
        local dx = ux - px
        local dy = uy - py
        local dz = (uz or 0) - (pz or 0)
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist > 0 then return dist end
      end
    end

    -- 5. 3D distance fallback
    local dist = ExactUnitDistance(unit)
    if dist then return dist end

    return nameplate.depth or 40
  end

  local function SetPlateDepthLayer(nameplate, strata, baseLevel)
    if not nameplate then return end

    if nameplate.cachedStrata ~= strata then
      nameplate.cachedStrata = strata
      nameplate:SetFrameStrata(strata)
      if nameplate.parent and nameplate.parent.SetFrameStrata then
        pcall(nameplate.parent.SetFrameStrata, nameplate.parent, strata)
      end
    end

    if nameplate.cachedBaseLevel ~= baseLevel then
      nameplate.cachedBaseLevel = baseLevel
      nameplate:SetFrameLevel(baseLevel + 1)
      if nameplate.parent and nameplate.parent.SetFrameLevel then
        pcall(nameplate.parent.SetFrameLevel, nameplate.parent, baseLevel)
      end

      if nameplate.health then
        nameplate.health:SetFrameLevel(baseLevel + 2)
      end
      if nameplate.totem then
        nameplate.totem:SetFrameLevel(baseLevel + 3)
      end
      if nameplate.castbar then
        nameplate.castbar:SetFrameLevel(baseLevel + 3)
        if nameplate.castbar.icon then
          nameplate.castbar.icon:SetFrameLevel(baseLevel + 4)
        end
      end
      if nameplate.debuffs then
        for i = 1, 16 do
          local debuff = nameplate.debuffs[i]
          if debuff then
            debuff:SetFrameLevel(baseLevel + 3)
            if debuff.cd then
              debuff.cd:SetFrameLevel(baseLevel + 4)
            end
          end
        end
      end
      if nameplate.combopoints then
        for i = 1, 5 do
          local cp = nameplate.combopoints[i]
          if cp then
            cp:SetFrameLevel(baseLevel + 5)
          end
        end
      end
      if nameplate.raidiconframe then
        nameplate.raidiconframe:SetFrameLevel(baseLevel + 6)
      end
    end
  end

  local function UpdateNameplateDepthLayers()
    -- Ensure all visible plates have their GUID and unit token resolved immediately
    -- (critical for stationary targets, dummies, and plates present at /rl)
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
      for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then
          local p = C_NamePlate.GetNamePlateForUnit(u)
          if p and p.nameplate then
            if not p.nameplate.unit then p.nameplate.unit = u end
            if not p.nameplate.cachedGuid then
              p.nameplate.cachedGuid = UnitGUID(u)
            end
            if not visiblePlates[p] then
              visiblePlates[p] = p
            end
          end
        end
      end
    end

    table.wipe(depthPlates)
    local count = 0
    for plate in pairs(visiblePlates) do
      if plate:IsVisible() and plate.nameplate then
        count = count + 1
        depthPlates[count] = plate
        local np = plate.nameplate
        np.depth = GetUnitDepth(np)
      end
    end

    if count == 0 then return end

    if count == 1 then
      local np = depthPlates[1].nameplate
      local d = np.depth or 20
      local rank = math.max(1, math.min(100, math.floor(101 - d * 2.5)))
      local sIdx = math.min(5, math.floor((rank - 1) / 20) + 1)
      local sName = DEPTH_STRATAS[sIdx] or "LOW"
      local bLvl = math.floor(2 + (rank - 1) * 0.9)
      SetPlateDepthLayer(np, sName, bLvl)
      return
    end

    -- Sort strictly by camera depth (furthest from camera first, closest last)
    -- Higher indices = closer plates -> receive higher ranks / stratas and render on top
    table.sort(depthPlates, function(a, b)
      local na = a.nameplate
      local nb = b.nameplate
      local da = na.depth or 40
      local db = nb.depth or 40

      if da ~= db then
        return da > db -- larger depth = further away = sorted first
      end

      if na.istarget ~= nb.istarget then
        return not na.istarget -- target tie-breaker only when depths are identical
      end

      return (na.platename or "") > (nb.platename or "")
    end)

    table.wipe(plateLeft)
    table.wipe(plateRight)
    table.wipe(plateTop)
    table.wipe(plateBottom)
    table.wipe(plateStrata)
    table.wipe(plateRank)

    for i = 1, count do
      local p = depthPlates[i]
      local np = p.nameplate
      local l = np:GetLeft() or (p.GetLeft and p:GetLeft())
      local r = np:GetRight() or (p.GetRight and p:GetRight())
      local t = np:GetTop() or (p.GetTop and p:GetTop())
      local b = np:GetBottom() or (p.GetBottom and p:GetBottom())
      plateLeft[i] = l
      plateRight[i] = r
      plateTop[i] = t
      plateBottom[i] = b

      -- Configure 1-100 distinct rendering rank based on depth
      -- depth = 0 yards -> rank 100 (closest, highest priority)
      -- depth = 40 yards -> rank 1 (furthest, lowest priority)
      local d = np.depth or 40
      plateRank[i] = math.max(1, math.min(100, math.floor(101 - d * 2.5)))
    end

    -- Ensure strictly monotonic ranks for sorted plates (closer plate >= further plate)
    for i = 2, count do
      if plateRank[i] <= plateRank[i - 1] then
        plateRank[i] = math.min(100, plateRank[i - 1] + 1)
      end
    end

    -- Map 100 ranks across the 5 discrete rendering stratas (20 ranks per strata)
    for i = 1, count do
      plateStrata[i] = math.min(5, math.floor((plateRank[i] - 1) / 20) + 1)
    end

    -- Dynamic overlap resolution:
    -- When plate i is closer than plate j (i > j) and overlaps on screen:
    -- plate i MUST be in a strictly higher strata than plate j.
    for i = 2, count do
      local li, ri, ti, bi = plateLeft[i], plateRight[i], plateTop[i], plateBottom[i]
      if li and ri and ti and bi then
        for j = 1, i - 1 do
          local lj, rj, tj, bj = plateLeft[j], plateRight[j], plateTop[j], plateBottom[j]
          if lj and rj and tj and bj then
            if not (li > rj + 4 or ri < lj - 4 or bi > tj + 4 or ti < bj - 4) then
              if plateStrata[i] <= plateStrata[j] then
                plateStrata[i] = math.min(5, plateStrata[j] + 1)
                plateRank[i] = math.max(plateRank[i], (plateStrata[i] - 1) * 20 + 1)
              end
            end
          end
        end
      end
    end

    -- Target priority boost if overlapping
    for i = 1, count do
      local np = depthPlates[i].nameplate
      if np.istarget and plateStrata[i] < 5 then
        plateStrata[i] = math.min(5, plateStrata[i] + 1)
        plateRank[i] = math.max(plateRank[i], (plateStrata[i] - 1) * 20 + 1)
      end
    end

    -- Apply strata and granular frame level (1 to 100)
    for i = 1, count do
      local np = depthPlates[i].nameplate
      local sIdx = plateStrata[i] or 2
      local sName = DEPTH_STRATAS[sIdx] or "LOW"
      local r = plateRank[i] or 50
      local baseLevel = math.floor(2 + (r - 1) * 0.9)
      SetPlateDepthLayer(np, sName, baseLevel)
    end
  end

  local function SaveVisualColor(object, getter)
    if not object or not object[getter] then return nil end
    local r, g, b, a = object[getter](object)
    if not r then return nil end
    return { r, g, b, a or 1 }
  end

  local function RestoreVisualColor(object, setter, color)
    if object and object[setter] and color then
      object[setter](object, color[1], color[2], color[3], color[4])
    end
  end

  local function GrayVisualColor(object, setter, color, amount)
    if object and object[setter] and color then
      local gray = color[1] * .30 + color[2] * .59 + color[3] * .11
      amount = math.max(0, math.min(1, tonumber(amount) or 1))
      object[setter](object,
        color[1] + (gray - color[1]) * amount,
        color[2] + (gray - color[2]) * amount,
        color[3] + (gray - color[3]) * amount,
        color[4])
    end
  end

  local function DesaturateTexture(texture, desaturated)
    if texture and texture.SetDesaturated then
      pcall(texture.SetDesaturated, texture, desaturated and true or false)
    end
  end

  local function SetLineOfSightDesaturation(plate, outOfSight, force)
    local changed = (plate.losDesaturated and true or false) ~= (outOfSight and true or false)
    if outOfSight and not plate.losVisualColors then
      plate.losVisualColors = {
        health = SaveVisualColor(plate.health, "GetStatusBarColor"),
        healthBorder = plate.health and SaveVisualColor(plate.health.backdrop, "GetBackdropBorderColor"),
        castbar = SaveVisualColor(plate.castbar, "GetStatusBarColor"),
        castBorder = plate.castbar and SaveVisualColor(plate.castbar.backdrop, "GetBackdropBorderColor"),
        name = SaveVisualColor(plate.name, "GetTextColor"),
        level = SaveVisualColor(plate.level, "GetTextColor"),
        guild = SaveVisualColor(plate.guild, "GetTextColor"),
        healthText = plate.health and SaveVisualColor(plate.health.text, "GetTextColor"),
        castText = plate.castbar and SaveVisualColor(plate.castbar.text, "GetTextColor"),
        spell = plate.castbar and SaveVisualColor(plate.castbar.spell, "GetTextColor"),
        quest = SaveVisualColor(plate.questIcon, "GetTextColor"),
      }
    end

    local colors = plate.losVisualColors
    if outOfSight and colors and (changed or force) then
      local amount = cfg.los_desaturation
      GrayVisualColor(plate.health, "SetStatusBarColor", colors.health, amount)
      if plate.health then
        GrayVisualColor(plate.health.backdrop, "SetBackdropBorderColor", colors.healthBorder, amount)
      end
      GrayVisualColor(plate.castbar, "SetStatusBarColor", colors.castbar, amount)
      if plate.castbar then
        GrayVisualColor(plate.castbar.backdrop, "SetBackdropBorderColor", colors.castBorder, amount)
      end
      GrayVisualColor(plate.name, "SetTextColor", colors.name, amount)
      GrayVisualColor(plate.level, "SetTextColor", colors.level, amount)
      GrayVisualColor(plate.guild, "SetTextColor", colors.guild, amount)
      if plate.health then GrayVisualColor(plate.health.text, "SetTextColor", colors.healthText, amount) end
      if plate.castbar then
        GrayVisualColor(plate.castbar.text, "SetTextColor", colors.castText, amount)
        GrayVisualColor(plate.castbar.spell, "SetTextColor", colors.spell, amount)
      end
      GrayVisualColor(plate.questIcon, "SetTextColor", colors.quest, amount)
    elseif colors then
      RestoreVisualColor(plate.health, "SetStatusBarColor", colors.health)
      if plate.health then
        RestoreVisualColor(plate.health.backdrop, "SetBackdropBorderColor", colors.healthBorder)
      end
      RestoreVisualColor(plate.castbar, "SetStatusBarColor", colors.castbar)
      if plate.castbar then
        RestoreVisualColor(plate.castbar.backdrop, "SetBackdropBorderColor", colors.castBorder)
      end
      RestoreVisualColor(plate.name, "SetTextColor", colors.name)
      RestoreVisualColor(plate.level, "SetTextColor", colors.level)
      RestoreVisualColor(plate.guild, "SetTextColor", colors.guild)
      if plate.health then RestoreVisualColor(plate.health.text, "SetTextColor", colors.healthText) end
      if plate.castbar then
        RestoreVisualColor(plate.castbar.text, "SetTextColor", colors.castText)
        RestoreVisualColor(plate.castbar.spell, "SetTextColor", colors.spell)
      end
      RestoreVisualColor(plate.questIcon, "SetTextColor", colors.quest)
      plate.losVisualColors = nil
      plate.eventcache = true
    end

    local textureDesaturated = outOfSight and cfg.los_desaturation >= .995 or false
    if changed or plate.losTextureDesaturated ~= textureDesaturated then
      local healthTexture = plate.health and plate.health.GetStatusBarTexture
        and plate.health:GetStatusBarTexture()
      local castTexture = plate.castbar and plate.castbar.GetStatusBarTexture
        and plate.castbar:GetStatusBarTexture()
      DesaturateTexture(healthTexture, textureDesaturated)
      DesaturateTexture(castTexture, textureDesaturated)
      DesaturateTexture(plate.glow, textureDesaturated)
      DesaturateTexture(plate.raidicon, textureDesaturated)
      DesaturateTexture(plate.totem and plate.totem.icon, textureDesaturated)
      DesaturateTexture(plate.castbar and plate.castbar.icon and plate.castbar.icon.tex, textureDesaturated)
      for index = 1, 16 do
        DesaturateTexture(plate.debuffs and plate.debuffs[index]
          and plate.debuffs[index].icon, textureDesaturated)
      end
      for index = 1, 5 do
        DesaturateTexture(plate.combopoints and plate.combopoints[index]
          and plate.combopoints[index].tex, textureDesaturated)
      end
      plate.losTextureDesaturated = textureDesaturated
    end
    plate.losDesaturated = outOfSight and true or nil
  end

  local function ApplyDistanceEffects(plate, now, baseAlpha)
    local baseScale = UIParent:GetScale()
    now = now or GetTime()
    local identity = plate.cachedGuid or plate.unit
    if plate.distanceScaleIdentity ~= identity then
      plate.distanceScaleIdentity = identity
      plate.distanceTargetScale = nil
      plate.distanceNextSample = nil
      plate.distanceProgress = nil
      plate.distanceVisualTime = nil
      plate.distanceAlpha = nil
      plate.losAlpha = nil
      plate.losNextSample = nil
      plate.losOutOfSight = nil
    end

    local elapsed = plate.distanceVisualTime
      and math.max(0, math.min(.1, now - plate.distanceVisualTime)) or nil
    local blend = elapsed and 1 - math.exp(-elapsed * 10) or 1
    plate.distanceVisualTime = now

    if cfg.distance_scale or cfg.distance_alpha then
      -- Sample exact range at the same cadence as the central visual loop. The
      -- eased frame scale then supplies many small transitions between glyph
      -- sizes instead of visibly stepping between a few coarse values.
      if not plate.distanceNextSample or now >= plate.distanceNextSample then
        local progress = 0
        local distance = ExactUnitDistance(plate.unit)
        if distance and distance > 8 then
          progress = math.min(1, (distance - 8) / (cfg.distance_max_range - 8))
        end
        plate.distanceProgress = progress
        plate.distanceNextSample = now + .01
      end
    else
      plate.distanceProgress = 0
      plate.distanceNextSample = nil
    end

    local progress = plate.distanceProgress or 0
    local targetScale = baseScale
    if cfg.distance_scale then
      targetScale = targetScale * (1 - (1 - cfg.distance_min_scale) * progress)
    end
    plate.distanceTargetScale = targetScale

    local scale = plate.distanceScale or baseScale
    scale = scale + (targetScale - scale) * blend
    if abs(targetScale - scale) < .00001 then scale = targetScale end
    if not plate.distanceScale or abs(plate.distanceScale - scale) > .000001 then
      plate:SetScale(scale)
      plate.distanceScale = scale
      plate.dwidth = nil
    end

    local targetDistanceAlpha = cfg.distance_alpha
      and 1 - (1 - cfg.distance_min_alpha) * progress or 1
    local distanceAlpha = plate.distanceAlpha or 1
    distanceAlpha = distanceAlpha + (targetDistanceAlpha - distanceAlpha) * blend
    if abs(targetDistanceAlpha - distanceAlpha) < .0001 then distanceAlpha = targetDistanceAlpha end
    plate.distanceAlpha = distanceAlpha

    if cfg.los_fade and cfg.distance_unitxp and plate.unit and UnitExists(plate.unit) then
      if not plate.losNextSample or now >= plate.losNextSample then
        local found, inSight = pcall(UnitXP, "inSight", "player", plate.unit)
        plate.losOutOfSight = found and inSight == false or nil
        plate.losNextSample = now + .1
      end
    else
      plate.losOutOfSight = nil
      plate.losNextSample = nil
    end
    SetLineOfSightDesaturation(plate, plate.losOutOfSight)

    local targetLosAlpha = plate.losOutOfSight and cfg.distance_min_alpha or 1
    local losAlpha = plate.losAlpha or 1
    losAlpha = losAlpha + (targetLosAlpha - losAlpha) * blend
    if abs(targetLosAlpha - losAlpha) < .0001 then losAlpha = targetLosAlpha end
    plate.losAlpha = losAlpha

    -- Distance and line-of-sight select the stronger fade. They never multiply,
    -- so a far, obstructed plate bottoms out at the configured minimum once.
    local visualAlpha = math.min(distanceAlpha, losAlpha)
    local desiredAlpha = math.max(0, math.min(1, (baseAlpha or 1) * visualAlpha))
    if not plate.cachedAlpha or abs(plate.cachedAlpha - desiredAlpha) > .0005 then
      plate:SetAlpha(desiredAlpha)
      plate.cachedAlpha = desiredAlpha
    end
  end

  local function RefreshVisibleNameplatePool()
    local hostileEnabled = C.nameplates.showhostile == "1"
      and not (inFriendlyArea and C.nameplates.disable_hostile_in_friendly == "1")
    local friendlyEnabled = C.nameplates.showfriendly == "1"
      and not (inFriendlyArea and C.nameplates.disable_friendly_in_friendly == "1")

    -- Both halves happen in one rendered frame. This rebuilds the client's
    -- pooled nameplates after the player's pet appears without changing the
    -- player's configured visibility state.
    if hostileEnabled then
      _G.NAMEPLATES_ON = nil
      HideNameplates()
      _G.NAMEPLATES_ON = true
      ShowNameplates()
    end
    if friendlyEnabled then
      _G.FRIENDNAMEPLATES_ON = nil
      HideFriendNameplates()
      _G.FRIENDNAMEPLATES_ON = true
      ShowFriendNameplates()
    end
  end

  local function ReleaseAtScreenEdge(frame, plate, overlap)
    if frame.SetClampedToScreen then
      if not overlap and not plate.screenUnclamped then
        if frame.IsClampedToScreen then
          local found, clamped = pcall(frame.IsClampedToScreen, frame)
          if found then plate.originalScreenClamp = clamped end
        end
        pcall(frame.SetClampedToScreen, frame, false)
        if plate.SetClampedToScreen then pcall(plate.SetClampedToScreen, plate, false) end
        plate.screenUnclamped = true
      elseif overlap and plate.screenUnclamped then
        if plate.originalScreenClamp ~= nil then
          pcall(frame.SetClampedToScreen, frame, plate.originalScreenClamp)
        end
        plate.screenUnclamped = nil
        plate.originalScreenClamp = nil
      end
    end

    if overlap or not frame.GetCenter or not UIParent.GetWidth or not UIParent.GetHeight then
      return false
    end
    local x, y = frame:GetCenter()
    if not x or not y then return false end

    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if parentScale <= 0 then parentScale = 1 end
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local plateScale = plate.GetEffectiveScale and plate:GetEffectiveScale() or frameScale
    x, y = x * frameScale / parentScale, y * frameScale / parentScale
    local halfWidth = plate:GetWidth() * plateScale / parentScale / 2
    local halfHeight = plate:GetHeight() * plateScale / parentScale / 2

    return x <= halfWidth + 1 or x >= UIParent:GetWidth() - halfWidth - 1
      or y <= halfHeight + 1 or y >= UIParent:GetHeight() - halfHeight - 1
  end

  local function DoNothing()
    return
  end

  local function DisableObject(object)
    if not object then return end
    if not object.GetObjectType then return end

    local otype = object:GetObjectType()

    if otype == "Texture" then
      object:SetTexture("")
      object:SetTexCoord(0, 0, 0, 0)
    elseif otype == "FontString" then
      object:SetWidth(0.001)
    elseif otype == "StatusBar" then
      object:SetStatusBarTexture("")
    end
  end

  -- Numeric CreatureType.dbc id for the plate's unit (8 = Critter, 11 = Totem).
  -- It's fixed per unit, so cache it and reset on plate reuse. nil while the GUID
  -- can't resolve yet (incl. the no-SuperWoW case, where cachedGuid is empty).
  -- Locale-proof and covers custom units for free -- no name tables needed.
  local function CreatureType(plate)
    local guid = plate.cachedGuid
    if not guid or guid == "" then return nil end
    if not plate.creatureType then
      plate.creatureType = UnitCreatureTypeID(guid)  -- nil retries next call
    end
    return plate.creatureType
  end

  -- Totem icon, read straight from the game:
  --   * Passive totems self-cast their provided buff, so they carry exactly one
  --     aura whose icon IS the totem's icon (Totem::Summon TOTEM_PASSIVE).
  --   * Active totems (Searing/Magma/Fire Nova) cast at enemies and hold no
  --     self-aura, so their icon arrives via UNIT_SPELLCAST_SUCCEEDED (cached
  --     into plate.totemIcon by the event handler); nil here until then.
  local function TotemPlate(plate)
    if C.nameplates.totemicons ~= "1" then return nil end
    if CreatureType(plate) ~= 11 then return nil end
    if plate.totemIcon then return plate.totemIcon end
    local aura = C_UnitAuras.GetBuffDataByIndex(plate.cachedGuid, 1)
    if aura then plate.totemIcon = aura.icon end
    return plate.totemIcon
  end

  local function HidePlate(unittype, fullhp, target, plate)
    -- keep some plates always visible according to config
    if C.nameplates.fullhealth == "1" and not fullhp then return nil end
    if C.nameplates.target == "1" and target then return nil end

    -- return true when something needs to be hidden
    if C.nameplates.enemynpc == "1" and unittype == "ENEMY_NPC" then
      return true
    elseif C.nameplates.enemyplayer == "1" and unittype == "ENEMY_PLAYER" then
      return true
    elseif C.nameplates.neutralnpc == "1" and unittype == "NEUTRAL_NPC" then
      return true
    elseif C.nameplates.friendlynpc == "1" and unittype == "FRIENDLY_NPC" then
      return true
    elseif C.nameplates.friendlyplayer == "1" and unittype == "FRIENDLY_PLAYER" then
      return true
    elseif C.nameplates.critters == "1" and CreatureType(plate) == 8 then
      return true
    elseif C.nameplates.totems == "1" and CreatureType(plate) == 11 then
      return true
    elseif unittype == "NEUTRAL_NPC" and not plate.neutralProvoked then
      -- Neutral mobs behave like friendly units until they are provoked:
      -- retain the nameplate name, but hide the healthbar while idle.
      return true
    end

    -- nothing to hide
    return nil
  end

  local function abbrevname(t)
    return string.sub(t,1,1)..". "
  end

  local function GetNameString(name)
    local abbrev = C.unitframes.abbrevname == "1" or nil
    local size = 20

    -- first try to only abbreviate the first word
    if abbrev and name and strlen(name) > size then
      name = string.gsub(name, "^(%S+) ", abbrevname)
    end

    -- abbreviate all if it still doesn't fit
    if abbrev and name and strlen(name) > size then
      name = string.gsub(name, "(%S+) ", abbrevname)
    end

    return name
  end


  local function GetUnitType(red, green, blue)
    if red > .9 and green < .2 and blue < .2 then
      return "ENEMY_NPC"
    elseif red > .9 and green > .9 and blue < .2 then
      return "NEUTRAL_NPC"
    elseif red < .2 and green < .2 and blue > 0.9 then
      return "FRIENDLY_PLAYER"
    elseif red < .2 and green > .9 and blue < .2 then
      return "FRIENDLY_NPC"
    end
  end

  local filter, list, cache
  local function DebuffFilterPopulate()
    -- initialize variables
    filter = C.nameplates["debuffs"]["filter"]
    if filter == "none" then return end
    list = C.nameplates["debuffs"][filter]
    cache = {}

    -- populate list
    for _, val in pairs({strsplit("#", list)}) do
      cache[strlower(val)] = true
    end
  end

  local function DebuffFilter(effect)
    if filter == "none" then return true end
    if not cache then DebuffFilterPopulate() end

    if filter == "blacklist" and cache[strlower(effect)] then
      return nil
    elseif filter == "blacklist" then
      return true
    elseif filter == "whitelist" and cache[strlower(effect)] then
      return true
    elseif filter == "whitelist" then
      return nil
    end
  end

  local function CreateDebuffIcon(plate, index)
    local baseLevel = plate.cachedBaseLevel or 4
    plate.debuffs[index] = CreateFrame("Frame", plate.platename.."Debuff"..index, plate)
    plate.debuffs[index]:Hide()
    plate.debuffs[index]:SetFrameLevel(baseLevel + 3)

    plate.debuffs[index].icon = plate.debuffs[index]:CreateTexture(nil, "BACKGROUND")
    plate.debuffs[index].icon:SetTexture(.3,1,.8,1)
    plate.debuffs[index].icon:SetAllPoints(plate.debuffs[index])

    plate.debuffs[index].stacks = plate.debuffs[index]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plate.debuffs[index].stacks:SetAllPoints(plate.debuffs[index])
    plate.debuffs[index].stacks:SetJustifyH("RIGHT")
    plate.debuffs[index].stacks:SetJustifyV("BOTTOM")
    plate.debuffs[index].stacks:SetTextColor(1,1,0)

    -- PERF: Use lightweight fake cooldown frame when animation disabled
    -- The Model-based CooldownFrameTemplate causes major lag with many nameplates
    if cfg.debuffanim ~= 1 then
      plate.debuffs[index].cd = CreateFrame("Frame", plate.platename.."Debuff"..index.."Cooldown", plate.debuffs[index])
      plate.debuffs[index].cd:SetAllPoints(plate.debuffs[index])
      plate.debuffs[index].cd:SetFrameLevel(baseLevel + 4)
      plate.debuffs[index].cd:SetScript("OnUpdate", CooldownFrame_OnUpdateModel)
      plate.debuffs[index].cd.AdvanceTime = DoNothing
      plate.debuffs[index].cd.SetSequence = DoNothing
      plate.debuffs[index].cd.SetSequenceTime = DoNothing
    else
      -- Use CooldownFrameTemplate for animation
      plate.debuffs[index].cd = CreateFrame(COOLDOWN_FRAME_TYPE, plate.platename.."Debuff"..index.."Cooldown", plate.debuffs[index], "CooldownFrameTemplate")
      plate.debuffs[index].cd:SetAllPoints(plate.debuffs[index])
      plate.debuffs[index].cd:SetFrameLevel(baseLevel + 4)
    end

    -- Set initial config flags (will be cached per-cooldown later)
    plate.debuffs[index].cd.pfCooldownStyleAnimation = cfg.debuffanim
    plate.debuffs[index].cd.pfCooldownStyleText = cfg.debufftext
    plate.debuffs[index].cd.pfCooldownType = "ALL"
  end

  local function UpdateDebuffConfig(nameplate, i)
    if not nameplate.debuffs[i] then return end

    -- update debuff positions
    local width = tonumber(C.nameplates.width)
    local debuffsize = tonumber(C.nameplates.debuffsize)
    local debuffoffset = tonumber(C.nameplates.debuffoffset)
    local limit = floor(width / debuffsize)
    local font = C.nameplates.use_unitfonts == "1" and zNameplates.font_unit or zNameplates.font_default
    local font_size = GetNameplateFontSize(nameplate.isFriendly)
    local font_style = (nameplate.isFriendly and (C.nameplates.name.fontstyle_friendly or C.nameplates.name.fontstyle)) or C.nameplates.name.fontstyle

    local aligna, alignb, offs, space
    if C.nameplates.debuffs["position"] == "BOTTOM" then
      aligna, alignb, offs, space = "TOPLEFT", "BOTTOMLEFT", -debuffoffset, -1
    else
      aligna, alignb, offs, space = "BOTTOMLEFT", "TOPLEFT", debuffoffset, 1
    end

    nameplate.debuffs[i].stacks:SetFont(font, font_size, font_style)
    nameplate.debuffs[i]:ClearAllPoints()
    if i == 1 then
      nameplate.debuffs[i]:SetPoint(aligna, nameplate.health, alignb, 0, offs)
    elseif i <= limit then
      nameplate.debuffs[i]:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
    elseif i > limit and limit > 0 then
      nameplate.debuffs[i]:SetPoint(aligna, nameplate.debuffs[i-limit], alignb, 0, space)
    end

    nameplate.debuffs[i]:SetSize(debuffsize, debuffsize)
    
    -- Update cooldown display settings
    if nameplate.debuffs[i].cd then
      local cooldown_text = tonumber(C.nameplates.debufftext) or 1
      local cooldown_anim = tonumber(C.nameplates.debuffanim) or 0
      nameplate.debuffs[i].cd.pfCooldownStyleText = cooldown_text
      nameplate.debuffs[i].cd.pfCooldownStyleAnimation = cooldown_anim
      
    end
  end

  -- create nameplate core
local nameplates = CreateFrame("Frame", "zNameplatesFrame", UIParent)
nameplates:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(nameplates.RegisterEvent, nameplates, "PLAYER_ALIVE")
pcall(nameplates.RegisterEvent, nameplates, "UNIT_PET")
pcall(nameplates.RegisterEvent, nameplates, "PET_BAR_UPDATE")
nameplates:RegisterEvent("PLAYER_TARGET_CHANGED")
nameplates:RegisterEvent("PLAYER_LOGOUT")
nameplates:RegisterEvent("UNIT_COMBO_POINTS")
nameplates:RegisterEvent("PLAYER_COMBO_POINTS")
nameplates:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(nameplates.RegisterEvent, nameplates, "ZONE_CHANGED")
pcall(nameplates.RegisterEvent, nameplates, "ZONE_CHANGED_INDOORS")
pcall(nameplates.RegisterEvent, nameplates, "PLAYER_UPDATE_RESTING")
nameplates:RegisterEvent("RAID_ROSTER_UPDATE")
nameplates:RegisterEvent("PARTY_MEMBERS_CHANGED")
nameplates:RegisterEvent("NAME_PLATE_CREATED")
nameplates:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nameplates:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
nameplates:RegisterEvent("UNIT_AURA")
nameplates:RegisterEvent("UNIT_FLAGS")
nameplates:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
nameplates:RegisterEvent("UNIT_SPELLCAST_START")
nameplates:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
nameplates:RegisterEvent("UNIT_SPELLCAST_STOP")
nameplates:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
nameplates:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
nameplates:RegisterEvent("PLAYER_GUILD_UPDATE")
  
  nameplates:SetScript("OnEvent", function()
    -- Stop event handling during logout to prevent crash 132
    if event == "PLAYER_LOGOUT" then
      this:UnregisterAllEvents()
      this:SetScript("OnEvent", nil)
      this:SetScript("OnUpdate", nil)
      if nameplates.mouselook then
        nameplates.mouselook:SetScript("OnUpdate", nil)
      end
      return

    elseif event == "PLAYER_GUILD_UPDATE" and arg1 == 'player' then
      myGuild = GetGuildInfo("player")

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
      or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
      or event == "PLAYER_UPDATE_RESTING" then
      if event == "PLAYER_ENTERING_WORLD" then
        CacheConfig()
        this:SetGameVariables()
        RebuildRaidGuidCache()
        frameState.targetGuid = UnitGUID("target")
        myGuild = GetGuildInfo("player")
        -- Establish a fresh baseline after a loading screen. Pet unit tokens
        -- are commonly recreated here; that is not a new summon and must not
        -- cause the nameplates to flicker as the zone finishes loading.
        this.playerPetPresent = UnitExists("pet") and true or false
        this.petRefreshSuppressedUntil = GetTime() + 3
        this.petTransitionCheckAt = nil
        this.petTransitionCheckUntil = nil
        this.visibilityRefreshAt = nil
      end
      
      -- Handle friendly zone nameplate disable feature
      local disableHostile = C.nameplates["disable_hostile_in_friendly"] == "1"
      local disableFriendly = C.nameplates["disable_friendly_in_friendly"] == "1"
      local nowFriendly = IsPlayerFriendlyArea()
      inFriendlyArea = nowFriendly
      
      if disableHostile or disableFriendly then
        if nowFriendly and not inFriendlyZone then
          -- Entering friendly zone - save current state and hide based on options
          inFriendlyZone = true
          savedHostileState = C.nameplates["showhostile"]
          savedFriendlyState = C.nameplates["showfriendly"]
          
          if disableHostile then
            _G.NAMEPLATES_ON = nil
            HideNameplates()
          end
          
          if disableFriendly then
            _G.FRIENDNAMEPLATES_ON = nil
            HideFriendNameplates()
          end
        elseif not nowFriendly and inFriendlyZone then
          -- Leaving friendly zone - restore previous state
          inFriendlyZone = false
          
          if savedHostileState == "1" then
            _G.NAMEPLATES_ON = true
            ShowNameplates()
          end
          
          if savedFriendlyState == "1" then
            _G.FRIENDNAMEPLATES_ON = true
            ShowFriendNameplates()
          end
          
          savedHostileState = nil
          savedFriendlyState = nil
        end
      end

    elseif event == "PLAYER_ALIVE" then
      this.eventcache = true

    elseif event == "UNIT_PET" or event == "PET_BAR_UPDATE" then
      if event ~= "UNIT_PET" or not arg1 or arg1 == "player" then
        -- UNIT_PET can precede the pet token becoming readable. Poll briefly,
        -- then refresh a little after the false -> true transition.
        local now = GetTime()
        this.petTransitionCheckAt = now + .05
        this.petTransitionCheckUntil = now + 1
      end

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
      RebuildRaidGuidCache()

    elseif event == "NAME_PLATE_CREATED" then
      -- arg1 = the nameplate Frame; build the zNameplates overlay once per pool slot
      if arg1 and not registry[arg1] then
        nameplates.OnCreate(arg1)
        registry[arg1] = arg1
      end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
      -- arg1 = "nameplateN" unit token. Cache the GUID for cache keys and the
      -- token itself for token-based UnitX reads (stable per plate lifetime).
      local plate = C_NamePlate.GetNamePlateForUnit(arg1)
      if plate and plate.nameplate then
        SetLineOfSightDesaturation(plate.nameplate, nil)
        local wasVisible = visiblePlates[plate]
        visiblePlates[plate] = plate
        plateByUnit[arg1] = plate
        local guid = UnitGUID(arg1)
        plate.nameplate.cachedGuid = guid
        plate.nameplate.unit = arg1
        -- A Blizzard nameplate is pooled. Clear all identity-dependent state
        -- immediately on reassignment, even when the replacement unit has the
        -- same displayed name as the previous occupant.
        table.wipe(plate.nameplate.cache)
        plate.nameplate.isFriendly = nil
        plate.nameplate.isNeutral = nil
        plate.nameplate.isCritter = nil
        plate.nameplate.isTotem = nil
        plate.nameplate.neutralProvoked = nil
        plate.nameplate.taggedByPlayer = nil
        plate.nameplate.taggedByOther = nil
        plate.nameplate.creatureType = nil  -- recompute for the new unit
        plate.nameplate.totemIcon = nil
        plate.nameplate.questIconRevision = nil
        plate.nameplate.cachedAlpha = nil
        plate.nameplate.depth = nil
        plate.nameplate.cachedStrata = nil
        plate.nameplate.cachedBaseLevel = nil
        if plate.nameplate.questIcon then plate.nameplate.questIcon:Hide() end
        if guid then
          plateByGuid[guid] = plate.nameplate
          -- Seed: the unit may already be mid-cast (its UNIT_SPELLCAST_START
          -- fired before this plate existed). One poll here catches that;
          -- ongoing casts arrive via the event.
          castState[guid] = PollCastInfo(arg1)
        end
        nameplates.OnShow(plate)
        if not wasVisible then visiblePlateCount = visiblePlateCount + 1 end
      end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      -- arg1 = "nameplateN" unit token; UnitGUID still resolves inside the
      -- handler on most clients. Keep our own token map because OctoWoW can
      -- release the C_NamePlate association before this callback runs.
      local plate = C_NamePlate.GetNamePlateForUnit(arg1) or plateByUnit[arg1]
      plateByUnit[arg1] = nil
      if plate and visiblePlates[plate] then
        visiblePlateCount = visiblePlateCount > 0 and visiblePlateCount - 1 or 0
      end
      if plate then visiblePlates[plate] = nil end
      local guid = UnitGUID(arg1) or (plate and plate.nameplate and plate.nameplate.cachedGuid)
      if guid then
        if debuffCache[guid] then debuffCache[guid] = nil end
        if threatMemory[guid] then threatMemory[guid] = nil end
        if combatColorCache[guid] then combatColorCache[guid] = nil end
        if castState[guid] then castState[guid] = nil end
        if plateByGuid[guid] then plateByGuid[guid] = nil end
      end
      if plate and plate.nameplate then
        SetLineOfSightDesaturation(plate.nameplate, nil)
        if plate.nameplate.questIcon then plate.nameplate.questIcon:Hide() end
        plate.nameplate.questIconRevision = nil
        plate.nameplate.cachedGuid = nil
        plate.nameplate.unit = nil
        plate.nameplate.depth = nil
        plate.nameplate.cachedStrata = nil
        plate.nameplate.cachedBaseLevel = nil
      end

    elseif event == "UNIT_FLAGS" then
      if arg1 and strfind(arg1, "^nameplate") then
        local plate = C_NamePlate.GetNamePlateForUnit(arg1)
        if plate and plate.nameplate then
          plate.nameplate.eventcache = true
        end
      end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
      local new = UnitGUID("mouseover")
      local old = frameState.mouseoverGuid
      if new ~= old then
        frameState.mouseoverGuid = new
        local po = old and plateByGuid[old]
        if po then po.eventcache = true end
        local pn = new and plateByGuid[new]
        if pn then pn.eventcache = true end
      end

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
      -- ClassicAPI fires UNIT_SPELLCAST_* per unit token, including the caster's
      -- "nameplateN". The payload has no timing, so poll it (PollCastInfo picks
      -- cast vs channel) and cache -- only for a unit we have a plate for, so
      -- the table stays bounded to on-screen casters.
      if arg1 and strfind(arg1, "^nameplate") then
        local guid = UnitGUID(arg1)
        local plate = guid and plateByGuid[guid]
        if plate then
          castState[guid] = PollCastInfo(arg1)
          if castState[guid] then
            plate.castUpdate = true  -- bypass the throttle so the bar shows now
          end
        end
      end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      -- Cast/channel ended (natural, interrupted, or cancelled -- the poll fires
      -- STOP for all three). Clear the cached cast and refresh its plate.
      if arg1 and strfind(arg1, "^nameplate") then
        local guid = UnitGUID(arg1)
        if guid and castState[guid] then
          castState[guid] = nil
          local plate = plateByGuid[guid]
          if plate then plate.castUpdate = true end
        end
      end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      -- Active totems (Searing/Magma/Fire Nova) carry no self-aura, so their
      -- attack cast is the only icon source. Capture it once per totem, gated on
      -- creature type so a normal caster's spell never styles it as a totem.
      if arg1 and strfind(arg1, "^nameplate") then
        local guid = UnitGUID(arg1)
        local plate = guid and plateByGuid[guid]
        if plate and not plate.totemIcon and arg3 and CreatureType(plate) == 11 then
          local tex = C_Spell.GetSpellTexture(arg3)
          if tex then
            plate.totemIcon = tex
            plate.castUpdate = true  -- re-render now so the icon shows
          end
        end
      end

    elseif event == "UNIT_AURA" then
      -- ClassicAPI: fires with arg1 == "nameplateN" when a unit's aura set
      -- changes (add/remove/modify). Flag the matching plate so OnUpdate does a
      -- fresh C_UnitAuras read next tick instead of waiting on the 0.5s
      -- throttle -- covers expirations, dispels, refreshes, and stack changes
      -- in one event. Guard on the token prefix (UNIT_AURA also fires for
      -- target/party/raid).
      if arg1 and strfind(arg1, "^nameplate") then
        local plate = C_NamePlate.GetNamePlateForUnit(arg1)
        if plate and plate.nameplate then
          plate.nameplate.auraUpdate = true
        end
      end

    elseif event == "PLAYER_TARGET_CHANGED" then
      frameState.targetGuid = UnitGUID('target')
      -- Flag the target's plate for update
      local plate = C_NamePlate.GetNamePlateForUnit("target")
      if plate and plate.nameplate then
        plate.nameplate.targetUpdate = true
      end
      -- Also propagate to all plates for alpha/strata updates
      this.eventcache = true

    elseif event == "PLAYER_COMBO_POINTS" or event == "UNIT_COMBO_POINTS" then
      -- Only flag the target's plate for combo point update
      local plate = C_NamePlate.GetNamePlateForUnit("target")
      if plate and plate.nameplate then
        plate.nameplate.comboUpdate = true
      end
    else
      this.eventcache = true
    end
  end)

  nameplates:SetScript("OnUpdate", function()
    -- PERF: Throttle central OnUpdate to ~80 FPS (0.0125s)
    -- Saves ~44% calls at 144 FPS while staying above 50 FPS target-plate rate
    local now = GetTime()
    if (this.frameTick or 0) + 0.01 > now then return end
    this.frameTick = now

    -- PERF: Cache GetTime() once per frame
    frameState.now = now

    if this.petTransitionCheckAt and now >= this.petTransitionCheckAt then
      local petPresent = UnitExists("pet") and true or false
      if petPresent ~= this.playerPetPresent then
        this.playerPetPresent = petPresent
        if petPresent and now >= (this.petRefreshSuppressedUntil or 0) then
          this.visibilityRefreshAt = now + .2
        end
      end
      if petPresent or now >= (this.petTransitionCheckUntil or 0) then
        this.petTransitionCheckAt = nil
        this.petTransitionCheckUntil = nil
      else
        this.petTransitionCheckAt = now + .05
      end
    end

    if this.visibilityRefreshAt and now >= this.visibilityRefreshAt then
      this.visibilityRefreshAt = nil
      RefreshVisibleNameplatePool()
    end

    if this.eventcache then
      this.eventcache = nil
      for plate in pairs(visiblePlates) do
        plate.nameplate.eventcache = true
      end
    end

    UpdateNameplateDepthLayers()

    for plate in pairs(visiblePlates) do
      if plate:IsVisible() then
        nameplates.OnUpdate(plate, frameState)
      end
    end
  end)

  -- combat tracker
  nameplates.combat = CreateFrame("Frame")
  nameplates.combat:RegisterEvent("PLAYER_ENTER_COMBAT")
  nameplates.combat:RegisterEvent("PLAYER_LEAVE_COMBAT")
  nameplates.combat:RegisterEvent("PLAYER_LOGOUT")
  nameplates.combat:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
      this:UnregisterAllEvents()
      this:SetScript("OnEvent", nil)
      return
    elseif event == "PLAYER_ENTER_COMBAT" then
      this.inCombat = 1
      if PlayerFrame then PlayerFrame.inCombat = 1 end
    elseif event == "PLAYER_LEAVE_COMBAT" then
      this.inCombat = nil
      if PlayerFrame then PlayerFrame.inCombat = nil end
      -- Clear threat memory when leaving combat
      for k in pairs(threatMemory) do
        threatMemory[k] = nil
      end
      for parent in pairs(visiblePlates) do
        if parent.nameplate then parent.nameplate.neutralProvoked = nil end
      end
    end
  end)

  nameplates.OnCreate = function(frame)
    local parent = frame or this
    platecount = platecount + 1
    local platename = "zNamePlate" .. platecount

    -- Blizzard's nameplate child order is not consistent across OctoWoW client
    -- builds (and other addons may insert children of their own). Resolve the
    -- bars before adding our overlay, and only accept StatusBar-like children.
    local originalHealthbar, originalCastbar
    local originalChildren = { parent:GetChildren() }
    for i = 1, table.getn(originalChildren) do
      local object = originalChildren[i]
      if object and object.GetValue and object.GetMinMaxValues
        and object.GetStatusBarColor and object.SetStatusBarTexture then
        if not originalHealthbar then
          originalHealthbar = object
        elseif not originalCastbar then
          originalCastbar = object
          break
        end
      end
    end

    -- create zNameplates overlay
    local nameplate = CreateFrame("Button", platename, parent)
    nameplate.platename = platename
    nameplate:EnableMouse(0)
    nameplate.parent = parent
    nameplate.cache = {}
    nameplate.original = {}

    -- create shortcuts for all known elements and disable them
    nameplate.original.healthbar = originalHealthbar
    nameplate.original.castbar = originalCastbar
    DisableObject(nameplate.original.healthbar)
    DisableObject(nameplate.original.castbar)

    for i, object in pairs({parent:GetRegions()}) do
      if NAMEPLATE_OBJECTORDER[i] and NAMEPLATE_OBJECTORDER[i] == "raidicon" then
        nameplate[NAMEPLATE_OBJECTORDER[i]] = object
      elseif NAMEPLATE_OBJECTORDER[i] then
        nameplate.original[NAMEPLATE_OBJECTORDER[i]] = object
        DisableObject(object)
      else
        DisableObject(object)
      end
    end

    -- Region ordering differs between OctoWoW client builds. Supply inert
    -- fallbacks for optional Blizzard regions so a missing name/level region
    -- cannot abort the central updater before the real unit data arrives.
    if not nameplate.original.name then nameplate.original.name = nameplate:CreateFontString(nil, "OVERLAY"); DisableObject(nameplate.original.name) end
    if not nameplate.original.level then nameplate.original.level = nameplate:CreateFontString(nil, "OVERLAY"); DisableObject(nameplate.original.level) end
    if not nameplate.original.guild then nameplate.original.guild = nameplate:CreateFontString(nil, "OVERLAY"); DisableObject(nameplate.original.guild) end
    if not nameplate.original.levelicon then nameplate.original.levelicon = nameplate:CreateTexture(nil, "OVERLAY"); DisableObject(nameplate.original.levelicon) end

    -- Some OctoWoW client builds expose HookScript but do not declare an
    -- OnValueChanged handler on Blizzard's nameplate statusbar. The central
    -- updater already mirrors values, so treat this hook as an optional fast
    -- path and never let it abort plate creation.
    if nameplate.original.healthbar and nameplate.original.healthbar.HookScript then
      pcall(nameplate.original.healthbar.HookScript, nameplate.original.healthbar,
        "OnValueChanged", nameplates.OnValueChanged)
    end

    -- adjust sizes and scaling of the nameplate
    nameplate:SetScale(UIParent:GetScale())

    nameplate.health = CreateFrame("StatusBar", nil, nameplate)
    nameplate.health:SetFrameLevel(4) -- keep above glow
    nameplate.health.text = nameplate.health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameplate.health.text:SetAllPoints()
    nameplate.health.text:SetTextColor(1,1,1,1)

    nameplate.name = nameplate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameplate.name:SetPoint("TOP", nameplate, "TOP", 0, 0)
    if zNameplates.CreateQuestIcon then zNameplates.CreateQuestIcon(nameplate) end

    nameplate.glow = nameplate:CreateTexture(nil, "BACKGROUND")
    nameplate.glow:SetPoint("CENTER", nameplate.health, "CENTER", 0, 0)
    nameplate.glow:SetTexture(zNameplates.media["img:dot"])
    nameplate.glow:Hide()

    nameplate.guild = nameplate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameplate.guild:SetPoint("BOTTOM", nameplate.health, "BOTTOM", 0, 0)

    nameplate.level = nameplate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameplate.level:SetPoint("RIGHT", nameplate.health, "LEFT", -3, 0)

    -- Create a dedicated high-level frame for the raid icon so it renders
    -- ABOVE nameplate.health (FrameLevel 4) and stays visible even when
    -- nameplates are toggled off (the Blizzard parent plate still exists).
    nameplate.raidiconframe = CreateFrame("Frame", nil, nameplate)
    nameplate.raidiconframe:SetFrameLevel(10)
    nameplate.raidiconframe:SetAllPoints(nameplate)
    -- Some client builds do not expose Blizzard's raid-icon region in the
    -- nameplate region list. Create a compatible replacement so one missing
    -- optional region cannot abort plate creation (and the overlap updater).
    if not nameplate.raidicon then
      nameplate.raidicon = nameplate:CreateTexture(nil, "OVERLAY")
    end
    nameplate.raidicon:SetParent(nameplate.raidiconframe)
    nameplate.raidicon:SetDrawLayer("OVERLAY", 7)
    if C.unitframes.blizzard_raidicons ~= "1" then
      nameplate.raidicon:SetTexture(zNameplates.media["img:raidicons"])
    end

    nameplate.totem = CreateFrame("Frame", nil, nameplate)
    nameplate.totem:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    nameplate.totem:SetSize(32, 32)
    nameplate.totem.icon = nameplate.totem:CreateTexture(nil, "OVERLAY")
    nameplate.totem.icon:SetTexCoord(.078, .92, .079, .937)
    nameplate.totem.icon:SetAllPoints()
    CreateBackdrop(nameplate.totem)

    do -- debuffs
      nameplate.debuffs = {}
      CreateDebuffIcon(nameplate, 1)
    end

    do -- combopoints
      local combopoints = { }
      for i = 1, 5 do
        combopoints[i] = CreateFrame("Frame", nil, nameplate)
        combopoints[i]:Hide()
        combopoints[i]:SetFrameLevel(8)
        combopoints[i].tex = combopoints[i]:CreateTexture("OVERLAY")
        combopoints[i].tex:SetAllPoints()

        if i < 3 then
          combopoints[i].tex:SetTexture(1, .3, .3, .75)
        elseif i < 4 then
          combopoints[i].tex:SetTexture(1, 1, .3, .75)
        else
          combopoints[i].tex:SetTexture(.3, 1, .3, .75)
        end
      end
      nameplate.combopoints = combopoints
    end

    do -- castbar
      local castbar = CreateFrame("StatusBar", nil, nameplate.health)
      castbar:Hide()

      castbar:SetScript("OnShow", function()
        if C.nameplates.debuffs["position"] == "BOTTOM" then
          nameplate.debuffs[1]:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, -4)
        end
      end)

      castbar:SetScript("OnHide", function()
        if C.nameplates.debuffs["position"] == "BOTTOM" then
          nameplate.debuffs[1]:SetPoint("TOPLEFT", this:GetParent(), "BOTTOMLEFT", 0, -4)
        end
      end)

      castbar.text = castbar:CreateFontString("Status", "DIALOG", "GameFontNormal")
      castbar.text:SetPoint("RIGHT", castbar, "LEFT", -4, 0)
      castbar.text:SetNonSpaceWrap(false)
      castbar.text:SetTextColor(1,1,1,.5)

      castbar.spell = castbar:CreateFontString("Status", "DIALOG", "GameFontNormal")
      castbar.spell:SetPoint("CENTER", castbar, "CENTER")
      castbar.spell:SetNonSpaceWrap(false)
      castbar.spell:SetTextColor(1,1,1,1)

      castbar.icon = CreateFrame("Frame", nil, castbar)
      castbar.icon.tex = castbar.icon:CreateTexture(nil, "BORDER")
      castbar.icon.tex:SetAllPoints()

      nameplate.castbar = castbar
    end

    -- Stagger tick to spread updates across frames (0.05s apart per plate)
    nameplate.tick = GetTime() + mathmod(platecount, 10) * 0.05

    parent.nameplate = nameplate
    -- NOTE: OnUpdate is now handled centrally, not per-plate/
    parent:SetScript("OnUpdate", nil)  -- Disable Blizzard's OnUpdate

    SetPlateDepthLayer(nameplate, "BACKGROUND", 4)

    nameplates.OnConfigChange(parent)
  end

  nameplates.OnConfigChange = function(frame)
    local parent = frame
    local nameplate = frame.nameplate

    local font = C.nameplates.use_unitfonts == "1" and zNameplates.font_unit or zNameplates.font_default
    local font_size = GetNameplateFontSize(nameplate.isFriendly)
    local font_style = (nameplate.isFriendly and (C.nameplates.name.fontstyle_friendly or C.nameplates.name.fontstyle)) or C.nameplates.name.fontstyle
    local glowr, glowg, glowb, glowa = GetStringColor(C.nameplates.glowcolor)
    local hlr, hlg, hlb, hla = GetStringColor(C.nameplates.highlightcolor)
    local hptexture = zNameplates.media[C.nameplates.healthtexture]
    local rawborder, default_border = GetBorderSize("nameplates")

    local plate_width = C.nameplates.width + 50
    local plate_height = C.nameplates.heighthealth + font_size + 5
    -- local plate_height_cast = C.nameplates.heighthealth + font_size + 5 + C.nameplates.heightcast + 5
    local combo_size = 5

    -- local width = tonumber(C.nameplates.width)
    -- local debuffsize = tonumber(C.nameplates.debuffsize)
    local healthoffset = tonumber(C.nameplates.health.offset)
    local orientation = C.nameplates.verticalhealth == "1" and "VERTICAL" or "HORIZONTAL"

    local c = combatstate -- load combat state colors
    c.CASTING.r, c.CASTING.g, c.CASTING.b, c.CASTING.a = GetStringColor(C.nameplates.combatcasting)
    c.THREAT.r, c.THREAT.g, c.THREAT.b, c.THREAT.a = GetStringColor(C.nameplates.combatthreat)
    c.NOTHREAT.r, c.NOTHREAT.g, c.NOTHREAT.b, c.NOTHREAT.a = GetStringColor(C.nameplates.combatnothreat)
    c.OFFTANK.r, c.OFFTANK.g, c.OFFTANK.b, c.OFFTANK.a = GetStringColor(C.nameplates.combatofftank)
    c.STUN.r, c.STUN.g, c.STUN.b, c.STUN.a = GetStringColor(C.nameplates.combatstun)

    RebuildOfftanks()

    nameplate:SetSize(plate_width, plate_height)
    nameplate:SetPoint("TOP", parent, "TOP", 0, 0)

    zNameplates.SetSmoothFontString(nameplate.name, font, font_size, font_style)
    if zNameplates.ConfigureQuestIcon then zNameplates.ConfigureQuestIcon(nameplate, font) end
    local nameTextPos = C.nameplates.nametextpos or "CENTER"
    local nameAnchor = nameTextPos == "RIGHT" and { "BOTTOMRIGHT", "TOPRIGHT" }
                    or nameTextPos == "CENTER" and { "BOTTOM", "TOP" }
                    or { "BOTTOMLEFT", "TOPLEFT" }
    nameplate.name:ClearAllPoints()
    nameplate.name:SetPoint(nameAnchor[1], nameplate.health, nameAnchor[2], 0, -healthoffset)
    nameplate.name:SetJustifyH(nameTextPos)

    nameplate.health:SetOrientation(orientation)
    -- Bar anchors to the plate directly so the name's JustifyH (configurable
    -- below) can shift left/right without dragging the bar with it.
    nameplate.health:ClearAllPoints()
    nameplate.health:SetPoint("BOTTOM", nameplate, "BOTTOM", 0, 0)
    nameplate.health:SetStatusBarTexture(hptexture)
    nameplate.health:SetWidth(C.nameplates.width)
    nameplate.health:SetHeight(C.nameplates.heighthealth)
    nameplate.health.hlr, nameplate.health.hlg, nameplate.health.hlb, nameplate.health.hla = hlr, hlg, hlb, hla

    CreateBackdrop(nameplate.health, default_border)

    nameplate.health.text:SetFont(font, font_size - 2, "OUTLINE")
    nameplate.health.text:SetJustifyH(C.nameplates.hptextpos)

    zNameplates.SetSmoothFontString(nameplate.guild, font, font_size, font_style)

    nameplate.glow:SetSize(C.nameplates.width + 60, C.nameplates.heighthealth + 30)
    nameplate.glow:SetVertexColor(glowr, glowg, glowb, glowa)

    nameplate.raidicon:ClearAllPoints()
    nameplate.raidicon:SetPoint("BOTTOM", nameplate.health, "TOP", C.nameplates.raidiconoffx, C.nameplates.raidiconoffy)
    zNameplates.SetSmoothFontString(nameplate.level, font, font_size, font_style)
    nameplate.raidicon:SetSize(C.nameplates.raidiconsize, C.nameplates.raidiconsize)

    for i=1,16 do
      UpdateDebuffConfig(nameplate, i)
    end

    for i=1,5 do
      nameplate.combopoints[i]:SetSize(combo_size, combo_size)
      nameplate.combopoints[i]:SetPoint("TOPRIGHT", nameplate.health, "BOTTOMRIGHT", -(i-1)*(combo_size+default_border*3), -default_border*3)
      CreateBackdrop(nameplate.combopoints[i], default_border)
    end

    nameplate.castbar:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -default_border*3)
    nameplate.castbar:SetPoint("TOPRIGHT", nameplate.health, "BOTTOMRIGHT", 0, -default_border*3)
    nameplate.castbar:SetHeight(C.nameplates.heightcast)
    -- Use the same castbar texture and color as the unit frame castbar (castbar.lua)
    local cbtexture = zNameplates.media[C.appearance.castbar.texture]
    nameplate.castbar:SetStatusBarTexture(cbtexture or hptexture)
    local cbr, cbg, cbb, cba = GetStringColor(C.appearance.castbar.castbarcolor)
    nameplate.castbar:SetStatusBarColor(cbr, cbg, cbb, cba)
    -- reset endTime cache so color/texture refresh takes effect on next cast
    nameplate.castbar.lastEndTime = nil
    CreateBackdrop(nameplate.castbar, default_border)

    nameplate.castbar.text:SetFont(font, font_size, "OUTLINE")
    nameplate.castbar.spell:SetFont(font, font_size, "OUTLINE")
    nameplate.castbar.icon:SetPoint("BOTTOMLEFT", nameplate.castbar, "BOTTOMRIGHT", default_border*3, 0)
    nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.health, "TOPRIGHT", default_border*3, 0)
    nameplate.castbar.icon:SetWidth(C.nameplates.heightcast + default_border*3 + C.nameplates.heighthealth)
    CreateBackdrop(nameplate.castbar.icon, default_border)
  end

  nameplates.OnValueChanged = function()
    local plate = this:GetParent().nameplate
    local healthbar = plate and plate.original and plate.original.healthbar
    if plate and plate.health and healthbar and healthbar.GetMinMaxValues and healthbar.GetValue then
      plate.health:SetMinMaxValues(healthbar:GetMinMaxValues())
      plate.health:SetValue(healthbar:GetValue())
    end
  end

  nameplates.OnDataChanged = function(self, plate)
    local healthbar = plate and plate.original and plate.original.healthbar
    if not healthbar or not healthbar.GetValue or not healthbar.GetMinMaxValues then return end

    local visible = plate:IsVisible()
    local hp = healthbar:GetValue()
    local hpmin, hpmax = healthbar:GetMinMaxValues()
    local name = plate.original.name:GetText()
    local unitName = plate.unit and UnitName(plate.unit)
    if unitName then name = unitName end
    local level = plate.original.level:IsShown() and plate.original.level:GetObjectType() == "FontString" and tonumber(plate.original.level:GetText()) or "??"

    -- reset per-unit cache when the plate is reassigned. Gate on GUID *and*
    -- name — name alone misses pool reuse between same-named units (e.g. plate
    -- held a player "Ironforge Guard" and is now reassigned to the NPC by the
    -- same name), which would leak a stale "PLAYER" hint into GetUnitInfo.
    -- Wipe the whole cache table: the PERF gates below ("only update X when
    -- X changed") would otherwise skip bar/color/text updates when the new
    -- unit happens to share a cached value with the previous occupant
    -- (e.g., both at 60% HP percentage on plate pool reuse → bar stays at
    -- the old fill until the new mob actually changes HP).
    if plate.cache.name ~= name or plate.cache.guid ~= plate.cachedGuid then
      table.wipe(plate.cache)
      plate.cache.name = name
      plate.cache.guid = plate.cachedGuid
      plate.cdCache = nil  -- new unit, reset spell-keyed timer cache
      plate.name:SetText(GetNameString(name))
    end

    local target = plate.istarget
    local mouseover = plate.cachedGuid and plate.cachedGuid == frameState.mouseoverGuid or nil
    -- Prefer the exact nameplate unit token. Target/mouseover are only fallback
    -- probes; using them first can misclassify two simultaneously visible
    -- units that happen to share a name.
    local unitstr = plate.unit or target and "target" or mouseover and "mouseover" or plate.cachedGuid or nil

    -- resolve player vs npc from plate's own unit so libunitscan can't return
    -- a player record for an NPC sharing the same name (e.g. Chromie). Stored
    -- as true/false/nil so it doubles as the GetUnitInfo hint.
    if plate.cache.player == nil and unitstr then
      plate.cache.player = UnitIsPlayer(unitstr) and true or false
    end
    local class, ulevel, elite, player, guild = GetUnitInfo(name, true, plate.cache.player)
    if plate.cache.player ~= nil then player = plate.cache.player or nil end

    -- Use database level ONLY if current level is ?? (fixes ?? after reload, but doesn't override visible levels)
    local levelFromDB = false
    if level == "??" and ulevel and ulevel > 0 then
      level = ulevel
      levelFromDB = true
    end

    local red, green, blue = 1, 0, 0
    if healthbar.GetStatusBarColor then
      red, green, blue = healthbar:GetStatusBarColor()
    end
    local unittype = GetUnitType(red, green, blue) or "ENEMY_NPC"
    local font_size = C.nameplates.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size

    -- ignore players with npc names if plate level is lower than player level
    if ulevel and ulevel > (level == "??" and -1 or level) then player = nil end

    if player and unittype == "ENEMY_NPC" then unittype = "ENEMY_PLAYER" end
    if player and unittype == "FRIENDLY_NPC" then unittype = "FRIENDLY_PLAYER" end

    -- Opposite-faction players cannot be attacked while the local player is not
    -- PvP flagged. Treat those otherwise-hostile player plates as friendly so
    -- every downstream nameplate rule (name colour, health visibility, overlap,
    -- outlines, and aura filtering) follows the friendly-player settings. This
    -- is recalculated on each data pass, so flagging for PvP restores the normal
    -- hostile presentation without requiring a reload.
    if unittype == "ENEMY_PLAYER" and UnitIsPVP and not UnitIsPVP("player") then
      unittype = "FRIENDLY_PLAYER"
    end

    plate.isCritter = CreatureType(plate) == 8
    plate.isTotem = CreatureType(plate) == 11
    plate.isNeutral = unittype == "NEUTRAL_NPC"
    if plate.isNeutral then
      if IsCombatWithPlayer(plate) then
        plate.neutralProvoked = true
      elseif plate.neutralProvoked and plate.unit and not UnitAffectingCombat(plate.unit) then
        plate.neutralProvoked = nil
      end
    else
      plate.neutralProvoked = nil
    end
    plate.isFriendly = unittype == "FRIENDLY_PLAYER" or unittype == "FRIENDLY_NPC"
    local font_style = plate.isFriendly and (C.nameplates.name.fontstyle_friendly or C.nameplates.name.fontstyle) or C.nameplates.name.fontstyle
    font_size = GetNameplateFontSize(plate.isFriendly)
    if plate.cache.fontStyle ~= font_style or plate.cache.fontSize ~= font_size then
      plate.cache.fontStyle = font_style
      plate.cache.fontSize = font_size
      local font = C.nameplates.use_unitfonts == "1" and zNameplates.font_unit or zNameplates.font_default
      zNameplates.SetSmoothFontString(plate.name, font, font_size, font_style)
      zNameplates.SetSmoothFontString(plate.guild, font, font_size, font_style)
      zNameplates.SetSmoothFontString(plate.level, font, font_size, font_style)
    end
    if plate.isFriendly or plate.isNeutral then
      plate.overlapEnabled = cfg.overlap_friendly
    else
      plate.overlapEnabled = cfg.overlap_enemy
    end
    elite = plate.original.levelicon:IsShown() and not player and "boss" or elite
    if not class then plate.wait_for_scan = true end

    -- skip data updates on invisible frames
    if not visible then return end

    -- target event sometimes fires too quickly, where nameplate identifiers are not
    -- yet updated. So while being inside this event, we cannot trust the unitstr.
    if event == "PLAYER_TARGET_CHANGED" then unitstr = nil end

    -- remove unitstr on unit name mismatch
    if unitstr and UnitName(unitstr) ~= name then unitstr = nil end

    -- always make sure to keep plate visible
    plate:Show()

    -- Tap ownership is only meaningful for NPC mobs. Unknown/untapped units
    -- retain their normal visuals; only positive ownership signals alter them.
    local tagUnit = plate.unit or unitstr
    local playerControlled = tagUnit and UnitPlayerControlled and UnitPlayerControlled(tagUnit)
    local enemyMob = (unittype == "ENEMY_NPC" or unittype == "NEUTRAL_NPC") and not playerControlled
    local tapped = enemyMob and tagUnit and UnitIsTapped and UnitIsTappedByPlayer and UnitIsTapped(tagUnit)
    -- Tap ownership persists when the mob changes target or the player changes
    -- focus. Do not tie the lime ownership outline to the transient threat state.
    local taggedByPlayer = tapped and UnitIsTappedByPlayer(tagUnit) or nil
    local taggedByOther = tapped and not taggedByPlayer or nil
    plate.taggedByPlayer = taggedByPlayer
    plate.taggedByOther = taggedByOther

    plate.glow:SetShown(target and cfg.targetglow)

    -- target indicator
    if taggedByPlayer then
      -- Confirmed player-owned combat tag always wins over threat, reaction,
      -- and target-highlight outline colours.
      plate.health.backdrop:SetBackdropBorderColor(.35, 1, .05, .75)
    elseif cfg.outcombatstate then
      local guid = plate.cachedGuid or ""

      -- determine color based on combat state
      local color = GetCombatStateColor(guid, plate.unit)
      if not color then color = combatstate.NONE end

      -- set border color
      plate.health.backdrop:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    elseif target and cfg.targethighlight then
      plate.health.backdrop:SetBackdropBorderColor(plate.health.hlr, plate.health.hlg, plate.health.hlb, plate.health.hla)
    elseif C.nameplates.outfriendlynpc == "1" and unittype == "FRIENDLY_NPC" then
      plate.health.backdrop:SetBackdropBorderColor(unpack(unitcolors[unittype]))
    elseif C.nameplates.outfriendly == "1" and unittype == "FRIENDLY_PLAYER" then
      plate.health.backdrop:SetBackdropBorderColor(unpack(unitcolors[unittype]))
    elseif C.nameplates.outneutral == "1" and strfind(unittype, "NEUTRAL") then
      plate.health.backdrop:SetBackdropBorderColor(unpack(unitcolors[unittype]))
    elseif C.nameplates.outenemy == "1" and strfind(unittype, "ENEMY") then
      plate.health.backdrop:SetBackdropBorderColor(unpack(unitcolors[unittype]))
    else
      plate.health.backdrop:SetBackdropBorderColor(er,eg,eb,ea)
    end

    -- hide frames according to the configuration
    local TotemIcon = TotemPlate(plate)

    if TotemIcon then
      -- icon resolved from the totem's aura / attack cast (already a full path)
      plate.totem.icon:SetTexture(TotemIcon)

      plate.glow:Hide()
      plate.level:Hide()
      plate.name:Hide()
      plate.health:Hide()
      plate.guild:Hide()
      plate.totem:Show()
    elseif HidePlate(unittype, (hpmax-hp == hpmin), target, plate) then
      plate.level:SetPoint("RIGHT", plate.name, "LEFT", -3, 0)
      plate.name:SetParent(plate)
      plate.guild:SetPoint("BOTTOM", plate.name, "BOTTOM", -2, -(font_size + 2))

      if plate.isCritter then plate.level:Hide() else plate.level:Show() end
      plate.name:Show()
      plate.health:Hide()
      if guild and C.nameplates.showguildname == "1" then
        plate.glow:SetPoint("CENTER", plate.name, "CENTER", 0, -(font_size / 2) - 2)
      else
        plate.glow:SetPoint("CENTER", plate.name, "CENTER", 0, 0)
      end
      plate.totem:Hide()
    else
      plate.level:SetPoint("RIGHT", plate.health, "LEFT", -5, 0)
      plate.name:SetParent(plate.health)
      plate.guild:SetPoint("BOTTOM", plate.health, "BOTTOM", 0, -(font_size + 4))

      if plate.isCritter then plate.level:Hide() else plate.level:Show() end
      plate.name:Show()
      plate.health:Show()
      plate.glow:SetPoint("CENTER", plate.health, "CENTER", 0, 0)
      plate.totem:Hide()
    end

    if zNameplates.UpdateQuestIcon then zNameplates.UpdateQuestIcon(plate, name, player or TotemIcon) end

    -- Gate level SetText behind a (level, elite) cache. string.format
    -- here was firing every OnDataChanged tick per plate; with the cache
    -- it only re-formats on real changes (level up / elite-state flip).
    if plate.cache.level ~= level or plate.cache.elite ~= elite then
      plate.cache.level = level
      plate.cache.elite = elite
      plate.level:SetText(string.format("%s%s", level, (elitestrings[elite] or "")))
    end

    -- Set level color from GetDifficultyColor when using DB level.
    -- No brightening here: adding a flat offset to all three channels
    -- desaturates every tier toward white and collapses the boundaries
    -- (orange reads as yellow, red reads as orange). Use Blizzard's values.
    -- Clearing cache.levelcolor forces the sync block in OnUpdate to
    -- re-colour once the ?? resolves and it takes ownership again.
    if levelFromDB and type(level) == "number" then
      local color = GetDifficultyColor(level)
      plate.level:SetTextColor(color.r, color.g, color.b, 1)
      plate.cache.levelcolor = nil
    end

    -- remember who owns the level colour so the two writers cannot fight
    plate.cache.levelfromdb = levelFromDB or nil

    if guild and C.nameplates.showguildname == "1" then
      plate.guild:SetText(plate.cache.player and ("<" .. guild .. ">") or guild)
      if guild == myGuild then
        plate.guild:SetTextColor(0, 0.9, 0, 1)
      else
        plate.guild:SetTextColor(0.8, 0.8, 0.8, 1)
      end
      plate.guild:Show()
    else
      plate.guild:Hide()
    end

    -- PERF: Only update bar + HP text when values actually changed
    if plate.cache.hp ~= hp or plate.cache.hpmax ~= hpmax then
      plate.cache.hp = hp
      plate.cache.hpmax = hpmax
      plate.health:SetMinMaxValues(hpmin, hpmax)
      plate.health:SetValue(hp)

    if cfg.showhp then
      local rhp, rhpmax, estimated
      local unit = plate.unit
      if unit then
        local npHp = UnitHealth(unit)
        local npMaxHp = UnitHealthMax(unit)
        if npHp and npHp > 0 and npMaxHp and npMaxHp > 0 and npMaxHp ~= 100 then
          rhp, rhpmax = npHp, npMaxHp
        end
      end

      -- Fallback to existing methods
      if not rhp then
        if hpmax > 100 or (round(hpmax/100*hp) ~= hp) then
          rhp, rhpmax = hp, hpmax
        end
      end

      local setting = cfg.hptextformat
      local hasdata = ( rhp and rhpmax ) or estimated or hpmax > 100 or (round(hpmax/100*hp) ~= hp)

      if setting == "curperc" and hasdata and rhp then
        plate.health.text:SetText(string.format("%s | %s%%", Abbreviate(rhp), ceil(hp/hpmax*100)))
      elseif setting == "cur" and hasdata and rhp then
        plate.health.text:SetText(string.format("%s", Abbreviate(rhp)))
      elseif setting == "curmax" and hasdata and rhp then
        plate.health.text:SetText(string.format("%s - %s", Abbreviate(rhp), Abbreviate(rhpmax)))
      elseif setting == "curmaxs" and hasdata and rhp then
        plate.health.text:SetText(string.format("%s / %s", Abbreviate(rhp), Abbreviate(rhpmax)))
      elseif setting == "curmaxperc" and hasdata and rhp then
        plate.health.text:SetText(string.format("%s - %s | %s%%", Abbreviate(rhp), Abbreviate(rhpmax), ceil(hp/hpmax*100)))
      elseif setting == "curmaxpercs" and hasdata and rhp then
        plate.health.text:SetText(string.format("%s / %s | %s%%", Abbreviate(rhp), Abbreviate(rhpmax), ceil(hp/hpmax*100)))
      elseif setting == "deficit" and rhp then
        plate.health.text:SetText(string.format("-%s" .. (hasdata and "" or "%%"), Abbreviate(rhpmax - rhp)))
      else -- "percent" as fallback
        plate.health.text:SetText(string.format("%s%%", ceil(hp/hpmax*100)))
      end
    else
      plate.health.text:SetText()
    end
    end -- hp cache gate

    local r, g, b, a = unpack(unitcolors[unittype])

    if class and (
      (unittype == "ENEMY_PLAYER" and C.nameplates["enemyclassc"] == "1") or
      (unittype == "FRIENDLY_PLAYER" and C.nameplates["friendclassc"] == "1")
    ) then
      r, g, b, a = PFUI_CLASS_COLORS[class]:GetRGBA()
    end

    if cfg.barcombatstate then
      local guid = plate.cachedGuid or ""
      local color = GetCombatStateColor(guid, plate.unit)

      if color then
        r, g, b, a = color.r, color.g, color.b, color.a
      end
    end

    if taggedByOther then
      -- Preserve perceived brightness while removing hue. This runs after the
      -- optional combat-state colour so another player's confirmed tap remains
      -- desaturated regardless of the selected bar-colour mode.
      local gray = r * .3 + g * .59 + b * .11
      r, g, b = gray, gray, gray
    end

    if r ~= plate.cache.r or g ~= plate.cache.g or b ~= plate.cache.b or a ~= plate.cache.a then
      plate.health:SetStatusBarColor(r, g, b, a)
      plate.cache.r, plate.cache.g, plate.cache.b, plate.cache.a = r, g, b, a
    end

    -- Resolve the name colour independently from the healthbar colour.
    local colorUnit = plate.unit or unitstr
    local nameR, nameG, nameB, nameA = GetStringColor(
      plate.isCritter and C.nameplates.critternamecolor or
      (plate.isFriendly and C.nameplates.friendlynamecolor or C.nameplates.enemynamecolor))
    if plate.isNeutral then
      nameR, nameG, nameB, nameA = unpack(unitcolors["NEUTRAL_NPC"])
    end
    local petHappiness = colorUnit and UnitIsUnit(colorUnit, "pet") and GetPetHappiness and GetPetHappiness() or nil
    local reaction = unittype == "FRIENDLY_NPC" and colorUnit and UnitReaction and UnitReaction("player", colorUnit) or nil
    local petColor = petHappiness and PET_HAPPINESS_NAME_COLORS[petHappiness]
    if not plate.isCritter and petColor then
      nameR, nameG, nameB, nameA = unpack(petColor)
    elseif not plate.isCritter and reaction then
      local factionColor = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
      if factionColor then
        nameR, nameG, nameB, nameA = factionColor.r, factionColor.g, factionColor.b, 1
      elseif REACTION_NAME_COLORS[reaction] then
        nameR, nameG, nameB, nameA = unpack(REACTION_NAME_COLORS[reaction])
      end
    elseif not plate.isCritter and class and ((unittype == "ENEMY_PLAYER" and C.nameplates.enemyclassc == "1") or
      (unittype == "FRIENDLY_PLAYER" and C.nameplates.friendclassnamec == "1")) then
      nameR, nameG, nameB, nameA = PFUI_CLASS_COLORS[class]:GetRGBA()
    end
    if taggedByOther then
      -- Only a positively confirmed tap owned by somebody else receives the
      -- dark-gray name override. Untapped/unknown mobs keep their normal colour.
      nameR, nameG, nameB, nameA = .3, .3, .3, 1
    end

    local nameColorKey = tostring(unittype) .. ":" .. tostring(class or "") .. ":" ..
      tostring(reaction or "") .. ":" .. tostring(petHappiness or "") .. ":" ..
      tostring(plate.isCritter) .. ":" .. tostring(taggedByOther) .. ":" .. tostring(C.nameplates.enemynamecolor) .. ":" .. tostring(C.nameplates.friendlynamecolor) .. ":" .. tostring(C.nameplates.critternamecolor) .. ":" ..
      tostring(C.nameplates.enemyclassc) .. ":" .. tostring(C.nameplates.friendclassnamec)
    if plate.cache.nameColorKey ~= nameColorKey then
      plate.cache.nameColorKey = nameColorKey
      plate.cache.nameR, plate.cache.nameG, plate.cache.nameB, plate.cache.nameA = nameR, nameG, nameB, nameA
      plate.name:SetTextColor(nameR, nameG, nameB, nameA)
    end

    -- Name colour ownership is handled entirely above.

    if target and C.nameplates.cpdisplay == "1" then
      local cp = GetComboPoints("target")
      if plate.cpShown ~= cp then
        for i=1, 5 do plate.combopoints[i]:SetShown(i <= cp) end
        plate.cpShown = cp
      end
    elseif plate.cpShown then
      for i=1, 5 do plate.combopoints[i]:Hide() end
      plate.cpShown = nil
    end

    -- update debuffs
    local index = 1

    local isFriendly = plate.isFriendly
    local showDebuffsForType = cfg.showdebuffs and (isFriendly and cfg.showdebuffs_friendly or (not isFriendly and cfg.showdebuffs_hostile))
    if showDebuffsForType then
      -- Pull debuffs from C_UnitAuras (HARMFUL range). owndebuffs adds the
      -- PLAYER filter token so only auras whose caster GUID matches the local
      -- player come through. debuffDisplayBuf is a module-level reusable
      -- buffer (no GC churn).
      local debuffCount = 0
      for i = 1, 16 do debuffDisplayBuf[i].effect = nil end
      if unitstr then
        local filter = cfg.owndebuffs and "HARMFUL|PLAYER" or "HARMFUL"
        local auras = C_UnitAuras.GetUnitAuras(unitstr, filter)
        local now = GetTime()
        for _, aura in ipairs(auras) do
          if debuffCount >= 16 then break end
          debuffCount = debuffCount + 1
          local timeleft = (aura.expirationTime and aura.expirationTime > 0) and (aura.expirationTime - now) or nil
          local b = debuffDisplayBuf[debuffCount]
          b.effect = aura.name
          b.texture = aura.icon
          b.stacks = aura.applications
          b.dtype = aura.dispelName
          b.duration = aura.duration
          b.timeleft = timeleft
        end
      end
      for i = 1, 16 do
        local effect, texture, stacks, dtype, duration, timeleft
        if debuffDisplayBuf[i].effect then
          local b = debuffDisplayBuf[i]
          effect, texture, stacks, dtype, duration, timeleft = b.effect, b.texture, b.stacks, b.dtype, b.duration, b.timeleft
        end

        if effect and texture and DebuffFilter(effect) then
          if not plate.debuffs[index] then
            CreateDebuffIcon(plate, index)
            UpdateDebuffConfig(plate, index)
          end

          plate.debuffs[index]:Show()
          plate.debuffs[index].icon:SetTexture(texture)
          plate.debuffs[index].icon:SetTexCoord(.078, .92, .079, .937)

          if stacks and stacks > 1 and C.nameplates.debuffs["showstacks"] == "1" then
            plate.debuffs[index].stacks:SetText(stacks)
            plate.debuffs[index].stacks:Show()
          else
            plate.debuffs[index].stacks:Hide()
          end

          if duration and timeleft and cfg.debufftimers then
            -- C_UnitAuras returns the Spell.dbc base duration, which talents
            -- can extend past — Shadow Affinity bumps SW:P from 18s to 24s,
            -- so a fresh cast has timeleft > duration and `now + timeleft -
            -- duration` lands in the future, which CooldownFrame_SetTimer
            -- treats as "not yet started" (no swirl). Widen to whichever is
            -- larger so start <= now.
            local effDuration = duration > timeleft and duration or timeleft
            plate.cdCache = plate.cdCache or {}
            local newStart = GetTime() + timeleft - effDuration
            local slotCache = plate.cdCache[index]
            local cachedStart = slotCache and slotCache.effect == effect and slotCache.start
            local cd = plate.debuffs[index].cd
            cd:Show()
            if not cachedStart or abs(cachedStart - newStart) > 0.5 then
              if not cd.configCached or cd.cachedAnim ~= cfg.debuffanim or cd.cachedText ~= cfg.debufftext then
                cd.pfCooldownStyleAnimation = cfg.debuffanim
                cd.pfCooldownStyleText = cfg.debufftext
                cd:SetAlpha(cfg.debuffanim == 1 and 1 or 0)
                cd.cachedAnim = cfg.debuffanim
                cd.cachedText = cfg.debufftext
                cd.configCached = true
              end
              CooldownFrame_SetTimer(cd, newStart, effDuration, 1)
              zNameplates.SetCooldown(cd, newStart, effDuration, 1)
              plate.cdCache[index] = plate.cdCache[index] or {}
              plate.cdCache[index].effect = effect
              plate.cdCache[index].start = newStart
            end
          end

          index = index + 1
        end
      end
    end

    -- hide remaining debuffs
    for i = index, 16 do
      if plate.debuffs[i] then
        plate.debuffs[i]:Hide()
      end
    end
  end

  nameplates.OnShow = function(frame)
    nameplates:OnDataChanged((frame or this).nameplate)
  end

  nameplates.OnUpdate = function(frame, state)
    local nameplate = frame.nameplate
    local now = state and state.now or GetTime()

    -- cachedGuid is maintained by NAME_PLATE_UNIT_ADDED / _REMOVED events.

    -- PERF: Intelligent throttling based on target/castbar status and plate count
    -- Use GUID comparison as primary target detection: instant, immune to alpha transitions,
    -- and immediately correct on de-target (unlike istarget which updates one tick later)
    local targetGuid = state and state.targetGuid
    local target = (targetGuid and nameplate.cachedGuid and targetGuid == nameplate.cachedGuid) or
                   (state and state.targetGuid and frame:GetAlpha() >= 0.99) or nil
    local configAlpha = cfg.notargalpha or 0.5
    local baseAlpha = (target or not targetGuid) and 1 or configAlpha

    -- Size, opacity, and line-of-sight transitions run at the fast central
    -- cadence so movement remains continuous even when normal plate data is
    -- using the lower non-target update rate.
    ApplyDistanceEffects(nameplate, now, baseAlpha)
    -- Target plate castbar runs on its own dedicated frame (nameplates.castbarFrame).
    -- For non-target plates with castbar active, use castbar throttle to ensure
    -- smooth animation without overloading the central loop.
    local isCastingNonTarget = not target and nameplate.castbar and nameplate.castbar:IsShown()
    if not isCastingNonTarget and not target and cfg.showcastbar and nameplate.cachedGuid then
      local castInfo = GetCastInfo(nameplate.unit)
      if castInfo and castInfo.endTime > now then
        isCastingNonTarget = true
      end
    end

    -- hide castbar before throttle if no cast active
    if not isCastingNonTarget and not target then
      if nameplate.castbar.isShown then
        nameplate.castbar.isShown = nil
        nameplate.castbar.lastEndTime = nil
        nameplate.castbar:Hide()
      end
    end

    local throttle
    if target then
      throttle = zNameplates.throttle:Get("nameplates_target")
    elseif visiblePlateCount > 20 then
      throttle = zNameplates.throttle:Get("nameplates_mass")
    else
      throttle = zNameplates.throttle:Get("nameplates")
    end

    -- Non-target plates with active castbar use the castbar throttle
    if isCastingNonTarget then
      local cbThrottle = zNameplates.throttle:Get("nameplates_castbar")
      if cbThrottle < throttle then throttle = cbThrottle end
    end

    -- Check for pending event updates (these bypass throttle for immediate response)
    local hasEventUpdate = nameplate.eventcache or nameplate.auraUpdate or nameplate.castUpdate or nameplate.targetUpdate or nameplate.comboUpdate

    -- Event updates bypass throttle
    if not hasEventUpdate and (nameplate.lasttick or 0) + throttle > now then return end
    nameplate.lasttick = now
    
    -- =========================================================================
    -- EVERYTHING BELOW RUNS AT THROTTLED RATE (50 FPS target, 10 FPS others)
    -- =========================================================================
    
    local update
    local original = nameplate.original
    if not original or not original.name or not original.name.GetText then return end
    local name = original.name:GetText()
    local mouseover = nameplate.cachedGuid and nameplate.cachedGuid == frameState.mouseoverGuid or nil

    -- trigger queued event update
    if hasEventUpdate then
      nameplates:OnDataChanged(nameplate)
      nameplate.eventcache = nil
      nameplate.auraUpdate = nil
      nameplate.castUpdate = nil
      nameplate.targetUpdate = nil
      nameplate.comboUpdate = nil
    end

    -- =========================================================================
    -- OVERLAP/CLICKTHROUGH HANDLING
    -- =========================================================================
    local overlapEnabled = ShouldOverlap(nameplate)
    local edgeReleased = ReleaseAtScreenEdge(frame, nameplate, overlapEnabled)
    local collisionReleased = overlapEnabled or edgeReleased
    local useOverlap = collisionReleased or C.nameplates["vertical_offset"] ~= "0"
    local clickable = C.nameplates["clickthrough"] ~= "1"

    if not clickable then
      frame:EnableMouse(false)
      nameplate:EnableMouse(false)
    elseif useOverlap then
      frame:EnableMouse(false)
      nameplate:EnableMouse(true)
    else
      frame:EnableMouse(true)
      nameplate:EnableMouse(false)
    end

    if collisionReleased then
      if frame:GetWidth() > 1 then
        frame:SetSize(1, 1)
      end
    else
      if not nameplate.dwidth then
        nameplate.dwidth = floor(nameplate:GetWidth() * nameplate:GetScale())
      end

      if floor(frame:GetWidth()) ~= nameplate.dwidth then
        local nameW, nameH = nameplate:GetSize()
        local plateScale = nameplate:GetScale()
        frame:SetSize(nameW * plateScale, nameH * plateScale)
      end
    end

    local mouseEnabled = nameplate:IsMouseEnabled()
    if C.nameplates["clickthrough"] == "0" and collisionReleased and SpellIsTargeting() == mouseEnabled then
      nameplate:EnableMouse(not mouseEnabled)
    end

    -- Target transition triggers immediate depth layer update
    if nameplate.istarget ~= target then
      nameplate.istarget = target
      nameplates.depthUpdateAt = 0
    end

    -- queue update on visual target update
    if nameplate.cache.target ~= target then
      nameplate.cache.target = target
      update = true
    end

    -- queue update on visual mouseover update
    if nameplate.cache.mouseover ~= mouseover then
      nameplate.cache.mouseover = mouseover
      update = true
    end

    -- trigger update when unit was found. Pass the cached player hint so the
    -- retry probes the same table OnDataChanged will read on the next pass —
    -- otherwise an NPC sharing a name with a known player flips wait_for_scan
    -- off here, then OnDataChanged re-sets it, every frame until the mob scan
    -- lands.
    if nameplate.wait_for_scan and GetUnitInfo(name, true, nameplate.cache.player) then
      nameplate.wait_for_scan = nil
      update = true
    end

    -- Another player's tap owns the dark-gray name state. Neutral names keep
    -- reaction yellow; all other plates may still use the configured combat tint.
    local unit = nameplate.unit
    local inCombatWithPlayer = cfg.namefightcolor and unit and UnitExists(unit) and
      UnitAffectingCombat(unit) and UnitAffectingCombat("player") or nil
    local combatNameOverride = inCombatWithPlayer and not nameplate.taggedByOther and not nameplate.isNeutral or nil
    if nameplate.cache.inCombat ~= combatNameOverride then
      nameplate.cache.inCombat = combatNameOverride
      if combatNameOverride then
        nameplate.name:SetTextColor(1, .4, .2, 1)
      elseif nameplate.cache.nameR then
        nameplate.name:SetTextColor(nameplate.cache.nameR, nameplate.cache.nameG,
          nameplate.cache.nameB, nameplate.cache.nameA)
      end
      update = true
    end

    -- trigger update when level color changed. Skipped while the level came
    -- from the database (?? plates), where OnDataChanged owns the colour --
    -- otherwise both writers race and cache.levelcolor goes stale, which
    -- leaves a recycled plate wearing the previous unit's colour.
    if not nameplate.cache.levelfromdb then
      local r, g, b = original.level:GetTextColor()
      if r + g + b ~= nameplate.cache.levelcolor then
        nameplate.cache.levelcolor = r + g + b
        nameplate.level:SetTextColor(r,g,b,1)
        update = true
      end
    end

    -- use timer based updates
    if not nameplate.tick or nameplate.tick < now then
      update = true
    end

    -- run full updates if required
    if update then
      nameplates:OnDataChanged(nameplate)
      nameplate.tick = now + .5
    end

    -- Zoom animation
    if target and cfg.targetzoom then
      if not nameplate.health.zoomed then
        local zoomval = cfg.zoomval
        local wc = cfg.width * zoomval
        local hc = cfg.heighthealth * (zoomval * .9)
        nameplate.health.targetWidth = wc
        nameplate.health.targetHeight = hc
      end
      
      local w, h = nameplate.health:GetSize()
      local wc, hc = nameplate.health.targetWidth, nameplate.health.targetHeight
      
      if wc and hc then
        if wc > w + 0.5 then
          nameplate.health:SetWidth(w*1.05)
          nameplate.health.zoomTransition = true
        elseif hc > h + 0.5 then
          nameplate.health:SetHeight(h*1.05)
          nameplate.health.zoomTransition = true
        else
          if nameplate.health.zoomTransition then
            nameplate.health:SetSize(wc, hc)
            nameplate.health.zoomTransition = nil
          end
          nameplate.health.zoomed = true
        end
      end
    elseif nameplate.health.zoomed or nameplate.health.zoomTransition then
      local w, h = nameplate.health:GetSize()
      local wc = cfg.width
      local hc = cfg.heighthealth

      if w > wc + 0.5 then
        nameplate.health:SetWidth(w*.95)
      elseif h > hc + 0.5 then
        nameplate.health:SetHeight(h*0.95)
      else
        nameplate.health:SetSize(wc, hc)
        nameplate.health.zoomTransition = nil
        nameplate.health.zoomed = nil
        nameplate.health.targetWidth = nil
        nameplate.health.targetHeight = nil
      end
    end

    -- Target plate castbar is handled by nameplates.castbarFrame (dedicated OnUpdate,
    -- engine framerate, decoupled from central loop). Only update non-target castbars here.
    local isTargetPlate = target or nameplate.istarget or (nameplate.health and nameplate.health.zoomed)
    if cfg.showcastbar and not cfg.targetcastbar and not isTargetPlate then
      local cbThrottle = zNameplates.throttle:Get("nameplates_castbar")
      if visiblePlateCount > 20 then
        local massThrottle = zNameplates.throttle:Get("nameplates_mass")
        if massThrottle > cbThrottle then cbThrottle = massThrottle end
      end
      if (nameplate.castbar_tick or 0) + cbThrottle <= now then
        nameplate.castbar_tick = now
        nameplates.UpdateCastbar(nameplate, now)
      end
    elseif cfg.showcastbar and cfg.targetcastbar and not isTargetPlate then
      if nameplate.castbar.isShown then
        nameplate.castbar.isShown = nil
        nameplate.castbar.lastEndTime = nil
        nameplate.castbar:Hide()
      end
    elseif not cfg.showcastbar then
      if nameplate.castbar.isShown then
        nameplate.castbar.isShown = nil
        nameplate.castbar.lastEndTime = nil
        nameplate.castbar:Hide()
      end
    end
  end

  -- ============================================================================
  -- DEDICATED TARGET CASTBAR FRAME
  -- Runs on its own OnUpdate, decoupled from the central nameplate loop.
  -- Mirrors the approach used in castbar.lua for the target unit frame castbar.
  -- ============================================================================

  -- Skip SetText when the rounded value hasn't changed since last frame.
  -- `string.format("%.2f", ...)` allocates a fresh string every call; this
  -- gate compares cheap integers and only formats when the displayed value
  -- would actually differ. Reset via lastEndTime-changed branch above.
  local function SetCastbarText(castbar, remaining)
    local rounded
    if C.unitframes.castbardecimals == "1" then
      rounded = floor(remaining * 10)
      if castbar.lastTextTick ~= rounded then
        castbar.lastTextTick = rounded
        castbar.text:SetText(rounded / 10)
      end
    else
      rounded = floor(remaining * 100)
      if castbar.lastTextTick ~= rounded then
        castbar.lastTextTick = rounded
        castbar.text:SetText(string.format("%.2f", remaining))
      end
    end
  end

  -- Shared castbar update logic (used by both dedicated frame and central loop)
  nameplates.UpdateCastbar = function(nameplate, now)
    if not nameplate or not nameplate.castbar then return end
    local castInfo = GetCastInfo(nameplate.unit)
    if not castInfo or castInfo.endTime < now then
      nameplate.castbar.isShown = nil
      nameplate.castbar.lastEndTime = nil
      nameplate.castbar:Hide()
      return
    end

    local isChannel = castInfo.isChannel
    local duration = castInfo.duration
    if nameplate.castbar.lastEndTime ~= castInfo.endTime then
      nameplate.castbar.lastEndTime = castInfo.endTime
      nameplate.castbar.lastTextTick = nil
      -- Relative 0..duration range to avoid float precision loss with large
      -- absolute timestamps.
      nameplate.castbar:SetMinMaxValues(0, duration)
      nameplate.castbar:SetStatusBarColor(GetStringColor(C.appearance.castbar[(isChannel and "channelcolor" or "castbarcolor")]))
      if castInfo.icon then
        nameplate.castbar.icon.tex:SetTexture(castInfo.icon)
        nameplate.castbar.icon.tex:SetTexCoord(.1,.9,.1,.9)
      end
      if cfg.spellname then
        nameplate.castbar.spell:SetText(castInfo.spellName)
      else
        nameplate.castbar.spell:SetText("")
      end
    end

    local barValue = isChannel and (castInfo.endTime - now) or (now - castInfo.startTime)
    if barValue < 0 then barValue = 0 end
    if barValue > duration then barValue = duration end
    nameplate.castbar:SetValue(barValue)
    SetCastbarText(nameplate.castbar, castInfo.endTime - now)
    if not nameplate.castbar.isShown then nameplate.castbar.isShown = true; nameplate.castbar:Show() end
  end

  -- Dedicated frame that updates ONLY the target plate castbar. Unthrottled:
  -- now that casts are event-driven, this just reads the cache + SetValue, so
  -- it animates the fill every frame for the smoothest sweep on the bar the
  -- player watches most. (Non-target plates stay throttled via the central
  -- loop's nameplates_castbar gate.)
  nameplates.castbarFrame = CreateFrame("Frame", nil, UIParent)
  nameplates.castbarFrame:SetScript("OnUpdate", function()
    if not cfg.showcastbar or not frameState.targetGuid then return end
    local nameplate = plateByGuid[frameState.targetGuid]
    if not nameplate then return end
    nameplates.UpdateCastbar(nameplate, GetTime())
  end)

  -- set nameplate game settings
  nameplates.SetGameVariables = function()
    -- update visibility (hostile)
    if C.nameplates["showhostile"] == "1" then
      _G.NAMEPLATES_ON = true
      ShowNameplates()
    else
      _G.NAMEPLATES_ON = nil
      HideNameplates()
    end

    -- update visibility (hostile)
    if C.nameplates["showfriendly"] == "1" then
      _G.FRIENDNAMEPLATES_ON = true
      ShowFriendNameplates()
    else
      _G.FRIENDNAMEPLATES_ON = nil
      HideFriendNameplates()
    end
  end

  nameplates:SetGameVariables()

  nameplates.UpdateConfig = function()
    -- Refresh config cache for all cfg.* values
    CacheConfig()
    RebuildOfftanks()
    
    -- update debuff filters
    DebuffFilterPopulate()

    -- Check friendly zone state when config changes
    local disableHostile = C.nameplates["disable_hostile_in_friendly"] == "1"
    local disableFriendly = C.nameplates["disable_friendly_in_friendly"] == "1"
    local nowFriendly = IsPlayerFriendlyArea()
    inFriendlyArea = nowFriendly
    
    if nowFriendly and (disableHostile or disableFriendly) then
      if not inFriendlyZone then
        -- Just entered friendly zone or feature just enabled
        inFriendlyZone = true
        savedHostileState = C.nameplates["showhostile"]
        savedFriendlyState = C.nameplates["showfriendly"]
      end
      
      -- Apply current settings based on options
      if disableHostile then
        _G.NAMEPLATES_ON = nil
        HideNameplates()
      else
        -- Restore hostile if option is off but we're in friendly zone
        if savedHostileState == "1" then
          _G.NAMEPLATES_ON = true
          ShowNameplates()
        end
      end
      
      if disableFriendly then
        _G.FRIENDNAMEPLATES_ON = nil
        HideFriendNameplates()
      else
        -- Restore friendly if option is off but we're in friendly zone
        if savedFriendlyState == "1" then
          _G.FRIENDNAMEPLATES_ON = true
          ShowFriendNameplates()
        end
      end
      
      return -- Don't call SetGameVariables
    elseif inFriendlyZone and not (disableHostile or disableFriendly) then
      -- Both features disabled while in friendly zone - restore state
      inFriendlyZone = false
      
      if savedHostileState == "1" then
        C.nameplates["showhostile"] = savedHostileState
      end
      
      if savedFriendlyState == "1" then
        C.nameplates["showfriendly"] = savedFriendlyState
      end
      
      savedHostileState = nil
      savedFriendlyState = nil
      -- Fall through to SetGameVariables to restore nameplates
    end

    -- update nameplate visibility
    nameplates:SetGameVariables()

    -- apply all config changes
    for plate in pairs(registry) do
      nameplates.OnConfigChange(plate)
      if plate.nameplate and plate.nameplate.cachedGuid then
        nameplates:OnDataChanged(plate.nameplate)
      end
    end
  end

  local hookOnConfigChange = nameplates.OnConfigChange
  nameplates.OnConfigChange = function(self)
    hookOnConfigChange(self)

    local parent = self
    local nameplate = self.nameplate
    local overlapEnabled = cfg.overlap_enemy
    if nameplate.isFriendly or nameplate.isNeutral then overlapEnabled = cfg.overlap_friendly end
    nameplate.overlapEnabled = overlapEnabled

    -- disable all clicks for now
    parent:EnableMouse(false)
    nameplate:EnableMouse(false)

    -- adjust vertical offset
    if C.nameplates["vertical_offset"] ~= "0" then
      nameplate:SetPoint("TOP", parent, "TOP", 0, tonumber(C.nameplates["vertical_offset"]))
    end

    -- The overlay only receives mouse input when overlap or vertical offset is
    -- active, but keeping its forwarding handler installed avoids stale click
    -- behavior when a pooled plate changes from friendly to hostile (or back).
    nameplate:SetScript("OnClick", function() parent:Click() end)

    -- enable mouselook on rightbutton down
    if C.nameplates["rightclick"] == "1" then
      parent:SetScript("OnMouseDown", nameplates.mouselook.OnMouseDown)
      nameplate:SetScript("OnMouseDown", nameplates.mouselook.OnMouseDown)
    else
      parent:SetScript("OnMouseDown", nil)
      nameplate:SetScript("OnMouseDown", nil)
    end
  end

  local hookOnDataChanged = nameplates.OnDataChanged
  nameplates.OnDataChanged = function(self, nameplate)
    hookOnDataChanged(self, nameplate)

    -- The normal data pass restores live reaction/threat colours. Reapply the
    -- grayscale treatment once after that pass while the unit remains blocked.
    if nameplate.losOutOfSight then
      SetLineOfSightDesaturation(nameplate, true, true)
    end

    -- Keep mouse ownership on the correct frame when a pooled nameplate changes
    -- between friendly and non-friendly units.
    if (ShouldOverlap(nameplate) or C.nameplates["vertical_offset"] ~= "0") then
      nameplate.parent:EnableMouse(false)
    else
      nameplate:EnableMouse(false)
    end
  end

  -- enable mouselook on rightbutton down
  nameplates.mouselook = CreateFrame("Frame", nil, UIParent)
  nameplates.mouselook.time = nil
  nameplates.mouselook.frame = nil
  nameplates.mouselook.OnMouseDown = function()
    if arg1 and arg1 == "RightButton" then
      MouselookStart()

      -- start detection of the rightclick emulation
      nameplates.mouselook.time = GetTime()
      nameplates.mouselook.frame = this
      nameplates.mouselook:Show()
    end
  end

  nameplates.mouselook:SetScript("OnUpdate", function()
    -- break here if nothing to do
    if not this.time or not this.frame then
      this:Hide()
      return
    end

    -- if threshold is reached (0.5 second) no click action will follow
    if not IsMouselooking() and this.time + tonumber(C.nameplates["clickthreshold"]) < GetTime() then
      this:Hide()
      return
    end

    -- run a usual nameplate rightclick action
    if not IsMouselooking() then
      this.frame:Click("LeftButton")
      if UnitCanAttack("player", "target") and not nameplates.combat.inCombat then AttackTarget() end
      this:Hide()
      return
    end
  end)

  -- The combat-list panel mirrors these existing plate objects and their live
  -- rendered colours instead of building a second nameplate scanner.
  nameplates.visiblePlates = visiblePlates
  nameplates.IsCombatWithPlayer = IsCombatWithPlayer
  zNameplates.nameplates = nameplates
end

-- pfUI used a private module environment, so its helpers were globals from the
-- compiler's perspective. Recreate that boundary without loading any pfUI code.
local moduleEnvironment = setmetatable({
  C = false,
  strsplit = zNameplates.StrSplit,
  round = zNameplates.Round,
  Abbreviate = zNameplates.Abbreviate,
  GetStringColor = zNameplates.GetStringColor,
  GetBorderSize = zNameplates.GetBorderSize,
  CreateBackdrop = zNameplates.CreateBackdrop,
  GetUnitInfo = zNameplates.GetUnitInfo,
  PFUI_CLASS_COLORS = zNameplates.classColors,
  NAMEPLATE_OBJECTORDER = zNameplates.NAMEPLATE_OBJECTORDER,
  COOLDOWN_FRAME_TYPE = zNameplates.cooldownFrameType,
  CooldownFrame_OnUpdateModel = zNameplates.CooldownFrame_OnUpdateModel,
  UnitCreatureTypeID = UnitCreatureTypeID or function() return nil end,
}, { __index = getfenv(0) })
setfenv(zNameplates.StartNameplates, moduleEnvironment)
