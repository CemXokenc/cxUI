local addonName, ns = ...

-- ===========================================================================
-- MODULE: CDM GLOW LOGIC
-- ===========================================================================

CDMProcGlowDB = CDMProcGlowDB or { enabled = true }
local DB = CDMProcGlowDB

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
-- nil = no color tint applied = renders Blizzard's native gold/yellow proc glow
local GLOW_COLOR = nil

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
        [81340] = { 47541, 207317, 1242174, 383269 },    -- Sudden Doom            → Death Coil, Epidemic, Necrotic Coil, Graveyard
        --[51124] = { 49020, 207230 },                     -- Killing Machine        → Obliterate, Frostscythe
        --["overlay:49184"] = { 49184 },                   -- Rime                   → Howling Blast
        ["cdm:1228433"]   = { 1228433 },                 -- Frostbane              → always glow if present in CDM
        -- CDs
        --["ready:42650"]   = { 42650 },                   -- Army of the Dead       → glow when ready
        --["ready:1249658"] = { 1249658 },                 -- Breath of Sindragosa   → glow when ready
        -- Utility
        ["ready:47528"] = { 47528 },                     -- Mind Freeze            → glow when ready
        ["ready:49576"] = { 49576 },                     -- Death Grip             → glow when ready
    },
    MAGE = {
        -- Procs
        --[44544]  = { 30455 },                            -- Fingers of Frost       → Ice Lance
        --[190446] = { 44614 },                            -- Brain Freeze           → Flurry
        --[270232] = { 190356 },                           -- Freezing Rain          → Blizzard
        --["cdm:199786"] = { 199786 },                     -- Glacial Spike          → always glow if present in CDM
        -- CDs
        --["ready:84714"] = { 84714 },                     -- Frozen Orb             → glow when ready
        -- Utility
        ["ready:2139"] = { 2139 },                       -- Counterspell           → glow when ready
        ["ready:475"]  = { 475 },                        -- Remove Curse           → glow when ready
    },
    WARLOCK = {
        -- Procs
        --[264173] = { 264178 },                           -- Demonic Core           → Demonbolt
        --["cdm:434635"]  = { 434635 },                    -- Ruination              → always glow if present in CDM
        --["cdm:434506"]  = { 434506 },                    -- Infernal Bolt          → always glow if present in CDM
        -- CDs
        ["ready:105174"] = { 105174 },                   -- Hand of Gul'dan        → glow when ready
        --["ready:104316"] = { 104316 },                   -- Call Dreadstalkers     → glow when ready
        --["ready:265187"] = { 265187 },                   -- Summon Demonic Tyrant  → glow when ready
        ["cdm:1276452"]  = { 1276452 },                  -- Grimoire: Imp Lord     → always glow if present in CDM
        ["cdm:1276467"]  = { 1276467 },                  -- Grimoire: Fel Ravager  → always glow if present in CDM
        -- Utility
        ["ready:119914"] = { 119914 },                   -- Axe Toss              → glow when ready
        ["ready:119910"] = { 119910 },                   -- Spell Lock             → glow when ready
    },
    WARRIOR = {}, PALADIN = {}, HUNTER = {}, ROGUE = {},
    PRIEST = {
        -- Procs
        --[375981] = { 8092, 450983 },                     -- Shadowy Insight        → Mind Blast, Void Blast
        --[373204] = { 335467 },                           -- Mind Devourer          → Shadow Word: Madness
        -- CDs
        --["ready:228260"]  = { 228260 },                  -- Voidform               → glow when ready
        --["ready:1242173"] = { 1242173 },                 -- Void Volley            → glow when ready
        --["ready:120644"]  = { 120644 },                  -- Halo                   → glow when ready
        --["ready:120517"]  = { 120517 },                  -- Halo (Holy)            → glow when ready
        --["ready:263165"]  = { 263165 },                  -- Void Torrent           → glow when ready
        ["ready:450983"]  = { 450983 },                  -- Void Blast             → glow when ready
        -- Utility
        ["ready:15487"]  = { 15487 },                    -- Silence                → glow when ready
        ["ready:213634"] = { 213634 },                   -- Purify Disease         → glow when ready
        ["ready:528"]    = { 528 },                      -- Dispel Magic           → glow when ready
        ["ready:527"]    = { 527 },                      -- Purify                 → glow when ready
    },
    SHAMAN = {},
    MONK = {
        -- Procs
        --[438443] = { 101546 },                           -- Dance of Chi-Ji            → Spinning Crane Kick
        --[443112] = { 124682 },                           -- Strength of the Black Ox  → Enveloping Mist
    },
    DRUID = {},
    DEMONHUNTER = {
        -- Procs
        --["cdm:1225826"] = { 1225826 },                   -- Eradicate              → always glow if present in CDM
        --["cdm:1221150"] = { 1221150 },                   -- Collapsing Star        → always glow if present in CDM
        -- CDs
        --["ready:1217605"] = { 1217605 },                 -- Void Metamorphosis     → glow when ready
        --["ready:191427"]  = { 191427 },                  -- Metamorphosis          → glow when ready
        ["ready:473728"]  = { 473728 },                  -- Void Ray               → glow when ready
        -- Utility
        ["ready:183752"] = { 183752 },                   -- Disrupt                → glow when ready
        ["ready:278326"] = { 278326 },                   -- Consume Magic          → glow when ready
    },
    EVOKER = {},
}

-- ---------------------------------------------------------------------------
-- Classes that are exempt from Blizzard SpellActivationAlert suppression
-- (their native overlay always shows regardless of cdmGlowSuppressUntracked)
-- ---------------------------------------------------------------------------
local SUPPRESS_EXEMPT_CLASSES = {
    MAGE = true,
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
    _reanchorHooked   = false,
    _playerClass      = nil,
}

-- ---------------------------------------------------------------------------
-- LCG overlay helpers
-- ---------------------------------------------------------------------------

local cdmOverlays = {}

local function GetOrCreateCDMOverlay(frame)
    if cdmOverlays[frame] then return cdmOverlays[frame] end
    local ov = CreateFrame("Frame", nil, frame)
    ov:SetAllPoints(frame)
    ov:SetFrameLevel(frame:GetFrameLevel() + 2)
    cdmOverlays[frame] = ov
    return ov
end

-- Both LCG calls are now pcall-guarded. LCG is third-party code we don't
-- control; if it ever errors on a given frame/options combo, we don't want
-- that to abort whatever loop called us (see ApplyGlowState/UpdateGlows).
local function RequestGlow(frame, enabled, auraID, color)
    if not LCG then return end
    local overlay = GetOrCreateCDMOverlay(frame)
    if enabled then
        local ok, err = pcall(LCG.ProcGlow_Start, overlay, { color = color or GLOW_COLOR, startAnim = false })
        if not ok then
            -- print("|cffff0000CDMGlow ProcGlow_Start error:|r", err)
        end
    else
        pcall(LCG.ProcGlow_Stop, overlay)
    end
end

-- ---------------------------------------------------------------------------
-- NOTE: resource-based glow color (white when not enough Runic Power) was
-- attempted here and reverted. Confirmed via /console taintLog 1 that
-- comparing UnitPower("player", RunicPower) against any threshold is
-- UNCONDITIONALLY blocked as a "secret value" comparison — every single
-- call, not just when execution happens to carry taint. There is no
-- addon-visible number to compare against baseCost at all.
-- C_Spell.IsSpellUsable() was considered as a sanctioned alternative, but
-- it can't work either: the glow only shows while Sudden Doom is active,
-- and Sudden Doom is exactly what discounts Death Coil/Necrotic Coil's
-- cost (30 RP -> 15 RP) for that window, so IsSpellUsable would only ever
-- reflect the discounted cost, not the real 30 RP baseline — the one
-- case we'd want to flag as "actually low" always reads as "usable".
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- "ready:" spell check
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
-- Frame scanning
-- ---------------------------------------------------------------------------
-- Every touch of a frame we don't own (IsForbidden, GetName, GetParent,
-- GetObjectType, GetChildren, raw field reads like frame.spellID) is now
-- wrapped in pcall. Forbidden/protected frames can throw on ANY field
-- access in current WoW clients, including the very first "is this safe"
-- check — so IsSafeFrame itself must be inside a pcall, not just the
-- checks that come after it. This mirrors the pattern Shared.lua already
-- uses for ScanFramesByTexture, which is why Festering/Flurry never had
-- this problem while Death Coil did: more CDM icons active at once in a
-- dungeon means ScanFrameTree walks more (and more varied) frames per
-- pass, so the odds of hitting one bad node — and silently aborting the
-- whole scan mid-recursion — go up a lot compared to a solo dummy.
-- ---------------------------------------------------------------------------

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function IsSafeFrame(frame)
    if not frame then return false end
    local ok, forbidden = pcall(function()
        return frame.IsForbidden and frame:IsForbidden()
    end)
    if not ok then return false end
    if forbidden then return false end
    return true
end

local function GetButtonSpellID(frame)
    if not IsSafeFrame(frame) then return nil end

    local ok, sid = pcall(function()
        return frame.spellID or frame.spellId or frame.spellid
    end)
    if ok and type(sid) == "number" and not IsSecret(sid) then return sid end

    local ok2, v = pcall(function()
        if frame.GetSpellID then return frame:GetSpellID() end
        return nil
    end)
    if ok2 and type(v) == "number" and not IsSecret(v) then return v end

    return nil
end

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

local CDM_VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
    "BlizzardCooldownFrame",
}

local function IsInCDMViewer(frame)
    local f = frame
    for i = 1, 10 do
        if not IsSafeFrame(f) then break end

        local ok, name = pcall(function()
            return f.GetName and f:GetName()
        end)
        if ok and name then
            for _, vname in ipairs(CDM_VIEWER_NAMES) do
                if name == vname then return true end
            end
        end

        local ok2, parent = pcall(function() return f:GetParent() end)
        if not ok2 or not parent then break end
        f = parent
    end
    return false
end

local function FindCurrentCDMFrames()
    local found = {}
    for auraID in pairs(CDMGlow.spellsByAura) do found[auraID] = {} end

    local results, seen = {}, {}
    for _, name in ipairs(CDM_VIEWER_NAMES) do
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
    if not CXUI_DB.cdmGlow or not DB.enabled then
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
-- Rescan scheduler
-- ---------------------------------------------------------------------------

local rescanGen = 0

function CDMGlow:ScheduleRescan(delay)
    rescanGen = rescanGen + 1
    local gen = rescanGen
    C_Timer.After(delay or 0.2, function()
        if gen ~= rescanGen then return end
        self:UpdateGlowsAfterRescan()
    end)
end

-- ---------------------------------------------------------------------------
-- Combat safeguard ticker
-- ---------------------------------------------------------------------------

local safeguardTicker = nil

function CDMGlow:StartSafeguardTicker()
    if safeguardTicker then return end
    safeguardTicker = C_Timer.NewTicker(10, function()
        table.wipe(CDMGlow.lastCDMPresence)
        CDMGlow:ScheduleRescan(0.1)
    end)
end

function CDMGlow:StopSafeguardTicker()
    if safeguardTicker then safeguardTicker:Cancel(); safeguardTicker = nil end
end

-- ---------------------------------------------------------------------------
-- Full state reset (used on spec/hero-tree change)
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
end

-- ---------------------------------------------------------------------------
-- Hook CDM
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
            -- Classes in SUPPRESS_EXEMPT_CLASSES keep their native Blizzard overlay
            if SUPPRESS_EXEMPT_CLASSES[CDMGlow._playerClass] then return end
            if not IsSafeFrame(frame) then return end

            local alert = frame.SpellActivationAlert
            if alert then alert:SetAlpha(0); alert:Hide() end

            local spellID = GetButtonSpellID(frame)
            local inCDM = IsInCDMViewer(frame)

            if cdm and cdm.Glow and inCDM and spellID then
                pcall(function() cdm.Glow:StopGlow(frame) end)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_CDMGLOWDEBUG1 = "/cdmglow"
SlashCmdList["CDMGLOWDEBUG"] = function(msg)
    local cmd = (msg:match("^(%S+)") or msg):lower()

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
        print("|cff0070ddcxUI:|r /cdmglow debug  — CDM frames in viewers")
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
        CDMGlow._playerClass = class
        RegisterClassSpells(class)

        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("PLAYER_TALENT_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELL_UPDATE_USABLE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_PET")

        C_Timer.After(1.5, function()
            CDMGlow:HookCDM()
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        FullReset()
        C_Timer.After(0.5, function()
            local _, class = UnitClass("player")
            CDMGlow._playerClass = class
            RegisterClassSpells(class)
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_TALENT_UPDATE" then
        -- Hero talent tree changed within the same spec
        FullReset()
        C_Timer.After(0.5, function()
            local _, class = UnitClass("player")
            CDMGlow._playerClass = class
            RegisterClassSpells(class)
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        CDMGlow:StartSafeguardTicker()

    elseif event == "PLAYER_REGEN_ENABLED" then
        CDMGlow:StopSafeguardTicker()
        table.wipe(CDMGlow.lastCDMPresence)
        CDMGlow:ScheduleRescan(0.3)

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            CDMGlow:HookCDM()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "UNIT_PET" then
        CDMGlow:ScheduleRescan(0.2)

    elseif event == "UNIT_AURA" and (...) == "player" then
        if not CDMGlow._pendingUpdate then
            CDMGlow._pendingUpdate = true
            C_Timer.After(0.1, function()
                CDMGlow._pendingUpdate = false
                CDMGlow:UpdateGlows()
            end)
        end

    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        if next(CDMGlow.readySpells) then
            if not CDMGlow._pendingUpdate then
                CDMGlow._pendingUpdate = true
                C_Timer.After(0.1, function()
                    CDMGlow._pendingUpdate = false
                    CDMGlow:UpdateGlows()
                end)
            end
        end

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
                C_Timer.After(0.15, function()
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
                    CDMGlow.overlayProcSpells[auraID] = nil
                    CDMGlow:UpdateGlows()
                end
            end
        end
    end
end)