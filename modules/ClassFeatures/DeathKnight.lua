local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: DEATH KNIGHT (classID 6)
-- Features: Festering Strike Glow, Putrefy Cross, Frost Bar Swap, Reaper Cross
-- ===========================================================================

local CF = ns.CF
if not CF or CF.CLASS_ID ~= 6 then return end

local ScanFramesBySpellID = CF.ScanFramesBySpellID
local CreateOverlay        = CF.CreateOverlay
local StartGlow            = CF.StartGlow
local StopGlow             = CF.StopGlow
local AttachXCross         = CF.AttachXCross
local ShowXCross           = CF.ShowXCross
local HideXCross           = CF.HideXCross

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

-- NOTE: identification switched from icon-texture comparison to spellID
-- (see Shared.lua) — comparing a CDM icon's live texture is now
-- unconditionally blocked as a secret-value comparison, confirmed via
-- /console taintLog 1, even for our own frames.
local SPELL_FESTERING_STRIKE = 85948
local SPELL_FESTERING_SCYTHE = 458128
local SPELL_PUTREFY          = 1247378
local SPELL_REAPER           = 343294 -- Soul Reaper

local SPELL_DARK_TRANSFORMATION = 1233448
local SPELL_OBLITERATE          = 49020
local SPELL_FROSTSCYTHE         = 207230

local FESTERING_DELAY  = 20
local PUTREFY_DELAY    = 36
local PUTREFY_DURATION = 9
local REAPER_DURATION  = 6

-- ---------------------------------------------------------------------------
-- FESTERING STRIKE GLOW (cdmFesteringGlow)
-- ---------------------------------------------------------------------------

local DB_FESTERING = "cdmFesteringGlow"
local cdmFesteringOverlays = {}
local festeringTimer       = nil
local festeringGlowActive  = false

local function HideFesteringGlow()
    if festeringTimer then festeringTimer:Cancel(); festeringTimer = nil end
    festeringGlowActive = false
    for _, ov in pairs(cdmFesteringOverlays) do StopGlow(ov) end
    if CXUI_DB.cxaoeDebugFestering then
        print("|cffff8800cxUI:|r HideFesteringGlow() called — caller stack:")
        print(debugstack(2, 8, 0))
    end
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

-- ---------------------------------------------------------------------------
-- REAPER CROSS (cdmReaperCross)
-- ---------------------------------------------------------------------------

local DB_REAPER = "cdmReaperCross"
local cdmReaperOverlays    = {}
local reaperWarningActive  = false
local reaperWarningTimer   = nil
local reaperDurationTimer  = nil
local ShowReaperWarning    -- forward declaration

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

local function OnDarkTransformationCast()
    if putrefyWarningTimer  then putrefyWarningTimer:Cancel();  putrefyWarningTimer  = nil end
    if putrefyDurationTimer then putrefyDurationTimer:Cancel(); putrefyDurationTimer = nil end
    putrefyWarningActive = false
    for _, ov in pairs(cdmPutrefyOverlays) do HideXCross(ov) end
    if CXUI_DB[DB_PUTREFY] then
        putrefyWarningTimer = C_Timer.NewTimer(PUTREFY_DELAY, function()
            putrefyWarningTimer = nil; ShowPutrefyWarning()
        end)
    end

    if reaperWarningTimer  then reaperWarningTimer:Cancel();  reaperWarningTimer  = nil end
    if reaperDurationTimer then reaperDurationTimer:Cancel(); reaperDurationTimer = nil end
    reaperWarningActive = false
    for _, ov in pairs(cdmReaperOverlays) do HideXCross(ov) end
    if CXUI_DB[DB_REAPER] then
        ShowReaperWarning()
    end
end

-- ---------------------------------------------------------------------------
-- FROST BAR SWAP (cdmFrostBarSwap)
-- ---------------------------------------------------------------------------

local DB_FROST_SWAP = "cdmFrostBarSwap"
local oblFrames     = {}
local frostHooked   = {}

local settingFrostTexture = {}

local function HookOblFrame(frame)
    if frostHooked[frame] or not frame.Icon then return end
    frostHooked[frame] = true
    hooksecurefunc(frame.Icon, "SetTexture", function(self)
        if settingFrostTexture[self] then return end
        if not CXUI_DB[DB_FROST_SWAP] then return end
        if GetSpecialization() ~= 2    then return end
        if GetActionBarPage() ~= 2     then return end
        local scyTex = C_Spell.GetSpellTexture(SPELL_FROSTSCYTHE)
        if scyTex then
            settingFrostTexture[self] = true
            self:SetTexture(scyTex)
            settingFrostTexture[self] = false
        end
    end)
end

local UpdateFrostSwap

local function BuildFrostSwapFrames()
    local oblTex = C_Spell.GetSpellTexture(SPELL_OBLITERATE)
    if oblTex then
        for _, frame in ipairs(oblFrames) do
            if frame.Icon then frame.Icon:SetTexture(oblTex) end
        end
    end
    wipe(oblFrames)
    ScanFramesBySpellID({SPELL_OBLITERATE}, function(frame)
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

local function ScanCDMOverlays()
    -- Remember what was actually showing before we tear down and rebuild the
    -- overlay frames (e.g. on CDM reanchor) — rebuilding is bookkeeping, not
    -- a reason to hide anything. Only the hard conditions (Festering Scythe
    -- cast, Putrefy/Reaper duration elapsing or being stopped) should do that.
    local wasFesteringActive = festeringGlowActive
    local wasPutrefyActive   = putrefyWarningActive
    local wasReaperActive    = reaperWarningActive

    if CXUI_DB.cxaoeDebugFestering then
        print(string.format("|cff00ff00cxUI:|r ScanCDMOverlays() rebuild — wasFestering=%s", tostring(wasFesteringActive)))
    end

    for _, ov in pairs(cdmFesteringOverlays) do
        if ov._glowActive then StopGlow(ov) end
        ov:Hide()
    end
    wipe(cdmFesteringOverlays); festeringGlowActive = false

    for _, ov in pairs(cdmPutrefyOverlays) do ov:Hide() end
    wipe(cdmPutrefyOverlays); putrefyWarningActive = false

    for _, ov in pairs(cdmReaperOverlays) do ov:Hide() end
    wipe(cdmReaperOverlays); reaperWarningActive = false

    ScanFramesBySpellID(
        {SPELL_FESTERING_STRIKE, SPELL_PUTREFY, SPELL_REAPER},
        function(frame, spellID)
            if spellID == SPELL_FESTERING_STRIKE then
                if not cdmFesteringOverlays[frame] then
                    cdmFesteringOverlays[frame] = CreateOverlay(frame)
                end
            elseif spellID == SPELL_PUTREFY then
                if not cdmPutrefyOverlays[frame] then
                    local ov = CreateOverlay(frame); AttachXCross(ov)
                    cdmPutrefyOverlays[frame] = ov
                end
            elseif spellID == SPELL_REAPER then
                if not cdmReaperOverlays[frame] then
                    local ov = CreateOverlay(frame); AttachXCross(ov)
                    cdmReaperOverlays[frame] = ov
                end
            end
        end
    )

    -- Restore visual state on the freshly created overlays. This does NOT
    -- touch/restart festeringTimer, putrefyDurationTimer, etc. — those keep
    -- counting through the rebuild untouched; we're only re-applying the
    -- glow/cross to whichever new overlay objects now exist.
    if wasFesteringActive and CXUI_DB[DB_FESTERING] and GetSpecialization() == 3 then
        festeringGlowActive = true
        if next(cdmFesteringOverlays) then
            for frame, ov in pairs(cdmFesteringOverlays) do
                StartGlow(ov)
                if CXUI_DB.cxaoeDebugFestering then
                    print(string.format(
                        "|cff00ff00cxUI:|r festering restored — frame:IsShown()=%s frame:IsVisible()=%s ov:IsShown()=%s",
                        tostring(frame:IsShown()), tostring(frame:IsVisible()), tostring(ov:IsShown())))
                end
            end
        elseif CXUI_DB.cxaoeDebugFestering then
            print("|cffff8800cxUI:|r festering was active but no CDM frame matched on this rescan")
        end
    end
    if wasPutrefyActive and CXUI_DB[DB_PUTREFY] then
        putrefyWarningActive = true
        for _, ov in pairs(cdmPutrefyOverlays) do ShowXCross(ov) end
    end
    if wasReaperActive and CXUI_DB[DB_REAPER] then
        reaperWarningActive = true
        for _, ov in pairs(cdmReaperOverlays) do ShowXCross(ov) end
    end
end

local function DKRescan()
    ScanCDMOverlays()
    BuildFrostSwapFrames()
end

local function StartRetryLoop()
    for _, delay in ipairs({3, 6, 10, 15}) do
        C_Timer.After(delay, function() DKRescan() end)
    end
end

-- ---------------------------------------------------------------------------
-- Debug watchdog — only runs while CXUI_DB.cxaoeDebugFestering is true.
-- Catches cases where the glow visually vanishes WITHOUT any of our own
-- code running at all (e.g. Blizzard itself hiding/fading the underlying
-- CDM icon per its own Edit Mode display rules) — nothing else would ever
-- surface that, since no error/taint/rescan happens in that case.
-- ---------------------------------------------------------------------------

local festeringWatchdog = nil
local function EnsureFesteringWatchdog()
    if festeringWatchdog then return end
    festeringWatchdog = C_Timer.NewTicker(2, function()
        if not CXUI_DB.cxaoeDebugFestering then return end
        if not festeringGlowActive then return end
        for frame, ov in pairs(cdmFesteringOverlays) do
            local frameShown   = frame:IsShown()
            local frameVisible = frame:IsVisible()
            local ovShown      = ov:IsShown()
            if not frameShown or not frameVisible or not ovShown then
                print(string.format(
                    "|cffff0000cxUI WATCHDOG:|r festeringGlowActive=true but frame:IsShown()=%s frame:IsVisible()=%s ov:IsShown()=%s — nothing in our code touched it, likely Blizzard/CDM itself hid the icon",
                    tostring(frameShown), tostring(frameVisible), tostring(ovShown)))
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Register with Shared.lua hook system
-- ---------------------------------------------------------------------------

-- After user drags CDM icons, rescan so glows/crosses land on the right frame
CF.OnCDMReanchor(function() DKRescan() end)

-- Hard-reset Putrefy/Reaper warning state between arena rounds — CDM frames
-- get recreated across rounds and can otherwise leave a stale timer/overlay
-- association behind.
-- Festering glow is intentionally NOT touched here anymore: it should only
-- ever hide because of the hard condition (casting Festering Scythe, see
-- StartFesteringTimer), never because of combat/arena state.
CF.OnArenaReset(function()
    StopPutrefyWarning()
    StopReaperWarning()
end)

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local dkFrame = CreateFrame("Frame")
dkFrame:RegisterEvent("PLAYER_LOGIN")

dkFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, cid = UnitClass("player")
        if cid ~= 6 then self:UnregisterAllEvents(); return end
        -- PLAYER_REGEN_ENABLED is now handled by CF.OnArenaReset above;
        -- we still register it here for StopPutrefy/Reaper as a safety net.
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()
        EnsureFesteringWatchdog()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- CF.OnArenaReset handles StopPutrefy/Reaper on actual arena rounds;
        -- keep these here as an explicit safety net for non-arena scenarios.
        StopPutrefyWarning()
        StopReaperWarning()

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        HideFesteringGlow()
        StopPutrefyWarning()
        StopReaperWarning()
        C_Timer.After(2, function() DKRescan() end)

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
        local cf, cp, cs, cr = 0, 0, 0, 0
        for _ in pairs(cdmFesteringOverlays) do cf = cf + 1 end
        for _ in pairs(cdmPutrefyOverlays)   do cp = cp + 1 end
        for _ in ipairs(oblFrames)            do cs = cs + 1 end
        for _ in pairs(cdmReaperOverlays)     do cr = cr + 1 end
        print("|cff0070ddcxUI:|r festering=" .. cf
            .. "  putrefy=" .. cp .. "  frostswap=" .. cs .. "  reaper=" .. cr)
    elseif cmd == "status" then
        print("|cff0070ddcxUI:|r spec=" .. tostring(GetSpecialization())
            .. "  festering=" .. tostring(festeringGlowActive)
            .. "  putrefy=" .. tostring(putrefyWarningActive)
            .. "  reaper=" .. tostring(reaperWarningActive)
            .. "  barpage=" .. tostring(GetActionBarPage()))
        for frame, ov in pairs(cdmFesteringOverlays) do
            print(string.format(
                "  festering frame: IsShown=%s IsVisible=%s ov.IsShown=%s",
                tostring(frame:IsShown()), tostring(frame:IsVisible()), tostring(ov:IsShown())))
        end
    elseif cmd == "debug" then
        CXUI_DB.cxaoeDebugFestering = not CXUI_DB.cxaoeDebugFestering
        print("|cff0070ddcxUI:|r festering debug logging " .. (CXUI_DB.cxaoeDebugFestering and "ON" or "OFF"))
    else
        print("|cff0070ddcxUI:|r /cxaoe [scan|status|debug]")
    end
end