local addonName, ns = ...

-- ===========================================================================
-- MODULE: CLASS FEATURES
--
-- A collection of per-class quality-of-life overlays and indicators that
-- integrate with the Ayije CDM cooldown manager. Each feature is gated to
-- the relevant class/spec and can be toggled independently via CXUI_DB keys
-- controlled by the Settings panel (Module 6).
--
-- Features in this file:
--   [DEATHKNIGHT / Unholy] AoE Swap
--     Overlays the CDM Death Coil button with the recommended spend-resource
--     spell based on the number of visible enemies currently in combat.
--     Uses an OVERLAY-layer texture drawn above frame.Icon so it is immune
--     to CDM's own Icon:SetTexture() calls (no blinking).
--     Thresholds (no Army of the Dead / Forbidden Knowledge):
--       < 3 enemies  →  Death Coil   (overlay hidden)
--       3+ enemies   →  Epidemic
--     Thresholds (Forbidden Knowledge buff active):
--       < 6 enemies  →  Necrotic Coil
--       6+ enemies   →  Graveyard
-- ===========================================================================

-- ===========================================================================
-- [DEATHKNIGHT / Unholy] AoE Swap
-- ===========================================================================
do
    local _, _, classID = UnitClass("player")
    if classID ~= 6 then return end  -- Death Knight only; other class features go in separate do..end blocks
end

-- ---------------------------------------------------------------------------
-- Spell IDs
-- ---------------------------------------------------------------------------
local DEATH_COIL_ID          = 47541
local EPIDEMIC_ID            = 207317
local NECROTIC_COIL_ID       = 434179
local GRAVEYARD_ID           = 458714
local FORBIDDEN_KNOWLEDGE_ID = 1242223  -- present while Army of the Dead is active

-- Thresholds (mirrors aoe_dk defaults, simplified per user request)
local THRESHOLD_NORMAL = 3   -- enemies needed to recommend Epidemic
local THRESHOLD_FK     = 6   -- enemies needed to recommend Graveyard (Army mode)

-- Hero talent detection (same IDs as aoe_dk)
local RIDER_CHECK_ID   = 444929  -- A Feast of Souls → Rider of the Apocalypse
local SANLAYN_CHECK_ID = 434153  -- Gift of the San'layn

-- Hero talent threshold modifiers (same as aoe_dk)
local HERO_MOD = { rider = -1, sanlayn = 0 }

-- Spell textures — cached once at login, never looked up mid-combat.
local TEX = {}
local function CacheTextures()
    TEX[EPIDEMIC_ID]      = C_Spell.GetSpellTexture(EPIDEMIC_ID)
    TEX[NECROTIC_COIL_ID] = C_Spell.GetSpellTexture(NECROTIC_COIL_ID)
    TEX[GRAVEYARD_ID]     = C_Spell.GetSpellTexture(GRAVEYARD_ID)
end

-- ---------------------------------------------------------------------------
-- CDM frame scanning
-- ---------------------------------------------------------------------------
local CDM_VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
}

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function IsSafeFrame(f)
    if not f then return false end
    if f.IsForbidden and f:IsForbidden() then return false end
    return true
end

local function GetButtonSpellID(f)
    if not IsSafeFrame(f) then return nil end
    local sid = f.spellID or f.spellId or f.spellid
    if type(sid) == "number" and not IsSecret(sid) then return sid end
    if f.GetSpellID then
        local ok, v = pcall(f.GetSpellID, f)
        if ok and type(v) == "number" and not IsSecret(v) then return v end
    end
    return nil
end

local function ScanForSpellID(root, targetID, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true
    if root.GetObjectType then
        local ok, ot = pcall(root.GetObjectType, root)
        if ok and (ot == "Button" or ot == "Frame") then
            -- CDM always stores the BASE spell ID on frame.spellID even when
            -- the displayed texture is overridden (e.g. Necrotic Coil during Army).
            if GetButtonSpellID(root) == targetID and root.Icon then
                results[#results + 1] = root
            end
        end
    end
    if root.GetChildren then
        local ok, children = pcall(function() return { root:GetChildren() } end)
        if ok and children then
            for i = 1, #children do
                ScanForSpellID(children[i], targetID, results, seen, depth + 1)
            end
        end
    end
end

local function FindDeathCoilFrames()
    local results, seen = {}, {}
    for _, name in ipairs(CDM_VIEWER_NAMES) do
        if _G[name] then ScanForSpellID(_G[name], DEATH_COIL_ID, results, seen, 0) end
    end
    return results
end

-- ---------------------------------------------------------------------------
-- Overlay texture management
--
-- We create a Texture at the OVERLAY draw layer directly on the CDM frame.
-- Because frame.Icon lives at ARTWORK and child Frames (Cooldown) only draw
-- their own swipe/flash (mostly transparent when spell is ready), the OVERLAY
-- texture sits visually above the icon without interfering with CDM's own
-- Icon:SetTexture() writes — solving the blinking problem completely.
-- ---------------------------------------------------------------------------
local overlayTextures = {}  -- [cdmFrame] = Texture

local function GetOrCreateOverlay(cdmFrame)
    if overlayTextures[cdmFrame] then return overlayTextures[cdmFrame] end
    if not IsSafeFrame(cdmFrame) then return nil end

    -- "OVERLAY" layer is above "ARTWORK" (where frame.Icon lives) so our
    -- texture is always on top regardless of CDM's Icon:SetTexture() calls.
    local ok, tex = pcall(cdmFrame.CreateTexture, cdmFrame, nil, "OVERLAY", nil, 7)
    if not ok or not tex then return nil end

    pcall(tex.SetAllPoints, tex, cdmFrame)
    pcall(tex.SetTexCoord,  tex, 0.08, 0.92, 0.08, 0.92)
    tex:Hide()

    overlayTextures[cdmFrame] = tex
    return tex
end

local function ShowOverlay(cdmFrame, spellID)
    local tex = GetOrCreateOverlay(cdmFrame)
    if not tex then return end
    local t = TEX[spellID]
    if t then pcall(tex.SetTexture, tex, t) end
    pcall(tex.Show, tex)
end

local function HideOverlay(cdmFrame)
    local tex = overlayTextures[cdmFrame]
    if tex then pcall(tex.Hide, tex) end
end

local function HideAllOverlays()
    for _, tex in pairs(overlayTextures) do
        pcall(tex.Hide, tex)
    end
end

-- ---------------------------------------------------------------------------
-- Enemy counting — exact port from aoe_dk (nameplate events + target fallback)
-- ---------------------------------------------------------------------------
local npActive = {}   -- [unit] = true for visible hostile nameplates
local npTracker = CreateFrame("Frame")
local npTrackerRunning = false

local function StartNpTracker()
    if npTrackerRunning then return end
    npTrackerRunning = true
    npTracker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npTracker:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    npTracker:RegisterEvent("UNIT_FLAGS")
    npTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function StopNpTracker()
    if not npTrackerRunning then return end
    npTrackerRunning = false
    npTracker:UnregisterAllEvents()
    wipe(npActive)
end

local function IsValidEnemy(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDead(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    return true
end

local function GetEnemyCount()
    local count, targetCounted = 0, false
    local hasTarget = UnitExists("target")

    -- Step 1: nameplates in combat or with threat (primary source, event-driven).
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            local inCbt   = UnitAffectingCombat(unit)
            local threat  = UnitThreatSituation("player", unit)
            if inCbt or threat ~= nil then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            end
        end
    end

    -- Step 2: always include current target if valid and not already counted.
    if not targetCounted and hasTarget and IsValidEnemy("target") then
        local inCbt  = UnitAffectingCombat("target")
        local threat = UnitThreatSituation("player", "target")
        if inCbt or threat ~= nil then count = count + 1 end
    end

    return count
end

-- Forward declaration so npTracker OnEvent can call UpdateOverlay.
local UpdateOverlay

npTracker:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if UnitIsFriend("player", unit) then return end
        if not UnitCanAttack("player", unit) then return end
        npActive[unit] = true
        -- Immediate update on nameplate change (mirrors aoe_dk behavior).
        if UnitAffectingCombat("player") then UpdateOverlay() end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        npActive[unit] = nil
        if UnitAffectingCombat("player") then UpdateOverlay() end
    elseif event == "UNIT_FLAGS" then
        if npActive[unit] and UnitIsFriend("player", unit) then
            npActive[unit] = nil
            if UnitAffectingCombat("player") then UpdateOverlay() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(npActive)
    end
end)

-- ---------------------------------------------------------------------------
-- Hero talent detection (cached on spec change, same as aoe_dk)
-- ---------------------------------------------------------------------------
local cachedHeroTalent = nil

local function RefreshHeroTalent()
    if IsPlayerSpell(RIDER_CHECK_ID) then
        cachedHeroTalent = "rider"
    elseif IsPlayerSpell(SANLAYN_CHECK_ID) then
        cachedHeroTalent = "sanlayn"
    else
        cachedHeroTalent = nil
    end
end

local function IsForbiddenKnowledgeActive()
    return C_UnitAuras.GetPlayerAuraBySpellID(FORBIDDEN_KNOWLEDGE_ID) ~= nil
end

-- ---------------------------------------------------------------------------
-- AoE Swap state
-- ---------------------------------------------------------------------------
local AoESwap = {
    _frames        = {},
    _currentSpell  = nil,   -- last recommended spell (nil = Death Coil / no overlay)
    _ticker        = nil,
    _tickerRunning = false,
    _rescanGen     = 0,
}

-- Determine the recommended spell given current enemy count and Army state.
-- Logic is a direct port of aoe_dk UpdateIcon with user-specified thresholds.
local function GetRecommendedSpell(count, fkActive)
    local heroMod = (cachedHeroTalent and HERO_MOD[cachedHeroTalent]) or 0

    if fkActive then
        -- Army of the Dead active: Necrotic Coil / Graveyard tier.
        local threshold = math.max(1, THRESHOLD_FK + heroMod)
        if count >= (threshold + 1) then
            return GRAVEYARD_ID
        elseif count >= threshold then
            return NECROTIC_COIL_ID
        else
            return nil  -- too few enemies — Death Coil is better even with Army
        end
    else
        -- Normal mode: Death Coil vs Epidemic.
        local threshold = math.max(1, THRESHOLD_NORMAL + heroMod)
        if count >= threshold then
            return EPIDEMIC_ID
        else
            return nil
        end
    end
end

-- Apply overlay to all tracked Death Coil CDM frames.
-- Called from ticker (every 1s) AND immediately from nameplate events.
UpdateOverlay = function()
    if not CXUI_DB.cdmAoESwap then
        if AoESwap._currentSpell then
            HideAllOverlays()
            AoESwap._currentSpell = nil
        end
        return
    end

    if not UnitAffectingCombat("player") then
        if AoESwap._currentSpell then
            HideAllOverlays()
            AoESwap._currentSpell = nil
        end
        return
    end

    local specIndex = GetSpecialization()
    if specIndex ~= 3 then  -- Unholy only
        if AoESwap._currentSpell then
            HideAllOverlays()
            AoESwap._currentSpell = nil
        end
        return
    end

    local count    = GetEnemyCount()
    local fkActive = IsForbiddenKnowledgeActive()
    local spell    = GetRecommendedSpell(count, fkActive)

    -- Only update textures when the recommendation actually changes.
    -- This prevents any per-tick texture writes and eliminates blinking.
    if spell == AoESwap._currentSpell then return end
    AoESwap._currentSpell = spell

    if spell then
        for _, f in ipairs(AoESwap._frames) do ShowOverlay(f, spell) end
    else
        HideAllOverlays()
    end
end

function AoESwap:RescanFrames()
    HideAllOverlays()
    self._currentSpell = nil
    self._frames = FindDeathCoilFrames()
    -- Pre-create overlay textures on all found frames.
    for _, f in ipairs(self._frames) do GetOrCreateOverlay(f) end
    UpdateOverlay()
end

function AoESwap:ScheduleRescan(delay)
    self._rescanGen = self._rescanGen + 1
    local gen = self._rescanGen
    C_Timer.After(delay or 0.2, function()
        if gen ~= self._rescanGen then return end
        self:RescanFrames()
    end)
end

function AoESwap:StartTicker()
    if self._tickerRunning then return end
    self._tickerRunning = true
    StartNpTracker()
    -- 1-second tick: re-evaluates enemy count and updates overlay only when
    -- the recommended spell changes — no unnecessary texture writes between ticks.
    self._ticker = C_Timer.NewTicker(1.0, function() UpdateOverlay() end)
end

function AoESwap:StopTicker()
    if not self._tickerRunning then return end
    self._tickerRunning = false
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    StopNpTracker()
    HideAllOverlays()
    self._currentSpell = nil
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, classID = UnitClass("player")
        if classID ~= 6 then self:UnregisterAllEvents(); return end

        CacheTextures()
        RefreshHeroTalent()

        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterUnitEvent("UNIT_AURA", "player")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")

        C_Timer.After(2.0, function()
            local cdm = _G["Ayije_CDM"]
            if cdm and cdm.ForceReanchor then
                hooksecurefunc(cdm, "ForceReanchor", function()
                    AoESwap:ScheduleRescan(0.2)
                end)
            end
            AoESwap:RescanFrames()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        if CXUI_DB.cdmAoESwap then
            AoESwap:StartTicker()
            UpdateOverlay()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        AoESwap:StopTicker()

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, function() AoESwap:RescanFrames() end)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        RefreshHeroTalent()
        AoESwap:StopTicker()
        C_Timer.After(0.5, function() AoESwap:RescanFrames() end)

    elseif event == "UNIT_AURA" then
        -- Forbidden Knowledge (Army) aura state changed — update immediately.
        if UnitAffectingCombat("player") and CXUI_DB.cdmAoESwap then
            UpdateOverlay()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Target change may add/remove an enemy from the count.
        if UnitAffectingCombat("player") and CXUI_DB.cdmAoESwap then
            UpdateOverlay()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Debug commands (/cxaoe scan | status)
-- ---------------------------------------------------------------------------
SLASH_CXAOEDEBUG1 = "/cxaoe"
SlashCmdList["CXAOEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" then
        AoESwap:RescanFrames()
        print("|cff0070ddcxUI AoE:|r Scanned. Found " .. #AoESwap._frames .. " Death Coil frame(s).")
        for i, f in ipairs(AoESwap._frames) do
            local name = "?"
            if f.GetName then local ok, n = pcall(f.GetName, f); if ok then name = tostring(n) end end
            print("  [" .. i .. "] " .. name
                .. "  spellID=" .. tostring(f.spellID)
                .. "  Icon=" .. tostring(f.Icon ~= nil)
                .. "  overlay=" .. tostring(overlayTextures[f] ~= nil))
        end
    elseif cmd == "status" then
        local count  = GetEnemyCount()
        local fk     = IsForbiddenKnowledgeActive()
        local spell  = GetRecommendedSpell(count, fk)
        print("|cff0070ddcxUI AoE:|r"
            .. "  enabled="  .. tostring(CXUI_DB.cdmAoESwap)
            .. "  spec="     .. tostring(GetSpecialization())
            .. "  combat="   .. tostring(UnitAffectingCombat("player") and true or false)
            .. "  enemies="  .. count
            .. "  FK="       .. tostring(fk)
            .. "  hero="     .. tostring(cachedHeroTalent)
            .. "  recommend=" .. tostring(spell)
            .. "  current="  .. tostring(AoESwap._currentSpell)
            .. "  frames="   .. #AoESwap._frames)
    else
        print("|cff0070ddcxUI AoE:|r /cxaoe [scan|status]")
    end
end