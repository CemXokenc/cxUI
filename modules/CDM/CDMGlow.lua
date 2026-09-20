local addonName, ns = ...

-- ===========================================================================
-- CDM: PROC / READY GLOW
-- Glows CDM icons when a tracked aura, Blizzard overlay proc, or "ready"
-- cooldown is active. Edit PROC_CONFIG to add your own spells.
-- Fully inert while the option is off: no events, no timers, no glows.
-- ===========================================================================

local CDM = ns:GetModule("CDM")

local F = CDM:NewFeature{
    key  = "cdmGlow",
    name = "Enable CDM Proc Glow",
    desc = "Special highlights for class-specific procs.",
}

local IsSafeFrame      = CDM.IsSafeFrame
local GetButtonSpellID = CDM.GetButtonSpellID

-- ---------------------------------------------------------------------------
-- PROC CONFIG
-- ---------------------------------------------------------------------------
-- Key types:
--   [numericAuraID] = { spellID, ... }     glow when aura is active on player
--   ["cdm:spellID"] = { spellID }          glow whenever frame is visible in CDM
--   ["overlay:spellID"] = { spellID }      glow driven by SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE
--   ["ready:spellID"] = { spellID }        glow when spell is not on cooldown and IsSpellUsable
-- ---------------------------------------------------------------------------

local PROC_CONFIG = {
    DEATHKNIGHT = {
        -- Procs
        -- [81340] = { 47541, 207317, 1242174, 383269 },    -- Sudden Doom            → Death Coil, Epidemic, Necrotic Coil, Graveyard
        -- [51124] = { 49020, 207230 },                     -- Killing Machine        → Obliterate, Frostscythe
        -- ["overlay:49184"] = { 49184 },                   -- Rime                   → Howling Blast
        -- ["cdm:1228433"]   = { 1228433 },                 -- Frostbane              → always glow if present in CDM
        -- CDs
        -- ["ready:42650"]   = { 42650 },                   -- Army of the Dead       → glow when ready
        -- ["ready:1249658"] = { 1249658 },                 -- Breath of Sindragosa   → glow when ready
        -- Utility
        -- ["ready:47528"] = { 47528 },                     -- Mind Freeze            → glow when ready
        -- ["ready:49576"] = { 49576 },                     -- Death Grip             → glow when ready
    },
    MAGE = {
        -- Procs
        -- [44544]  = { 30455 },                            -- Fingers of Frost       → Ice Lance
        -- [190446] = { 44614 },                            -- Brain Freeze           → Flurry
        -- [270232] = { 190356 },                           -- Freezing Rain          → Blizzard
        -- ["cdm:199786"] = { 199786 },                     -- Glacial Spike          → always glow if present in CDM
        -- CDs
        -- ["ready:84714"] = { 84714 },                     -- Frozen Orb             → glow when ready
        -- Utility
        -- ["ready:2139"] = { 2139 },                       -- Counterspell           → glow when ready
        -- ["ready:475"]  = { 475 },                        -- Remove Curse           → glow when ready
        -- ["ready:30449"]  = { 30449 },                    -- Spellsteal             → glow when ready
		
    },
    WARLOCK = {
        -- Procs
        -- [264173] = { 264178 },                           -- Demonic Core           → Demonbolt
        -- ["cdm:434635"]  = { 434635 },                    -- Ruination              → always glow if present in CDM
        -- ["cdm:434506"]  = { 434506 },                    -- Infernal Bolt          → always glow if present in CDM
        -- CDs
        ["ready:105174"] = { 105174 },                      -- Hand of Gul'dan        → glow when ready
        -- ["ready:104316"] = { 104316 },                   -- Call Dreadstalkers     → glow when ready
        -- ["ready:265187"] = { 265187 },                   -- Summon Demonic Tyrant  → glow when ready
        -- ["cdm:1276452"]  = { 1276452 },                  -- Grimoire: Imp Lord     → always glow if present in CDM
        -- ["cdm:1276467"]  = { 1276467 },                  -- Grimoire: Fel Ravager  → always glow if present in CDM
        -- Utility
        -- ["ready:119914"] = { 119914 },                   -- Axe Toss               → glow when ready
        -- ["ready:119910"] = { 119910 },                   -- Spell Lock             → glow when ready
        -- ["ready:89808"] = { 89808 },                     -- Singe Magic            → glow when ready
        -- ["ready:19505"] = { 19505 },                     -- Devour Magic           → glow when ready
    },
    WARRIOR = {
		-- Procs
		-- [29725] = { 281000 },                     		-- Sudden Death           → Execute
		-- CDs
		-- ["ready:12294"]  = { 12294 },                    -- Mortal Strike          → glow when ready
		-- ["ready:446035"]  = { 446035 },                  -- Bladestorm             → glow when ready
		-- ["ready:260708"]  = { 260708 },                  -- Sweeping Strikes       → glow when ready
		-- Utility
		-- ["ready:6552"]  = { 6552 },                      -- Pummel                 → glow when ready
		-- ["ready:64382"]  = { 64382 },                    -- Shattering Throw       → glow when ready
	}, 
	PALADIN = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:96231"] = { 96231 },                     -- Rebuke                 → glow when ready
		-- ["ready:4987"] = { 4987 },                       -- Cleanse                → glow when ready
		-- ["ready:213644"] = { 213644 },                   -- Cleanse Toxins         → glow when ready
	}, 
	HUNTER = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:147362"] = { 147362 },                   -- Counter Shot           → glow when ready		
		-- ["ready:19801"] = { 19801 },                     -- Tranquilizing Shot     → glow when ready		
		["ready:212640"] = { 212640 },                      -- Mending Bandage        → glow when ready
	}, 
	ROGUE = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:1766"]  = { 1766 },                      -- Kick                   → glow when ready
		-- ["ready:5938"]  = { 5938 },                      -- Shiv                   → glow when ready
	},
    PRIEST = {
        -- Procs
        -- [375981] = { 8092, 450983 },                     -- Shadowy Insight        → Mind Blast, Void Blast
        -- [373204] = { 335467 },                           -- Mind Devourer          → Shadow Word: Madness
        -- CDs
        -- ["ready:228260"]  = { 228260 },                  -- Voidform               → glow when ready
        -- ["ready:1242173"] = { 1242173 },                 -- Void Volley            → glow when ready
        -- ["ready:120644"]  = { 120644 },                  -- Halo                   → glow when ready
        -- ["ready:120517"]  = { 120517 },                  -- Halo (Holy)            → glow when ready
        -- ["ready:263165"]  = { 263165 },                  -- Void Torrent           → glow when ready
        ["ready:450983"]  = { 450983 },                     -- Void Blast             → glow when ready
        -- Utility
        -- ["ready:15487"]  = { 15487 },                    -- Silence                → glow when ready
        -- ["ready:32375"] = { 32375 },                     -- Mass Dispel            → glow when ready
        -- ["ready:213634"] = { 213634 },                   -- Purify Disease         → glow when ready
        -- ["ready:527"]    = { 527 },                      -- Purify                 → glow when ready
    },
    SHAMAN = {
		-- Procs		
        -- CDs
		-- ["ready:452201"]  = { 452201 },                  -- Tempest                → glow when ready
		-- ["ready:191634"]  = { 191634 },                  -- Stormkeeper            → glow when ready
		-- ["ready:114050"]  = { 114050 },                  -- Ascendance             → glow when ready
		["ready:462620"]  = { 462620 },                     -- Earth Quake            → glow when ready
		["ready:117014"]  = { 117014 },                     -- Elemental Blast        → glow when ready
        -- Utility
		-- ["ready:57994"]  = { 57994 },                    -- Wind Shear             → glow when ready
		-- ["ready:8166"]  = { 8166 },                      -- Poison Cleansing Totem → glow when ready
		-- ["ready:51886"]  = { 51886 },                    -- Cleanse Spirit         → glow when ready
		-- ["ready:77130"]  = { 77130 },                    -- Purify Spirit          → glow when ready
		-- ["ready:370"]  = { 370 },                        -- Purge                  → glow when ready
	},
    MONK = {
        -- Procs
        -- [438443] = { 101546 },                           -- Dance of Chi-Ji        → Spinning Crane Kick
        -- [443112] = { 124682 },                           -- Strength of the Black  → Enveloping Mist
        -- CDs		
        -- Utility
		-- ["ready:116705"] = { 116705 },                   -- Spear Hand Strike      → glow when ready
		-- ["ready:218164"] = { 218164 },                   -- Detox                  → glow when ready
		-- ["ready:115450"] = { 115450 },                   -- Detox                  → glow when ready
    },
    DRUID = {
		-- Procs
        -- CDs  
		--["ready:204066"] = { 204066 },                    -- Lunar Beam             → glow when ready		
		--["ready:202770"] = { 202770 },                    -- Fury of Elune          → glow when ready		
		--["ready:1261867"] = { 1261867 },                  -- Heart of the Wild      → glow when ready
        -- Utility
		-- ["ready:106839"]  = { 106839 },                  -- Skull Bash             → glow when ready
		-- ["ready:78675"]  = { 78675 },   		            -- Solar Beam	          → glow when ready		
		-- ["ready:106839"]  = { 106839 },   		        -- Skull Bash	          → glow when ready		
		--["ready:2782"]  = { 2782 },   		            -- Remove Corruption	  → glow when ready
		--["ready:88423"]  = { 88423 },   		            -- Nature's Cure          → glow when ready
		--["ready:2908"]  = { 2908 },   		            -- Soothe        	      → glow when ready
	},
    DEMONHUNTER = {
        -- Procs
        --["cdm:1225826"] = { 1225826 },                    -- Eradicate              → always glow if present in CDM
        --["cdm:1221150"] = { 1221150 },                    -- Collapsing Star        → always glow if present in CDM
        -- CDs
        -- ["ready:1217605"] = { 1217605 },                 -- Void Metamorphosis     → glow when ready
        -- ["ready:191427"]  = { 191427 },                  -- Metamorphosis          → glow when ready
        ["ready:473728"]  = { 473728 },                     -- Void Ray               → glow when ready
        ["ready:198013"]  = { 198013 },                     -- Eye Beam               → glow when ready
        -- Utility
        -- ["ready:183752"] = { 183752 },                   -- Disrupt                → glow when ready
        -- ["ready:278326"] = { 278326 },                   -- Consume Magic          → glow when ready
        -- ["ready:205604"] = { 205604 },                   -- Reverse Magic          → glow when ready
    },
    EVOKER = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:351338"] = { 351338 },                   -- Quell                  → glow when ready
		-- ["ready:374251"] = { 374251 },                   -- Cauterizing Flame      → glow when ready
		-- ["ready:365585"] = { 365585 },                   -- Expunge                → glow when ready
		-- ["ready:360823"] = { 360823 },                   -- Naturalize             → glow when ready		
		-- ["ready:372048"] = { 372048 },                   -- Oppressing Roar        → glow when ready		
	},
}


local CDMGlow = {
    spellsByAura       = {},
    trackedSpells      = {},
    spellToAura        = {},
    activeAuras        = {},
    overlayProcSpells  = {},
    readySpells        = {},
    baseCost           = {},
    activeGlowFrames   = {},
    frameSpellID       = {}, -- frame -> spellID currently shown there (refreshed every scan)
    lastCDMPresence    = {},
    _pendingUpdate    = false,
    _overlayUpdateGen = 0,
    _playerClass      = nil,
}


-- ---------------------------------------------------------------------------
-- Glow request (delegates to the shared engine in CDM.lua)
-- ---------------------------------------------------------------------------
local function RequestGlow(frame, enabled, auraID, color)
    local overlay = CDM.GetOrCreateOverlay(frame)
    if enabled then
        ns.CXUI_Glow_Start(overlay, color or CDM.glowColor)
    else
        ns.CXUI_Glow_Stop(overlay)
    end
end

-- ---------------------------------------------------------------------------
-- "ready:" spell check + class spell registration
-- ---------------------------------------------------------------------------

local function IsSpellReady(spellID)
    if not C_Spell then return false end
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
    if not info then return false end
    local offCooldown = not info.isActive or info.isOnGCD
    if not offCooldown then return false end
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
    return ok and usable == true
end

-- ---------------------------------------------------------------------------
-- Shared spell registration helper
-- ---------------------------------------------------------------------------

local function RegisterClassSpells(class)
    if not PROC_CONFIG[class] then return end
    for auraID, spells in pairs(PROC_CONFIG[class]) do
        CDMGlow.spellsByAura[auraID] = spells
        for i = 1, #spells do
            CDMGlow.trackedSpells[spells[i]] = true
            if type(auraID) == "number" then
                CDMGlow.spellToAura[spells[i]] = auraID
            end
            if type(auraID) == "string" and auraID:sub(1, 6) == "ready:" then
                local sid = tonumber(auraID:sub(7))
                if sid then CDMGlow.readySpells[sid] = true end
            end
        end
    end
end


-- ---------------------------------------------------------------------------
-- Frame scanning (only frames of tracked spells)
-- ---------------------------------------------------------------------------

local function ScanFrameTree(root, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true

    local ok, ot = pcall(function()
        return root.GetObjectType and root:GetObjectType()
    end)
    if ok and ot and (ot == "Button" or ot == "Frame") then
        local spellID = GetButtonSpellID(root)
        if spellID and CDMGlow.trackedSpells[spellID] then
            results[#results + 1] = { frame = root, spellID = spellID }
        end
    end

    local ok2, children = pcall(function()
        return root.GetChildren and { root:GetChildren() }
    end)
    if ok2 and children then
        for i = 1, #children do
            ScanFrameTree(children[i], results, seen, depth + 1)
        end
    end
end

local function FindCurrentCDMFrames()
    local found = {}
    for auraID in pairs(CDMGlow.spellsByAura) do found[auraID] = {} end

    local results, seen = {}, {}
    for _, name in ipairs(CDM.VIEWER_NAMES) do
        if _G[name] then ScanFrameTree(_G[name], results, seen, 0) end
    end

    local smallest = {}
    for _, entry in ipairs(results) do
        local area = 999999
        pcall(function()
            local w, h = entry.frame:GetSize()
            area = w * h
        end)
        local prev = smallest[entry.spellID]
        if not prev or area < prev.area then
            smallest[entry.spellID] = { frame = entry.frame, area = area }
        end
    end

    local deduped = {}
    for spellID, entry in pairs(smallest) do
        deduped[#deduped + 1] = { frame = entry.frame, spellID = spellID }
    end

    table.wipe(CDMGlow.frameSpellID)
    for _, entry in ipairs(deduped) do
        CDMGlow.frameSpellID[entry.frame] = entry.spellID
        for auraID, spells in pairs(CDMGlow.spellsByAura) do
            for _, sid in ipairs(spells) do
                if sid == entry.spellID then
                    table.insert(found[auraID], entry.frame)
                end
            end
        end
    end

    return found
end


-- ---------------------------------------------------------------------------
-- Glow state management
-- ---------------------------------------------------------------------------

local function ApplyGlowState(auraID, hasAura, currentFrames)
    local newSet = {}
    if currentFrames then
        for _, f in ipairs(currentFrames) do newSet[f] = true end
    end

    local hasNewFrames = currentFrames and #currentFrames > 0

    if hasAura and hasNewFrames then
        for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
            if fAuraID == auraID and not newSet[frame] then
                RequestGlow(frame, false, auraID)
                CDMGlow.activeGlowFrames[frame] = nil
            end
        end
        for _, frame in ipairs(currentFrames) do
            if CDMGlow.activeGlowFrames[frame] ~= auraID then
                RequestGlow(frame, true, auraID)
                CDMGlow.activeGlowFrames[frame] = auraID
            end
        end
    elseif hasAura and not hasNewFrames then
        -- keep existing glows alive during ForceReanchor
    elseif not hasAura then
        for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
            if fAuraID == auraID then
                RequestGlow(frame, false, auraID)
                CDMGlow.activeGlowFrames[frame] = nil
            end
        end
    end
end

function CDMGlow:UpdateGlows()
    if not F:IsOn() then
        for frame in pairs(self.activeGlowFrames) do
            RequestGlow(frame, false, "disabled")
        end
        table.wipe(self.activeGlowFrames)
        return
    end

    local currentFrames = FindCurrentCDMFrames()
    local now = GetTime()

    for auraID in pairs(self.spellsByAura) do
        local hasAura = false

        if type(auraID) == "string" and auraID:sub(1, 4) == "cdm:" then
            local hasFrames = currentFrames[auraID] ~= nil and #currentFrames[auraID] > 0
            if hasFrames then
                self.lastCDMPresence[auraID] = now
                hasAura = true
            elseif self.lastCDMPresence[auraID] then
                local age = now - self.lastCDMPresence[auraID]
                if age < 1.0 then
                    hasAura = true
                else
                    self.lastCDMPresence[auraID] = nil
                end
            end

        elseif type(auraID) == "string" and auraID:sub(1, 8) == "overlay:" then
            hasAura = self.overlayProcSpells[auraID] == true

        elseif type(auraID) == "string" and auraID:sub(1, 6) == "ready:" then
            local sid = tonumber(auraID:sub(7))
            hasAura = sid ~= nil and IsSpellReady(sid)

        else
            if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
                hasAura = (ok and aura ~= nil)
            end
            if not hasAura and self.overlayProcSpells[auraID] then
                hasAura = true
            end
            if not hasAura and self:HasProcViaCost(auraID) then
                hasAura = true
            end
        end

        self.activeAuras[auraID] = hasAura
        ApplyGlowState(auraID, hasAura, currentFrames[auraID])
    end
end

-- Called when the glow-style selector changes so already-active glows switch
-- engine immediately instead of waiting for their next aura state change.
function CDMGlow:RefreshGlowStyle()
    if not F:IsOn() then return end
    for frame, auraID in pairs(self.activeGlowFrames) do
        RequestGlow(frame, true, auraID)
    end
end
CDM.OnStyleChange(function() CDMGlow:RefreshGlowStyle() end)

function CDMGlow:UpdateGlowsAfterRescan()
    self:UpdateGlows()
end

-- ---------------------------------------------------------------------------
-- Runic power cost fallback
-- ---------------------------------------------------------------------------

local function GetSpellRunicCost(spellID)
    local rpType = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        if ok and costs then
            for i = 1, #costs do
                if costs[i].type == rpType then return costs[i].cost or costs[i].minCost end
            end
        end
    end
    return nil
end

function CDMGlow:UpdateBaselineCosts()
    for auraID, spells in pairs(self.spellsByAura) do
        for i = 1, #spells do
            local cost = GetSpellRunicCost(spells[i])
            if cost then self.baseCost[spells[i]] = math.max(self.baseCost[spells[i]] or 0, cost) end
        end
    end
end

function CDMGlow:HasProcViaCost(auraID)
    local spells = self.spellsByAura[auraID]
    if not spells then return false end
    for i = 1, #spells do
        local base    = self.baseCost[spells[i]]
        local current = GetSpellRunicCost(spells[i])
        if base and current and current <= (base - 1) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Rescan scheduler
-- ---------------------------------------------------------------------------

local rescanGen = 0

function CDMGlow:ScheduleRescan(delay)
    rescanGen = rescanGen + 1
    local gen = rescanGen
    F:After(delay or 0.2, function()
        if gen ~= rescanGen then return end
        self:UpdateGlowsAfterRescan()
    end)
end

-- Debounced UpdateGlows (events can fire many times per frame)
local function QueueUpdate(delay)
    if CDMGlow._pendingUpdate then return end
    CDMGlow._pendingUpdate = true
    F:After(delay, function()
        CDMGlow._pendingUpdate = false
        CDMGlow:UpdateGlows()
    end)
end

-- ---------------------------------------------------------------------------
-- Combat safeguard ticker (only while in combat)
-- ---------------------------------------------------------------------------

local safeguardTicker = nil

function CDMGlow:StartSafeguardTicker()
    if safeguardTicker then return end
    safeguardTicker = F:NewTicker(10, function()
        table.wipe(CDMGlow.lastCDMPresence)
        CDMGlow:ScheduleRescan(0.1)
    end)
end

function CDMGlow:StopSafeguardTicker()
    if safeguardTicker then safeguardTicker:Cancel(); safeguardTicker = nil end
end

-- ---------------------------------------------------------------------------
-- Full state reset (spec/hero-tree change, or feature turned off)
-- ---------------------------------------------------------------------------

local function FullReset()
    for frame in pairs(CDMGlow.activeGlowFrames) do
        RequestGlow(frame, false, "reset")
    end
    table.wipe(CDMGlow.activeGlowFrames)
    table.wipe(CDMGlow.frameSpellID)
    table.wipe(CDMGlow.spellsByAura)
    table.wipe(CDMGlow.trackedSpells)
    table.wipe(CDMGlow.spellToAura)
    table.wipe(CDMGlow.activeAuras)
    table.wipe(CDMGlow.overlayProcSpells)
    table.wipe(CDMGlow.readySpells)
    table.wipe(CDMGlow.baseCost)
    table.wipe(CDMGlow.lastCDMPresence)
    CDMGlow._pendingUpdate = false
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local ev

-- Cooldown/usable events are very chatty; only listen while a "ready:" spell is tracked.
local function SyncCooldownEvents()
    if next(CDMGlow.readySpells) then
        ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        ev:RegisterEvent("SPELL_UPDATE_USABLE")
    else
        ev:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        ev:UnregisterEvent("SPELL_UPDATE_USABLE")
    end
end

local function ReloadSpells()
    FullReset()
    F:After(0.5, function()
        local _, class = UnitClass("player")
        CDMGlow._playerClass = class
        RegisterClassSpells(class)
        SyncCooldownEvents()
        CDMGlow:UpdateBaselineCosts()
        CDMGlow:UpdateGlows()
    end)
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        ReloadSpells() -- spec, or hero tree within the same spec

    elseif event == "PLAYER_REGEN_DISABLED" then
        CDMGlow:StartSafeguardTicker()

    elseif event == "PLAYER_REGEN_ENABLED" then
        CDMGlow:StopSafeguardTicker()
        table.wipe(CDMGlow.lastCDMPresence)
        CDMGlow:ScheduleRescan(0.3)

    elseif event == "PLAYER_ENTERING_WORLD" then
        F:After(1.0, function() CDMGlow:UpdateGlows() end)

    elseif event == "UNIT_PET" then
        CDMGlow:ScheduleRescan(0.2)

    elseif event == "UNIT_AURA" then
        QueueUpdate(0.1)

    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        QueueUpdate(0.1)

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local sid = ...
        local overlayKey = "overlay:" .. sid
        if CDMGlow.spellsByAura[overlayKey] then
            CDMGlow.overlayProcSpells[overlayKey] = true
            CDMGlow:UpdateGlows()
        else
            local auraID = CDMGlow.spellToAura[sid]
            if auraID then
                CDMGlow.overlayProcSpells[auraID] = true
                CDMGlow._overlayUpdateGen = CDMGlow._overlayUpdateGen + 1
                local gen = CDMGlow._overlayUpdateGen
                F:After(0.15, function()
                    if gen ~= CDMGlow._overlayUpdateGen then return end
                    CDMGlow:UpdateGlows()
                end)
            end
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        local overlayKey = "overlay:" .. sid
        if CDMGlow.spellsByAura[overlayKey] then
            CDMGlow.overlayProcSpells[overlayKey] = nil
            CDMGlow:UpdateGlows()
        else
            local auraID = CDMGlow.spellToAura[sid]
            if auraID and CDMGlow.overlayProcSpells[auraID] then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
                if ok and aura ~= nil then
                    if not CDMGlow._pendingUpdate then
                        CDMGlow._pendingUpdate = true
                        F:After(0.1, function()
                            CDMGlow._pendingUpdate = false
                            for aID in pairs(CDMGlow.overlayProcSpells) do
                                local ok2, aura2 = pcall(C_UnitAuras.GetPlayerAuraBySpellID, aID)
                                if ok2 and aura2 == nil then
                                    CDMGlow.overlayProcSpells[aID] = nil
                                end
                            end
                            CDMGlow:UpdateGlows()
                        end)
                    end
                else
                    CDMGlow.overlayProcSpells[auraID] = nil
                    CDMGlow:UpdateGlows()
                end
            end
        end
    end
end

function F:OnEnable()
    local _, class = UnitClass("player")
    CDMGlow._playerClass = class
    RegisterClassSpells(class)

    ev = self:NewEventFrame()
    ev:SetScript("OnEvent", OnEvent)
    ev:RegisterUnitEvent("UNIT_AURA", "player")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_TALENT_UPDATE")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("UNIT_PET")
    SyncCooldownEvents()

    CDM.AddReanchorListener("cdmGlow", function() CDMGlow:ScheduleRescan(0.2) end)

    if InCombatLockdown() then CDMGlow:StartSafeguardTicker() end

    self:After(1.5, function()
        CDMGlow:UpdateBaselineCosts()
        CDMGlow:UpdateGlows()
    end)
end

function F:OnDisable()
    CDM.RemoveReanchorListener("cdmGlow")
    rescanGen = rescanGen + 1
    safeguardTicker = nil -- already cancelled by F:Silence()
    FullReset()           -- removes every glow this feature created
end

-- ---------------------------------------------------------------------------
-- Slash subcommands (/cdmglow debug | diag)
-- ---------------------------------------------------------------------------

CDM.slash.debug = function()
        local count = 0
        for _, name in ipairs(CDM.VIEWER_NAMES) do
            local viewer = _G[name]
            if viewer and viewer.GetChildren then
                local ok, children = pcall(function() return { viewer:GetChildren() } end)
                if ok and children then
                    for _, child in ipairs(children) do
                        if IsSafeFrame(child) then
                            local sid = GetButtonSpellID(child)
                            if sid then
                                count = count + 1
                                local fw, fh = child:GetSize()
                                local alert = child.SpellActivationAlert
                                local aw, ah = alert and alert:GetSize()
                                print(string.format(
                                    "|cff0070ddcxUI:|r [%d] spell=%-8s  frame=%dx%d  alert=%s",
                                    count, tostring(sid),
                                    math.floor(fw or 0), math.floor(fh or 0),
                                    alert and string.format("%dx%d", math.floor(aw or 0), math.floor(ah or 0)) or "none"
                                ))
                            end
                        end
                    end
                end
            end
        end
        if count == 0 then print("|cff0070ddcxUI:|r no CDM frames found") end
end

CDM.slash.diag = function()
        local AddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        print("|cff0070ddcxUI:|r === glow diag ===")
        print(("|cff0070ddcxUI:|r EllesmereUI loaded=%s  ElvUI global=%s  EllesmereUI global=%s"):format(
            tostring(AddOnLoaded and AddOnLoaded("EllesmereUI")),
            tostring(_G.ElvUI ~= nil),
            tostring(_G.EllesmereUI ~= nil)
        ))

        local function DumpChain(f, label)
            print(("|cff0070ddcxUI:|r -- %s --"):format(label))
            local n, depth = f, 0
            while n and depth < 12 do
                local ok, name = pcall(function() return n.GetName and n:GetName() end)
                if not ok then name = nil end
                local w, h = 0, 0
                pcall(function() w, h = n:GetSize() end)
                local scale, es = 1, 1
                pcall(function() scale = n:GetScale() end)
                pcall(function() es = n:GetEffectiveScale() end)
                local strata, level = "?", "?"
                pcall(function() strata = n:GetFrameStrata() end)
                pcall(function() level = n:GetFrameLevel() end)
                print(("  [%d] %-28s size=%s x %s  scale=%.4f  effScale=%.4f  strata=%s  level=%s"):format(
                    depth, tostring(name or "<anon>"),
                    tostring(w and string.format("%.1f", w)), tostring(h and string.format("%.1f", h)),
                    scale or 1, es or 1, tostring(strata), tostring(level)
                ))
                -- Anchor point detail for the first 2 levels only (target
                -- frame + its direct parent) — this tells us whether
                -- SetAllPoints actually took effect, and if not, what points
                -- (if any) the frame actually has instead.
                if depth <= 1 then
                    local ok3, numPoints = pcall(function() return n:GetNumPoints() end)
                    if ok3 and numPoints then
                        print(("      numPoints=%d"):format(numPoints))
                        for i = 1, numPoints do
                            local ok4, point, relTo, relPoint, x, y = pcall(function() return n:GetPoint(i) end)
                            if ok4 then
                                local relName = "?"
                                pcall(function() relName = (relTo and relTo.GetName and relTo:GetName()) or (relTo and tostring(relTo)) or "nil" end)
                                print(("        [%d] point=%s relativeTo=%s relativePoint=%s x=%s y=%s"):format(
                                    i, tostring(point), tostring(relName), tostring(relPoint), tostring(x), tostring(y)))
                            end
                        end
                    else
                        print("      (GetNumPoints failed or unavailable)")
                    end
                end
                local ok2, p = pcall(function() return n:GetParent() end)
                n = ok2 and p or nil
                depth = depth + 1
            end
        end

        local function DumpIconTexture(icon)
            local tex = icon.icon or icon.Icon or (icon.GetNormalTexture and icon:GetNormalTexture())
            if not tex then print("  (no icon texture found: tried icon.icon / icon.Icon / GetNormalTexture)"); return end
            local desat, alpha, blend = "?", "?", "?"
            pcall(function() desat = tex:IsDesaturated() end)
            pcall(function() alpha = tex:GetAlpha() end)
            pcall(function() blend = tex:GetBlendMode() end)
            local r, g, b, a = 1, 1, 1, 1
            pcall(function() r, g, b, a = tex:GetVertexColor() end)
            print(("  icon texture: desaturated=%s alpha=%s blend=%s vertexColor=%.2f,%.2f,%.2f,%.2f"):format(
                tostring(desat), tostring(alpha), tostring(blend), r, g, b, a))
        end

        local count = 0
        for frame, sid in pairs(CDMGlow.frameSpellID) do
            if IsSafeFrame(frame) then
                count = count + 1
                DumpChain(frame, ("production-selected icon spell=%s"):format(tostring(sid)))
                DumpIconTexture(frame)
                local overlay = CDM.overlays[frame]
                if overlay then
                    DumpChain(overlay, "our overlay child")
                    if overlay._CXUI_PixelGlow then
                        local pf = overlay._CXUI_PixelGlow
                        DumpChain(pf, "our pixel glow frame")
                        print(("   shown=%s alpha=%.2f"):format(tostring(pf:IsShown()), pf:GetAlpha()))
                    end
                    if overlay._CXUI_CDMGlow then
                        local cf = overlay._CXUI_CDMGlow
                        DumpChain(cf, "our proc glow frame")
                        print(("   shown=%s alpha=%.2f"):format(tostring(cf:IsShown()), cf:GetAlpha()))
                    end
                else
                    print("  (no cxUI overlay created yet for this icon)")
                end
                if count >= 4 then break end
            end
        end
        if count == 0 then print("|cff0070ddcxUI:|r no CDM frames found for diag (CDMGlow.frameSpellID empty — UpdateGlows hasn't run or found nothing)") end

        print("|cff0070ddcxUI:|r -- CDM.overlays cache (every icon that ever got a glow) --")
        local n = 0
        for iconFrame, overlay in pairs(CDM.overlays) do
            n = n + 1
            local sid = GetButtonSpellID(iconFrame)
            DumpChain(iconFrame, ("cached icon #%d spell=%s"):format(n, tostring(sid)))
            DumpIconTexture(iconFrame)
            DumpChain(overlay, "  -> overlay")
            if overlay._CXUI_PixelGlow then
                local pf = overlay._CXUI_PixelGlow
                DumpChain(pf, "  -> pixel glow frame")
                print(("     shown=%s alpha=%.2f"):format(tostring(pf:IsShown()), pf:GetAlpha()))
            end
            if overlay._CXUI_CDMGlow then
                local cf = overlay._CXUI_CDMGlow
                DumpChain(cf, "  -> proc glow frame")
                print(("     shown=%s alpha=%.2f"):format(tostring(cf:IsShown()), cf:GetAlpha()))
            end
        end
        if n == 0 then print("  (CDM.overlays cache is empty — no glow has ever been requested on a real icon this session)") end
        print("|cff0070ddcxUI:|r === end diag ===")
end
