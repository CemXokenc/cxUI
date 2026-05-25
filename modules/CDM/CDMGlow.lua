local addonName, ns = ...

-- ===========================================================================
-- MODULE: CDM GLOW LOGIC
-- ===========================================================================

CDMProcGlowDB = CDMProcGlowDB or { enabled = true }
local DB = CDMProcGlowDB

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local GLOW_COLOR = { 1, 0.82, 0, 0.9 }

local PROC_CONFIG = {
    DEATHKNIGHT = {
        [81340] = { 47541, 207317, 1242174, 383269 },	-- Sudden Doom        		→ Death Coil, Epidemic, Necrotic Coil, Graveyard
		[51124] = { 49020, 207230 }, 					-- Killing Machine			→ Obliterate, Frostscythe		
		[59052] = { 49184 }, --but this not trackeble   -- Rime                     → Howling Blast									
		["cdm:1228433"] = {1228433}, 					-- Frostbane				→ always glow if present in CDM
    },
    MAGE = {
        [44544]   = { 30455 },          				-- Fingers of Frost   		→ Ice Lance
        --[1247729] = { 30455 },          				-- Thermal Void       		→ Ice Lance        
        [190446]  = { 44614 },         					-- Brain Freeze     	  	→ Flurry
        [270232]  = { 190356 },        					-- Freezeng Rain    	  	→ Blizzard
		["cdm:199786"] = {199786},						-- Glacial Spike     		→ always glow if present in CDM
    },
    WARLOCK = {
        [264173]  = { 264178 },         				-- Demonic Core       		→ Demonbolt        
		["cdm:434635"] = {434635},						-- Ruination    	  		→ always glow if present in CDM
		["cdm:434506"] = {434506},						-- Infernal Bolt      		→ always glow if present in CDM
		["cdm:1276452"] = {1276452},					-- Grimoire: Imp Lord 		→ always glow if present in CDM
		["cdm:1276467"] = {1276467},					-- Grimoire: Fel Ravager	→ always glow if present in CDM
    },
    WARRIOR = {}, PALADIN = {}, HUNTER = {}, ROGUE = {}, 
	PRIEST = {
		--["cdm:450405"] = {450405},					-- Void Blast	      	   	→ always glow if present in CDM
		--["cdm:1242173"] = {1242173},					-- Void Volley   	 		→ always glow if present in CDM
		--["cdm:263165"] = {263165},					-- Void Torrent   	 		→ always glow if present in CDM
		--["cdm:228260"] = {228260},					-- Voidform		   	 		→ always glow if present in CDM
	},
    SHAMAN = {}, 
	MONK = {
		[438443]  = { 101546 },         				-- Dance of Chi-Ji     		→ Spinning Crane Kick
		[443112]  = { 124682 },         				-- Strength of the Black Ox → Enveloping Mist        
		--[392883]  = { 399491 },         				-- Vivacious Vivification   → Sheilun's Gift        
	}, DRUID = {},
	DEMONHUNTER = {
		--[1256302]  = { 1226019, 1225826, 1245453 },	-- Voidfall       			→ Reap, Eradicate, Cull		
		["cdm:1221150"] = { 1221150 },					-- Collapsing Star    		→ always glow if present in CDM
	},
	EVOKER = {},
}

local CDMGlow = {
    spellsByAura          = {},
    trackedSpells         = {},
    spellToAura           = {},
    activeAuras           = {},
    overlayProcSpells     = {},
    baseCost              = {},
    activeGlowFrames      = {},
    _pendingUpdate        = false,
    _overlayUpdateGen     = 0,      -- generation counter replacing _pendingOverlayUpdate boolean
    _reanchorHooked       = false,
}

-- ---------------------------------------------------------------------------
-- CDM Glow API access
-- ---------------------------------------------------------------------------

local cdmOverlays = {}

local function GetOrCreateCDMOverlay(frame)
    if cdmOverlays[frame] then return cdmOverlays[frame] end
    local ov = CreateFrame("Frame", nil, frame)
    ov:SetAllPoints(frame)
    ov:SetFrameStrata("TOOLTIP")
    ov:SetFrameLevel(frame:GetFrameLevel() + 10)
    cdmOverlays[frame] = ov
    return ov
end

local function RequestGlow(frame, enabled)
    if not LCG then return end
    local overlay = GetOrCreateCDMOverlay(frame)
    if enabled then
        LCG.ProcGlow_Start(overlay, { color = GLOW_COLOR, startAnim = false })
    else
        LCG.ProcGlow_Stop(overlay)
    end
end

-- ---------------------------------------------------------------------------
-- Frame scanning — find CDM frames that currently display a tracked spell
-- ---------------------------------------------------------------------------

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function IsSafeFrame(frame)
    if not frame then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

local function GetButtonSpellID(frame)
    if not IsSafeFrame(frame) then return nil end
    local sid = frame.spellID or frame.spellId or frame.spellid
    if type(sid) == "number" and not IsSecret(sid) then return sid end
    if frame.GetSpellID then
        local ok, v = pcall(frame.GetSpellID, frame)
        if ok and type(v) == "number" and not IsSecret(v) then return v end
    end
    return nil
end

local function ScanFrameTree(root, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true

    if root.GetObjectType then
        local ok, ot = pcall(root.GetObjectType, root)
        if ok and (ot == "Button" or ot == "Frame") then
            local spellID = GetButtonSpellID(root)
            if spellID and CDMGlow.trackedSpells[spellID] then
                results[#results + 1] = { frame = root, spellID = spellID }
            end
        end
    end

    if root.GetChildren then
        local ok, children = pcall(function() return { root:GetChildren() } end)
        if ok and children then
            for i = 1, #children do
                ScanFrameTree(children[i], results, seen, depth + 1)
            end
        end
    end
end

local CDM_VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
    "BlizzardCooldownFrame",
}

-- Returns { [auraID] = { frame, frame, ... }, ... } for all currently visible
-- CDM frames that match a tracked spell.
local function FindCurrentCDMFrames()
    local found = {}
    for auraID in pairs(CDMGlow.spellsByAura) do found[auraID] = {} end

    local results, seen = {}, {}
    for _, name in ipairs(CDM_VIEWER_NAMES) do
        if _G[name] then ScanFrameTree(_G[name], results, seen, 0) end
    end

    -- Each CDM spell may appear on both a parent Frame and child Button.
    -- Keep only the smallest frame per spellID to avoid double-glowing.
    local smallest = {}  -- [spellID] = { frame, area }
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

    for _, entry in ipairs(deduped) do
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
        -- New frames found — transition: hide glow on old frames, show on new ones.
        for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
            if fAuraID == auraID and not newSet[frame] then
                RequestGlow(frame, false)
                CDMGlow.activeGlowFrames[frame] = nil
            end
        end
        for _, frame in ipairs(currentFrames) do
            RequestGlow(frame, true)
            CDMGlow.activeGlowFrames[frame] = auraID
        end
    elseif hasAura and not hasNewFrames then
        -- Proc is active but CDM has no frames right now (ForceReanchor in progress).
        -- Keep existing glows alive — ScheduleRescan will find the new frames shortly.
    elseif not hasAura then
        -- Proc ended — hide glow on all frames for this aura.
        for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
            if fAuraID == auraID then
                RequestGlow(frame, false)
                CDMGlow.activeGlowFrames[frame] = nil
            end
        end
    end
end

function CDMGlow:UpdateGlows()
    if not CXUI_DB.cdmGlow or not DB.enabled then
        for frame in pairs(self.activeGlowFrames) do
            RequestGlow(frame, false)
        end
        table.wipe(self.activeGlowFrames)
        return
    end

    -- Scan CDM frame tree once per update cycle.
    local currentFrames = FindCurrentCDMFrames()

    for auraID in pairs(self.spellsByAura) do
        local hasAura = false

        if type(auraID) == "string" and auraID:sub(1, 4) == "cdm:" then
            -- CDM-presence sentinel: glow whenever the spell is visible in CDM,
            -- regardless of any player buff. Used for spells like Collapsing Star
            -- that CDM shows automatically based on its own internal logic.
            hasAura = currentFrames[auraID] ~= nil and #currentFrames[auraID] > 0
        else
            if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
                hasAura = (ok and aura ~= nil)
            end
            hasAura = hasAura or self.overlayProcSpells[auraID] or self:HasProcViaCost(auraID)
        end

        self.activeAuras[auraID] = hasAura
        ApplyGlowState(auraID, hasAura, currentFrames[auraID])
    end
end

-- ---------------------------------------------------------------------------
-- Runic power cost fallback (secondary proc detection)
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
-- Rescan scheduler — generation counter so only the LAST call in a burst runs.
-- Army of the Dead fires ForceReanchor many times; earlier callbacks are skipped.
-- ---------------------------------------------------------------------------

local rescanGen = 0

function CDMGlow:ScheduleRescan(delay)
    rescanGen = rescanGen + 1
    local gen = rescanGen
    C_Timer.After(delay or 0.2, function()
        if gen ~= rescanGen then return end
        self:UpdateGlows()
    end)
end

-- ---------------------------------------------------------------------------
-- Hook CDM's ForceReanchor so we update glows after every frame rebuild
-- ---------------------------------------------------------------------------

function CDMGlow:HookCDM()
    if self._reanchorHooked then return end

    local cdm = _G["Ayije_CDM"]
    if cdm and cdm.ForceReanchor then
        hooksecurefunc(cdm, "ForceReanchor", function()
            CDMGlow:ScheduleRescan(0.2)
        end)
        self._reanchorHooked = true
    end

    local alertMgr = _G.ActionButtonSpellAlertManager
    if alertMgr and alertMgr.ShowAlert then
        hooksecurefunc(alertMgr, "ShowAlert", function(_, frame)
            if not CXUI_DB.cdmGlowSuppressUntracked then return end
            if not IsSafeFrame(frame) then return end

            local spellID = GetButtonSpellID(frame)
            local isTracked = spellID and CDMGlow.trackedSpells[spellID]

            if cdm and cdm.Glow and cdm.Glow.buffHookedFrames then
                for _, hookedFrame in pairs(cdm.Glow.buffHookedFrames) do
                    if hookedFrame == frame then return end
                end
            end

            -- Always suppress Blizzard's SpellActivationAlert.
            local alert = frame.SpellActivationAlert
            if alert then alert:SetAlpha(0); alert:Hide() end

            -- For untracked spells only: also stop CDM's glow.
            -- For tracked spells our LCG overlay handles the glow — don't interfere.
            if not isTracked and cdm and cdm.Glow and spellID then
                for glowFrame, auraID in pairs(CDMGlow.activeGlowFrames) do
                    local spells = CDMGlow.spellsByAura[auraID]
                    if spells then
                        for _, sid in ipairs(spells) do
                            if sid == spellID then
                                RequestGlow(glowFrame, false)
                                CDMGlow.activeGlowFrames[glowFrame] = nil
                                break
                            end
                        end
                    end
                end
                for _, name in ipairs(CDM_VIEWER_NAMES) do
                    local viewer = _G[name]
                    if viewer and viewer.GetChildren then
                        local ok, children = pcall(function() return { viewer:GetChildren() } end)
                        if ok and children then
                            for _, child in ipairs(children) do
                                if IsSafeFrame(child) and GetButtonSpellID(child) == spellID then
                                    pcall(cdm.Glow.StopGlow, cdm.Glow, child)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

SLASH_CDMGLOWDEBUG1 = "/cdmglow"
SlashCmdList["CDMGLOWDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "debug" then
        local count = 0
        for _, name in ipairs(CDM_VIEWER_NAMES) do
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
    else
        print("|cff0070ddcxUI:|r /cdmglow debug — print CDM frame and SpellActivationAlert sizes")
    end
end

local procEventFrame = CreateFrame("Frame")
procEventFrame:RegisterEvent("PLAYER_LOGIN")
procEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        if not PROC_CONFIG[class] then return end

        for auraID, spells in pairs(PROC_CONFIG[class]) do
            CDMGlow.spellsByAura[auraID] = spells
            for i = 1, #spells do
                CDMGlow.trackedSpells[spells[i]] = true
                -- String keys like "cdm:1221150" are CDM-presence sentinels,
                -- not real aura IDs — skip reverse aura mapping for them.
                if type(auraID) == "number" then
                    CDMGlow.spellToAura[spells[i]] = auraID
                end
            end
        end

        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_PET")

        C_Timer.After(1.5, function()
            CDMGlow:HookCDM()
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            CDMGlow:HookCDM()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "UNIT_PET" then
        -- Pet summons (Army of the Dead ghouls) trigger CDM frame rebuilds.
        CDMGlow:ScheduleRescan(0.2)

    elseif event == "UNIT_AURA" and (...) == "player" then
        -- Debounce: UNIT_AURA fires before WoW finishes updating aura data.
        if not CDMGlow._pendingUpdate then
            CDMGlow._pendingUpdate = true
            C_Timer.After(0.1, function()
                CDMGlow._pendingUpdate = false
                CDMGlow:UpdateGlows()
            end)
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local sid = ...
        local auraID = CDMGlow.spellToAura[sid]
        if auraID then
            CDMGlow.overlayProcSpells[auraID] = true
            -- Generation counter debounce: unlike a boolean flag, each new GLOW_SHOW
            -- increments the counter and schedules its own callback. Only the latest
            -- callback runs — earlier ones see a stale generation and skip.
            -- This fixes the pull-start issue where multiple procs firing within
            -- 0.15s caused the boolean to block all but the first GLOW_SHOW.
            CDMGlow._overlayUpdateGen = CDMGlow._overlayUpdateGen + 1
            local gen = CDMGlow._overlayUpdateGen
            C_Timer.After(0.15, function()
                if gen ~= CDMGlow._overlayUpdateGen then return end
                CDMGlow:UpdateGlows()
            end)
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        local auraID = CDMGlow.spellToAura[sid]
        if auraID and CDMGlow.overlayProcSpells[auraID] then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
            if ok and aura ~= nil then
                -- Aura still exists — this is a stack consumption (e.g. Fingers of
                -- Frost, Demonic Core). Debounce so we don't flicker between stacks.
                if not CDMGlow._pendingUpdate then
                    CDMGlow._pendingUpdate = true
                    C_Timer.After(0.1, function()
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
                -- Aura is completely gone — hide immediately, no debounce needed.
                CDMGlow.overlayProcSpells[auraID] = nil
                CDMGlow:UpdateGlows()
            end
        end
    end
end)