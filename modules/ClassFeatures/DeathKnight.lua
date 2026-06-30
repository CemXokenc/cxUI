local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: DEATH KNIGHT (classID 6)
-- Features: Festering Strike Glow, Putrefy Cross, Frost Bar Swap, Reaper Cross
-- ===========================================================================

local CF = ns.CF
if not CF or CF.CLASS_ID ~= 6 then return end

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
local SPELL_DARK_TRANSFORMATION = 1233448
local SPELL_OBLITERATE          = 49020
local SPELL_FROSTSCYTHE         = 207230

local FESTERING_DELAY  = 20
local PUTREFY_DELAY    = 36
local PUTREFY_DURATION = 9
local REAPER_DELAY     = 35
local REAPER_DURATION  = 10

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
        reaperWarningTimer = C_Timer.NewTimer(REAPER_DELAY, function()
            reaperWarningTimer = nil; ShowReaperWarning()
        end)
    end
end

-- ---------------------------------------------------------------------------
-- FROST BAR SWAP (cdmFrostBarSwap)
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

local UpdateFrostSwap

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

local function ScanCDMOverlays()
    for _, ov in pairs(cdmFesteringOverlays) do
        if ov._glowActive then StopGlow(ov) end
        ov:Hide()
    end
    wipe(cdmFesteringOverlays); festeringGlowActive = false

    for _, ov in pairs(cdmPutrefyOverlays) do ov:Hide() end
    wipe(cdmPutrefyOverlays); putrefyWarningActive = false

    for _, ov in pairs(cdmReaperOverlays) do ov:Hide() end
    wipe(cdmReaperOverlays); reaperWarningActive = false

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
                    local ov = CreateOverlay(frame); AttachXCross(ov)
                    cdmPutrefyOverlays[frame] = ov
                end
            elseif tex == TEX_REAPER then
                if not cdmReaperOverlays[frame] then
                    local ov = CreateOverlay(frame); AttachXCross(ov)
                    cdmReaperOverlays[frame] = ov
                end
            end
        end
    )
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
-- Event handler
-- ---------------------------------------------------------------------------

local dkFrame = CreateFrame("Frame")
dkFrame:RegisterEvent("PLAYER_LOGIN")

dkFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, cid = UnitClass("player")
        if cid ~= 6 then self:UnregisterAllEvents(); return end
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()

    elseif event == "PLAYER_REGEN_ENABLED" then
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
    else
        print("|cff0070ddcxUI:|r /cxaoe [scan|status]")
    end
end