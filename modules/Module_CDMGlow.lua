local addonName, ns = ...

-- ===========================================================================
-- MODULE: CDM GLOW LOGIC
-- ===========================================================================

CDMProcGlowDB = CDMProcGlowDB or { enabled = true }
local DB = CDMProcGlowDB

local PROC_CONFIG = {
    DEATHKNIGHT = {
        [81340] = { 47541, 207317, 1242174, 383269 }	-- Sudden Doom        → Death Coil, Epidemic, Necrotic Coil, Graveyard
    },
    MAGE = {
        [44544]   = { 30455 },          				-- Fingers of Frost   → Ice Lance
        [1247729] = { 30455 },          				-- Thermal Void       → Ice Lance
        [1222865] = { 199786 },         				-- Glacial Spike!     → Glacial Spike
    },
    WARLOCK = {
        [264173]  = { 264178 },         				-- Demonic Core       → Demonbolt
    },
    WARRIOR = {}, PALADIN = {}, HUNTER = {}, ROGUE = {}, PRIEST = {},
    SHAMAN = {}, MONK = {}, DRUID = {}, DEMONHUNTER = {}, EVOKER = {},
}

local CDMGlow = {
    spellsByAura      = {},
    trackedSpells     = {},
    spellToAura       = {},
    activeAuras       = {},
    overlayProcSpells = {},
    baseCost          = {},
    -- frames currently glowing, keyed by frame object → auraID
    activeGlowFrames  = {},
    _pendingUpdate    = false,
    _reanchorHooked   = false,
}

-- ---------------------------------------------------------------------------
-- CDM Glow API access
-- ---------------------------------------------------------------------------

local function GetCDMGlowAPI()
    local cdm = _G["Ayije_CDM"]
    if cdm and cdm.Glow and cdm.Glow.RequestBuffGlow then
        return cdm.Glow
    end
    return nil
end

local function RequestGlow(frame, enabled)
    local api = GetCDMGlowAPI()
    if not api then return end
    -- RequestBuffGlow(frame, enabled, overrideColor, sourceID)
    api:RequestBuffGlow(frame, enabled, nil, nil)
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

    for _, entry in ipairs(results) do
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

-- Apply or remove glow on all frames for a given auraID based on hasAura.
-- Also transitions cleanly when CDM has reassigned frames (Army of the Dead,
-- Festering Strike, pet summons): hides glow on old frames, shows on new ones.
local function ApplyGlowState(auraID, hasAura, currentFrames)
    local newSet = {}
    if currentFrames then
        for _, f in ipairs(currentFrames) do newSet[f] = true end
    end

    -- Hide glow on any frame that is no longer showing this spell.
    for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
        if fAuraID == auraID and not newSet[frame] then
            RequestGlow(frame, false)
            CDMGlow.activeGlowFrames[frame] = nil
        end
    end

    if hasAura and currentFrames then
        for _, frame in ipairs(currentFrames) do
            RequestGlow(frame, true)
            CDMGlow.activeGlowFrames[frame] = auraID
        end
    elseif not hasAura then
        -- Proc ended — hide glow on all remaining frames for this aura.
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

        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
            hasAura = (ok and aura ~= nil)
        end

        hasAura = hasAura or self.overlayProcSpells[auraID] or self:HasProcViaCost(auraID)
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
            -- Army of the Dead calls this repeatedly; ScheduleRescan debounces.
            CDMGlow:ScheduleRescan(0.2)
        end)
        self._reanchorHooked = true
    end

    -- Hook ShowAlert to suppress untracked proc glows when the option is enabled.
    -- CDM's own hook on ShowAlert runs first (hooksecurefunc is FIFO), so by the
    -- time our hook runs, CDM has already shown its custom glow. We then hide it
    -- for any spell that is not in our trackedSpells list.
    local alertMgr = _G.ActionButtonSpellAlertManager
    if alertMgr and alertMgr.ShowAlert then
        hooksecurefunc(alertMgr, "ShowAlert", function(_, frame)
            if not CXUI_DB.cdmGlowSuppressUntracked then return end
            if not IsSafeFrame(frame) then return end

            local spellID = GetButtonSpellID(frame)
            if spellID and CDMGlow.trackedSpells[spellID] then
                -- Tracked spell — our module handles it, leave it alone.
                return
            end

            -- Untracked spell — hide both Blizzard and CDM glows.
            local alert = frame.SpellActivationAlert
            if alert then alert:SetAlpha(0); alert:Hide() end

            if cdm and cdm.Glow then
                cdm.Glow:StopGlow(frame)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

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
                CDMGlow.spellToAura[spells[i]] = auraID
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
        -- This event sends a spell ID (e.g. 47541), not an aura ID (e.g. 81340).
        local auraID = CDMGlow.spellToAura[sid]
        if auraID then
            CDMGlow.overlayProcSpells[auraID] = true
            CDMGlow:UpdateGlows()
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        local auraID = CDMGlow.spellToAura[sid]
        if auraID and CDMGlow.overlayProcSpells[auraID] then
            CDMGlow.overlayProcSpells[auraID] = nil
            CDMGlow:UpdateGlows()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_CDMGLOW1 = "/cdmglow"
SlashCmdList["CDMGLOW"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "on" then
        DB.enabled = true
        CDMGlow:UpdateGlows()
        print("|cff0070ddcxUI:|r CDM Glow enabled")
    elseif cmd == "off" then
        DB.enabled = false
        CDMGlow:UpdateGlows()
        print("|cff0070ddcxUI:|r CDM Glow disabled")
    elseif cmd == "refresh" then
        CDMGlow:UpdateGlows()
        print("|cff0070ddcxUI:|r CDM Glow refreshed")
    else
        print("|cff0070ddcxUI CDM Glow:|r /cdmglow [on|off|refresh]")
    end
end