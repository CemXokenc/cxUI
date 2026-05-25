local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: DEATH KNIGHT (classID 6)
-- Features: Enemy Counter, Festering Strike Glow, Putrefy Cross, Frost Bar Swap
-- ===========================================================================

local CF = ns.CF
if not CF or CF.CLASS_ID ~= 6 then return end

local LCG                  = CF.LCG
local ScanFramesByTexture  = CF.ScanFramesByTexture
local CreateOverlay        = CF.CreateOverlay
local StartGlow            = CF.StartGlow
local StopGlow             = CF.StopGlow
local AttachXCross         = CF.AttachXCross
local ShowXCross           = CF.ShowXCross
local HideXCross           = CF.HideXCross

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local TEX_FESTERING_SCYTHE = "3997563"
local TEX_FESTERING_STRIKE = "879926"
local TEX_PUTREFY          = "7439191"
local TEX_REAPER           = "636333"

local SPELL_FESTERING_SCYTHE    = 458128
local SPELL_FESTERING_STRIKE    = 85948
local SPELL_DARK_TRANSFORMATION = 1233448
local SPELL_OBLITERATE          = 49020
local SPELL_FROSTSCYTHE         = 207230

local FESTERING_DELAY  = 20   -- 25s buff - 5s warning
local PUTREFY_DELAY    = 36   -- 45s DT CD - 9s warning
local PUTREFY_DURATION = 9
local REAPER_DELAY     = 35   -- 45s DT CD - 10s warning
local REAPER_DURATION  = 10

-- ---------------------------------------------------------------------------
-- ENEMY COUNTER (cdmEnemyCounter)
-- Displays live enemy count above the Death Coil CDM button during combat.
-- ---------------------------------------------------------------------------

local DB_COUNTER = "cdmEnemyCounter"
local FONT_NAME  = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE  = 20
local FONT_FLAGS = "OUTLINE"
local OFFSET_Y   = 8

local counterLabels = {}

local function GetOrCreateCounter(dcFrame)
    if counterLabels[dcFrame] then return counterLabels[dcFrame] end
    if not dcFrame or (dcFrame.IsForbidden and dcFrame:IsForbidden()) then return nil end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(dcFrame); f:SetFrameStrata("HIGH")
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT_NAME, FONT_SIZE, FONT_FLAGS)
    fs:SetPoint("TOP", f, "TOP", 0, OFFSET_Y)
    fs:SetTextColor(1, 1, 1)
    fs:SetText(""); f.label = fs; f:Hide()
    counterLabels[dcFrame] = f
    return f
end

local function HideAllCounters()
    for _, f in pairs(counterLabels) do f:Hide(); f.label:SetText("") end
end

local npActive = {}
local npTracker = CreateFrame("Frame")
local npTrackerRunning = false

local function StartNpTracker()
    if npTrackerRunning then return end; npTrackerRunning = true
    npTracker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npTracker:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    npTracker:RegisterEvent("UNIT_FLAGS")
    npTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function StopNpTracker()
    if not npTrackerRunning then return end; npTrackerRunning = false
    npTracker:UnregisterAllEvents(); wipe(npActive)
end

local function IsValidEnemy(unit)
    return UnitExists(unit) and not UnitIsDead(unit) and UnitCanAttack("player", unit)
end

local function GetEnemyCount()
    local count, targetCounted = 0, false
    local hasTarget = UnitExists("target")
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            if UnitAffectingCombat(unit) or UnitThreatSituation("player", unit) ~= nil then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            end
        end
    end
    if not targetCounted and hasTarget and IsValidEnemy("target") then
        if UnitAffectingCombat("target") or UnitThreatSituation("player", "target") ~= nil then
            count = count + 1
        end
    end
    return count
end

local UpdateCounter
local dcTexStr = nil
local counterFrames = {}

local function RescanCounterFrames()
    if not dcTexStr then
        local t = C_Spell.GetSpellTexture(47541)
        if t then dcTexStr = tostring(t) end
    end
    if not dcTexStr then return end
    wipe(counterFrames)
    ScanFramesByTexture({dcTexStr}, function(f)
        if f.Cooldown then
            counterFrames[f] = true
            GetOrCreateCounter(f)
        end
    end)
end

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

local Counter = { _lastCount=-1, _ticker=nil, _tickerRunning=false }

UpdateCounter = function()
    if not CXUI_DB[DB_COUNTER] or not UnitAffectingCombat("player") or GetSpecialization() ~= 3 then
        HideAllCounters(); Counter._lastCount = -1; return
    end
    local count = GetEnemyCount()
    if count == Counter._lastCount then return end
    Counter._lastCount = count
    for dcFrame in pairs(counterFrames) do
        local f = GetOrCreateCounter(dcFrame)
        if f then
            if count > 0 then f.label:SetText(tostring(count)); f:Show()
            else f.label:SetText(""); f:Hide() end
        end
    end
end

function Counter:StartTicker()
    if self._tickerRunning then return end; self._tickerRunning = true
    self._ticker = C_Timer.NewTicker(1.0, function() UpdateCounter() end)
end

function Counter:StopTicker()
    if not self._tickerRunning then return end; self._tickerRunning = false
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    HideAllCounters(); self._lastCount = -1
end

-- ---------------------------------------------------------------------------
-- FESTERING STRIKE GLOW (cdmFesteringGlow)
-- White glow on Festering Strike/Scythe CDM when buff has <5s left.
-- ---------------------------------------------------------------------------

local DB_FESTERING = "cdmFesteringGlow"
local cdmFesteringOverlays = {}
local festeringTimer       = nil
local festeringGlowActive  = false

-- Single EnumerateFrames pass for festering, putrefy and reaper overlays.
local function HideFesteringGlow()
    if festeringTimer then festeringTimer:Cancel(); festeringTimer = nil end
    festeringGlowActive = false
    for _, ov in pairs(cdmFesteringOverlays) do StopGlow(ov) end
end

local function ShowFesteringGlow()
    if not CXUI_DB[DB_FESTERING] or GetSpecialization() ~= 3 then return end
    festeringGlowActive = true
    for _, ov in pairs(cdmFesteringOverlays) do StartGlow(ov) end
end

local function StartFesteringTimer()
    if festeringTimer then festeringTimer:Cancel(); festeringTimer = nil end
    HideFesteringGlow()
    if not CXUI_DB[DB_FESTERING] or GetSpecialization() ~= 3 then return end
    festeringTimer = C_Timer.NewTimer(FESTERING_DELAY, function()
        festeringTimer = nil; ShowFesteringGlow()
    end)
end

-- ---------------------------------------------------------------------------
-- PUTREFY CROSS (cdmPutrefyCross)
-- Red × on Putrefy CDM when Dark Transformation has <9s CD remaining.
-- ---------------------------------------------------------------------------

local DB_PUTREFY = "cdmPutrefyCross"
local cdmPutrefyOverlays   = {}
local putrefyWarningActive = false
local putrefyWarningTimer  = nil
local putrefyDurationTimer = nil

local function StopPutrefyWarning()
    putrefyWarningActive = false
    if putrefyWarningTimer  then putrefyWarningTimer:Cancel();  putrefyWarningTimer  = nil end
    if putrefyDurationTimer then putrefyDurationTimer:Cancel(); putrefyDurationTimer = nil end
    for _, ov in pairs(cdmPutrefyOverlays) do HideXCross(ov) end
end

local function ShowPutrefyWarning()
    if putrefyDurationTimer then putrefyDurationTimer:Cancel(); putrefyDurationTimer = nil end
    putrefyWarningActive = true
    if CXUI_DB[DB_PUTREFY] then
        for _, ov in pairs(cdmPutrefyOverlays) do ShowXCross(ov) end
    end
    putrefyDurationTimer = C_Timer.NewTimer(PUTREFY_DURATION, function()
        putrefyDurationTimer = nil; StopPutrefyWarning()
    end)
end

local DB_REAPER = "cdmReaperCross"

local cdmReaperOverlays    = {}
local reaperWarningActive  = false
local reaperWarningTimer   = nil
local reaperDurationTimer  = nil
local ShowReaperWarning    -- forward declaration

local function OnDarkTransformationCast()
    -- Putrefy: cross at 9s remaining (delay 36s)
    if putrefyWarningTimer  then putrefyWarningTimer:Cancel();  putrefyWarningTimer  = nil end
    if putrefyDurationTimer then putrefyDurationTimer:Cancel(); putrefyDurationTimer = nil end
    putrefyWarningActive = false
    for _, ov in pairs(cdmPutrefyOverlays) do HideXCross(ov) end
    if CXUI_DB[DB_PUTREFY] then
        putrefyWarningTimer = C_Timer.NewTimer(PUTREFY_DELAY, function()
            putrefyWarningTimer = nil; ShowPutrefyWarning()
        end)
    end
    -- Reaper: cross at 10s remaining (delay 35s)
    if reaperWarningTimer  then reaperWarningTimer:Cancel();  reaperWarningTimer  = nil end
    if reaperDurationTimer then reaperDurationTimer:Cancel(); reaperDurationTimer = nil end
    reaperWarningActive = false
    for _, ov in pairs(cdmReaperOverlays) do HideXCross(ov) end
    if CXUI_DB[DB_REAPER] then
        reaperWarningTimer = C_Timer.NewTimer(REAPER_DELAY, function()
            reaperWarningTimer = nil; ShowReaperWarning()
        end)
    end
end

-- ---------------------------------------------------------------------------
-- REAPER CROSS (cdmReaperCross)
-- Red × on Reaper CDM when Dark Transformation has <10s CD remaining.
-- Identical pattern to Putrefy Cross: triggered by SPELL_DARK_TRANSFORMATION
-- cast, waits REAPER_DELAY seconds, then shows cross for REAPER_DURATION.
-- ---------------------------------------------------------------------------

local function StopReaperWarning()
    reaperWarningActive = false
    if reaperWarningTimer  then reaperWarningTimer:Cancel();  reaperWarningTimer  = nil end
    if reaperDurationTimer then reaperDurationTimer:Cancel(); reaperDurationTimer = nil end
    for _, ov in pairs(cdmReaperOverlays) do HideXCross(ov) end
end

ShowReaperWarning = function()
    if reaperDurationTimer then reaperDurationTimer:Cancel(); reaperDurationTimer = nil end
    reaperWarningActive = true
    if CXUI_DB[DB_REAPER] then
        for _, ov in pairs(cdmReaperOverlays) do ShowXCross(ov) end
    end
    reaperDurationTimer = C_Timer.NewTimer(REAPER_DURATION, function()
        reaperDurationTimer = nil; StopReaperWarning()
    end)
end

-- ---------------------------------------------------------------------------
-- FROST BAR SWAP (cdmFrostBarSwap)
-- Swaps Obliterate/Scythe and FS/GA icons on CDM after action bar page swap.
-- ---------------------------------------------------------------------------

local DB_FROST_SWAP = "cdmFrostBarSwap"
local oblFrames     = {}
local frostHooked   = {}

local function HookOblFrame(frame)
    if frostHooked[frame] or not frame.Icon then return end
    frostHooked[frame] = true
    hooksecurefunc(frame.Icon, "SetTexture", function(self, tex)
        if not CXUI_DB[DB_FROST_SWAP] then return end
        if GetSpecialization() ~= 2    then return end
        if GetActionBarPage() ~= 2     then return end
        local oblTex = C_Spell.GetSpellTexture(SPELL_OBLITERATE)
        if tex == oblTex or tex == tostring(oblTex) then
            local scyTex = C_Spell.GetSpellTexture(SPELL_FROSTSCYTHE)
            if scyTex then self:SetTexture(scyTex) end
        end
    end)
end

local UpdateFrostSwap  -- forward declaration

local function BuildFrostSwapFrames()
    local oblTex = C_Spell.GetSpellTexture(SPELL_OBLITERATE)
    if oblTex then
        for _, frame in ipairs(oblFrames) do
            if frame.Icon then frame.Icon:SetTexture(oblTex) end
        end
    end

    wipe(oblFrames)
    if not oblTex then return end

    ScanFramesByTexture({tostring(oblTex)}, function(frame)
        if frame.Icon then
            table.insert(oblFrames, frame)
            HookOblFrame(frame)
        end
    end)

    if UpdateFrostSwap then UpdateFrostSwap() end
end

UpdateFrostSwap = function()
    if not oblFrames then return end
    local oblTex = C_Spell.GetSpellTexture(SPELL_OBLITERATE)
    local scyTex = C_Spell.GetSpellTexture(SPELL_FROSTSCYTHE)
    local swapOn = CXUI_DB[DB_FROST_SWAP]
                   and GetSpecialization() == 2
                   and GetActionBarPage() == 2
    for _, frame in ipairs(oblFrames) do
        if frame.Icon then
            if swapOn and scyTex then
                frame.Icon:SetTexture(scyTex)
            elseif oblTex then
                frame.Icon:SetTexture(oblTex)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Full rescan
-- ---------------------------------------------------------------------------

-- Single EnumerateFrames pass for all three CDM overlay types.
-- Must be defined after all overlay table declarations.
local function ScanCDMOverlays()
    for _, ov in pairs(cdmFesteringOverlays) do
        if ov._glowActive and LCG and LCG.ButtonGlow_Stop then LCG.ButtonGlow_Stop(ov) end
        ov:Hide()
    end
    wipe(cdmFesteringOverlays)
    festeringGlowActive = false

    for _, ov in pairs(cdmPutrefyOverlays) do ov:Hide() end
    wipe(cdmPutrefyOverlays)
    putrefyWarningActive = false

    for _, ov in pairs(cdmReaperOverlays) do ov:Hide() end
    wipe(cdmReaperOverlays)
    reaperWarningActive = false

    ScanFramesByTexture(
        {TEX_FESTERING_SCYTHE, TEX_FESTERING_STRIKE, TEX_PUTREFY, TEX_REAPER},
        function(frame)
            local tex = tostring(frame.Icon:GetTexture())
            if tex == TEX_FESTERING_SCYTHE or tex == TEX_FESTERING_STRIKE then
                if not cdmFesteringOverlays[frame] then
                    cdmFesteringOverlays[frame] = CreateOverlay(frame)
                end
            elseif tex == TEX_PUTREFY then
                if not cdmPutrefyOverlays[frame] then
                    local ov = CreateOverlay(frame)
                    AttachXCross(ov)
                    cdmPutrefyOverlays[frame] = ov
                end
            elseif tex == TEX_REAPER then
                if not cdmReaperOverlays[frame] then
                    local ov = CreateOverlay(frame)
                    AttachXCross(ov)
                    cdmReaperOverlays[frame] = ov
                end
            end
        end
    )
end

local function DKRescan()
    RescanCounterFrames()
    ScanCDMOverlays()
    BuildFrostSwapFrames()
end

local function StartRetryLoop()
    for _, delay in ipairs({3, 6, 10, 15}) do
        C_Timer.After(delay, function() DKRescan() end)
    end
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local dkFrame = CreateFrame("Frame")
dkFrame:RegisterEvent("PLAYER_LOGIN")

dkFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, cid = UnitClass("player")
        if cid ~= 6 then self:UnregisterAllEvents(); return end
        StartNpTracker()
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()

    elseif event == "PLAYER_REGEN_DISABLED" then
        if CXUI_DB[DB_COUNTER] then Counter:StartTicker(); UpdateCounter() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        Counter:StopTicker()
        StopPutrefyWarning()
        StopReaperWarning()

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        Counter:StopTicker()
        HideFesteringGlow()
        StopPutrefyWarning()
        StopReaperWarning()
        StopNpTracker(); StartNpTracker()
        C_Timer.After(2, function() DKRescan() end)

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") and CXUI_DB[DB_COUNTER] then UpdateCounter() end

    elseif event == "ACTIONBAR_PAGE_CHANGED" then
        C_Timer.After(0.05, function() BuildFrostSwapFrames() end)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == SPELL_FESTERING_SCYTHE then
            StartFesteringTimer()
        elseif spellID == SPELL_DARK_TRANSFORMATION then
            OnDarkTransformationCast()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Debug commands
-- ---------------------------------------------------------------------------

SLASH_CXAOEDEBUG1 = "/cxaoe"
SlashCmdList["CXAOEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" then
        DKRescan()
        local cf, cp, cs, cc, cr = 0, 0, 0, 0, 0
        for _ in pairs(cdmFesteringOverlays) do cf = cf + 1 end
        for _ in pairs(cdmPutrefyOverlays)   do cp = cp + 1 end
        for _ in ipairs(oblFrames)            do cs = cs + 1 end
        for _ in pairs(counterFrames)         do cc = cc + 1 end
        for _ in pairs(cdmReaperOverlays)     do cr = cr + 1 end
        print("|cff0070ddcxUI:|r counter=" .. cc
            .. "  festering=" .. cf .. "  putrefy=" .. cp
            .. "  frostswap=" .. cs .. "  reaper=" .. cr)
    elseif cmd == "status" then
        local count  = GetEnemyCount()
        local npCount = 0; for _ in pairs(npActive) do npCount = npCount + 1 end
        print("|cff0070ddcxUI:|r spec=" .. tostring(GetSpecialization())
            .. "  enemies=" .. count .. "  npActive=" .. npCount
            .. "  festering=" .. tostring(festeringGlowActive)
            .. "  putrefy=" .. tostring(putrefyWarningActive)
            .. "  reaper=" .. tostring(reaperWarningActive)
            .. "  barpage=" .. tostring(GetActionBarPage()))
    else
        print("|cff0070ddcxUI:|r /cxaoe [scan|status]")
    end
end