local addonName, ns = ...

-- ===========================================================================
-- MODULE: CLASS FEATURES
--
-- [DEATHKNIGHT / Unholy] Enemy Counter
--   Shows enemy count above the CDM Death Coil button during combat.
-- ===========================================================================

do
    local _, _, classID = UnitClass("player")
    if classID ~= 6 then return end
end

-- ---------------------------------------------------------------------------
-- Configuration — adjust all visual settings here
-- ---------------------------------------------------------------------------
local DB_KEY       = "cdmEnemyCounter"   -- CXUI_DB key (Settings panel toggle)

local FONT_NAME    = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE    = 20
local FONT_FLAGS   = "OUTLINE"           -- "", "OUTLINE", "THICKOUTLINE"
local FONT_COLOR_R = 1
local FONT_COLOR_G = 1
local FONT_COLOR_B = 1

local ANCHOR_POINT    = "TOP"         -- which point of the FontString to anchor
local ANCHOR_RELATIVE = "TOP"            -- relative to which point of the DC frame
local OFFSET_X        = 0               -- horizontal offset in pixels
local OFFSET_Y        = 8               -- vertical offset in pixels

-- ---------------------------------------------------------------------------
-- CDM frame scanning (outside combat only)
-- ---------------------------------------------------------------------------
local CDM_VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
}

local function IsSafeFrame(f)
    if not f then return false end
    if f.IsForbidden and f:IsForbidden() then return false end
    return true
end

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function ScanForTexture(root, targetTex, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true
    if root.Icon and root.Icon.GetTexture then
        local ok, tex = pcall(root.Icon.GetTexture, root.Icon)
        if ok and tex and not IsSecret(tex) then
            if tex == targetTex or tostring(tex) == tostring(targetTex) then
                results[#results + 1] = root
            end
        end
    end
    if root.GetChildren then
        local ok, ch = pcall(function() return { root:GetChildren() } end)
        if ok and ch then
            for i = 1, #ch do ScanForTexture(ch[i], targetTex, results, seen, depth + 1) end
        end
    end
end

local function FindDCFrames()
    local tex = C_Spell.GetSpellTexture(47541)  -- Death Coil
    if not tex then return {} end
    local results, seen = {}, {}
    for _, name in ipairs(CDM_VIEWER_NAMES) do
        if _G[name] then ScanForTexture(_G[name], tex, results, seen, 0) end
    end
    return results
end

-- ---------------------------------------------------------------------------
-- Counter label (one FontString per DC frame, parented to UIParent)
-- ---------------------------------------------------------------------------
local counterLabels = {}  -- [dcFrame] = FontString's parent frame

local function GetOrCreateCounter(dcFrame)
    if counterLabels[dcFrame] then return counterLabels[dcFrame] end
    if not IsSafeFrame(dcFrame) then return nil end

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(dcFrame)
    f:SetFrameStrata("HIGH")

    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT_NAME, FONT_SIZE, FONT_FLAGS)
    fs:SetPoint(ANCHOR_POINT, f, ANCHOR_RELATIVE, OFFSET_X, OFFSET_Y)
    fs:SetTextColor(FONT_COLOR_R, FONT_COLOR_G, FONT_COLOR_B)
    fs:SetText("")
    f.label = fs

    f:Hide()
    counterLabels[dcFrame] = f
    return f
end

local function HideAllCounters()
    for _, f in pairs(counterLabels) do
        f:Hide()
        f.label:SetText("")
    end
end

-- ---------------------------------------------------------------------------
-- Enemy counting
-- ---------------------------------------------------------------------------
local npActive = {}
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
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            local inCbt  = UnitAffectingCombat(unit)
            local threat = UnitThreatSituation("player", unit)
            if inCbt or threat ~= nil then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            end
        end
    end
    if not targetCounted and hasTarget and IsValidEnemy("target") then
        local inCbt  = UnitAffectingCombat("target")
        local threat = UnitThreatSituation("player", "target")
        if inCbt or threat ~= nil then count = count + 1 end
    end
    return count
end

-- ---------------------------------------------------------------------------
-- Counter state
-- ---------------------------------------------------------------------------
local Counter = {
    _frames        = {},
    _lastCount     = -1,
    _ticker        = nil,
    _tickerRunning = false,
    _rescanGen     = 0,
}

local function UpdateCounter()
    if not CXUI_DB[DB_KEY]
    or not UnitAffectingCombat("player")
    or GetSpecialization() ~= 3 then
        HideAllCounters()
        Counter._lastCount = -1
        return
    end

    local count = GetEnemyCount()
    if count == Counter._lastCount then return end
    Counter._lastCount = count

    for _, dcFrame in ipairs(Counter._frames) do
        local f = GetOrCreateCounter(dcFrame)
        if f then
            if count > 0 then
                f.label:SetText(tostring(count))
                f:Show()
            else
                f.label:SetText("")
                f:Hide()
            end
        end
    end
end

function Counter:RescanFrames()
    if UnitAffectingCombat("player") then return end
    HideAllCounters()
    self._lastCount = -1
    self._frames = FindDCFrames()
    for _, f in ipairs(self._frames) do GetOrCreateCounter(f) end
end

function Counter:ScheduleRescan(delay)
    self._rescanGen = self._rescanGen + 1
    local gen = self._rescanGen
    C_Timer.After(delay or 0.2, function()
        if gen ~= self._rescanGen then return end
        self:RescanFrames()
    end)
end

function Counter:StartTicker()
    if self._tickerRunning then return end
    self._tickerRunning = true
    self._ticker = C_Timer.NewTicker(1.0, function() UpdateCounter() end)
end

function Counter:StopTicker()
    if not self._tickerRunning then return end
    self._tickerRunning = false
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    HideAllCounters()
    self._lastCount = -1
end

-- ---------------------------------------------------------------------------
-- Nameplate events
-- ---------------------------------------------------------------------------
npTracker:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if UnitIsFriend("player", unit) then return end
        npActive[unit] = true
        if UnitAffectingCombat("player") then UpdateCounter() end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        npActive[unit] = nil
        if UnitAffectingCombat("player") then UpdateCounter() end
    elseif event == "UNIT_FLAGS" then
        if npActive[unit] and UnitIsFriend("player", unit) then
            npActive[unit] = nil
            if UnitAffectingCombat("player") then UpdateCounter() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(npActive)
    end
end)

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, classID = UnitClass("player")
        if classID ~= 6 then self:UnregisterAllEvents(); return end

        StartNpTracker()

        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")

        C_Timer.After(2.0, function()
            local cdm = _G["Ayije_CDM"]
            if cdm and cdm.ForceReanchor then
                hooksecurefunc(cdm, "ForceReanchor", function()
                    Counter:ScheduleRescan(0.3)
                end)
            end
            Counter:RescanFrames()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        if CXUI_DB[DB_KEY] then
            Counter:StartTicker()
            UpdateCounter()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        Counter:StopTicker()
        Counter:ScheduleRescan(0.5)

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, function() Counter:RescanFrames() end)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        Counter:StopTicker()
        StopNpTracker()
        StartNpTracker()
        C_Timer.After(0.5, function() Counter:RescanFrames() end)

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") and CXUI_DB[DB_KEY] then
            UpdateCounter()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Debug  /cxaoe [scan | status]
-- ---------------------------------------------------------------------------
SLASH_CXAOEDEBUG1 = "/cxaoe"
SlashCmdList["CXAOEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" then
        Counter:RescanFrames()
        print("|cff0070ddcxUI AoE:|r frames=" .. #Counter._frames)
        for i, f in ipairs(Counter._frames) do
            local n = "?"; if f.GetName then local ok, v = pcall(f.GetName, f); if ok then n = tostring(v) end end
            local lbl = counterLabels[f]
            print("  [" .. i .. "] " .. n .. "  label=" .. tostring(lbl ~= nil) .. "  shown=" .. tostring(lbl and lbl:IsShown() or false))
        end
    elseif cmd == "status" then
        local count   = GetEnemyCount()
        local npCount = 0; for _ in pairs(npActive) do npCount = npCount + 1 end
        print("|cff0070ddcxUI AoE:|r"
            .. "  enabled="  .. tostring(CXUI_DB[DB_KEY])
            .. "  spec="     .. tostring(GetSpecialization())
            .. "  combat="   .. tostring(UnitAffectingCombat("player") and true or false)
            .. "  enemies="  .. count
            .. "  npActive=" .. npCount
            .. "  frames="   .. #Counter._frames)
    else
        print("|cff0070ddcxUI AoE:|r /cxaoe [scan|status]")
    end
end