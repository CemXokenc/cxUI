local addonName, ns = ...

-- ===========================================================================
-- MODULE: CLASS FEATURES
-- Supported: Death Knight (6) · Mage (8)
-- Frame scanning: EnumerateFrames() — exact port of DKAssist approach.
-- Overlays parented directly to the found CDM frame (not UIParent).
-- Glow: LibCustomGlow-1.0 (ButtonGlow).
-- ===========================================================================

local _, _, CLASS_ID = UnitClass("player")
if CLASS_ID ~= 6 and CLASS_ID ~= 8 then return end

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- ---------------------------------------------------------------------------
-- EnumerateFrames scan — exact port of DKAssist CreateCDMOverlays.
-- Scans ALL game frames, matches by texture string ID.
-- Overlay is CreateFrame(nil, foundFrame) so it moves with it.
-- ---------------------------------------------------------------------------
local function ScanFramesByTexture(texStrings, callback)
    local frame = EnumerateFrames()
    while frame do
        if frame.Icon and type(frame.Icon) == "table" and frame.Icon.GetTexture then
            local ok, matched = pcall(function()
                local tex = frame.Icon:GetTexture()
                if tex then
                    local texStr = tostring(tex)
                    for _, t in ipairs(texStrings) do
                        if texStr == t then return true end
                    end
                end
                return false
            end)
            if ok and matched then
                callback(frame)
            end
        end
        frame = EnumerateFrames(frame)
    end
end

-- Create an overlay parented directly to the CDM frame (moves with it)
local function CreateOverlay(cdmFrame)
    local ov = CreateFrame("Frame", nil, cdmFrame)
    ov:SetFrameStrata("HIGH")
    ov:SetAllPoints(cdmFrame)
    ov:SetFrameLevel(cdmFrame:GetFrameLevel() + 10)
    ov._targetFrame = cdmFrame
    ov._glowActive  = false
    ov:Hide()
    return ov
end

-- ---------------------------------------------------------------------------
-- Glow: ButtonGlow via LCG (white, classic proc glow)
-- ---------------------------------------------------------------------------
local GLOW_COLOR = {1, 1, 1, 1}  -- white

local function StartGlow(overlay)
    if overlay._glowActive then return end
    overlay._glowActive = true
    overlay:Show()
    if LCG and LCG.ButtonGlow_Start then
        LCG.ButtonGlow_Start(overlay, GLOW_COLOR, 0.4)
    end
end

local function StopGlow(overlay)
    if not overlay._glowActive then return end
    overlay._glowActive = false
    if LCG and LCG.ButtonGlow_Stop then
        LCG.ButtonGlow_Stop(overlay)
    end
    overlay:Hide()
end

-- ---------------------------------------------------------------------------
-- X-cross: two diagonal lines via SetRotation (user wants × not +)
-- ---------------------------------------------------------------------------
local X_THICK = 5  -- px

local function AttachXCross(overlay)
    if overlay._xl1 then return end
    local l1 = overlay:CreateTexture(nil, "OVERLAY")
    l1:SetColorTexture(1, 0, 0, 0.9)
    l1:SetPoint("CENTER", overlay, "CENTER")
    overlay._xl1 = l1

    local l2 = overlay:CreateTexture(nil, "OVERLAY")
    l2:SetColorTexture(1, 0, 0, 0.9)
    l2:SetPoint("CENTER", overlay, "CENTER")
    overlay._xl2 = l2

    local function ApplySize()
        local w, h = overlay:GetSize()
        if not w or w < 4 then return end
        local diag  = math.sqrt(w * w + h * h)
        local angle = math.atan(h / w)
        l1:SetSize(diag, X_THICK); l1:SetRotation( angle)
        l2:SetSize(diag, X_THICK); l2:SetRotation(-angle)
    end
    overlay:SetScript("OnSizeChanged", function() ApplySize() end)
    ApplySize()
end

local function ShowXCross(overlay)
    AttachXCross(overlay)
    if overlay._xl1 then overlay._xl1:Show(); overlay._xl2:Show() end
    overlay:Show()
end

local function HideXCross(overlay)
    if overlay._xl1 then overlay._xl1:Hide(); overlay._xl2:Hide() end
    overlay:Hide()
end


-- ===========================================================================
-- DEATH KNIGHT (classID 6)
-- ===========================================================================
if CLASS_ID == 6 then

-- Texture string IDs (from DKAssist — tostring of file ID)
local TEX_FESTERING_SCYTHE = "3997563"   -- Festering Scythe (458128)
local TEX_FESTERING_STRIKE = "879926"    -- Festering Strike (85948)
local TEX_PUTREFY          = "7439191"   -- Putrefy (1247378)

local SPELL_FESTERING_SCYTHE    = 458128
local SPELL_FESTERING_STRIKE    = 85948
local SPELL_DARK_TRANSFORMATION = 1233448

-- Festering: 25s buff, warn at 5s → 20s delay (DKAssist default)
local FESTERING_DELAY = 20

-- Putrefy: user wants 9s warning. DT CD ~45s → 36s delay, 9s duration
local PUTREFY_DELAY    = 36
local PUTREFY_DURATION = 9

-- ---- Enemy Counter (cdmEnemyCounter) ---------------------------------------
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

-- Counter uses UIParent-parented frames (safe, proven working)
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
        if f.Cooldown then  -- CDM button identifier
            counterFrames[f] = true
            GetOrCreateCounter(f)
        end
    end)
end

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

-- ---- Festering Strike glow (cdmFesteringGlow) ------------------------------
-- Exact port of DKAssist: on Festering cast → 20s timer → ButtonGlow on overlay.
local DB_FESTERING = "cdmFesteringGlow"

local cdmFesteringOverlays = {}
local festeringTimer       = nil
local festeringGlowActive  = false

local function CreateFesteringCDMOverlays()
    -- Clean up old overlays
    for _, ov in pairs(cdmFesteringOverlays) do
        if ov._glowActive and LCG and LCG.ButtonGlow_Stop then
            LCG.ButtonGlow_Stop(ov)
        end
        ov:Hide()
    end
    wipe(cdmFesteringOverlays)
    festeringGlowActive = false

    ScanFramesByTexture(
        {TEX_FESTERING_SCYTHE, TEX_FESTERING_STRIKE},
        function(frame)
            if not cdmFesteringOverlays[frame] then
                cdmFesteringOverlays[frame] = CreateOverlay(frame)
            end
        end
    )
end

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
        festeringTimer = nil
        ShowFesteringGlow()
    end)
end

-- ---- Putrefy cross (cdmPutrefyCross) ----------------------------------------
-- Exact port of DKAssist: DT cast → 36s → show × for 9s.
local DB_PUTREFY = "cdmPutrefyCross"

local cdmPutrefyOverlays   = {}
local putrefyWarningActive = false
local putrefyWarningTimer  = nil
local putrefyDurationTimer = nil

local function CreatePutrefyCDMOverlays()
    for _, ov in pairs(cdmPutrefyOverlays) do ov:Hide() end
    wipe(cdmPutrefyOverlays)
    putrefyWarningActive = false

    ScanFramesByTexture({TEX_PUTREFY}, function(frame)
        if not cdmPutrefyOverlays[frame] then
            local ov = CreateOverlay(frame)
            AttachXCross(ov)
            cdmPutrefyOverlays[frame] = ov
        end
    end)
end

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
        putrefyDurationTimer = nil
        StopPutrefyWarning()
    end)
end

local function OnDarkTransformationCast()
    if putrefyWarningTimer  then putrefyWarningTimer:Cancel();  putrefyWarningTimer  = nil end
    if putrefyDurationTimer then putrefyDurationTimer:Cancel(); putrefyDurationTimer = nil end
    putrefyWarningActive = false
    for _, ov in pairs(cdmPutrefyOverlays) do HideXCross(ov) end
    if not CXUI_DB[DB_PUTREFY] then return end
    putrefyWarningTimer = C_Timer.NewTimer(PUTREFY_DELAY, function()
        putrefyWarningTimer = nil
        ShowPutrefyWarning()
    end)
end

-- ---- DK full rescan ---------------------------------------------------------
local function DKRescan()
    RescanCounterFrames()
    CreateFesteringCDMOverlays()
    CreatePutrefyCDMOverlays()
end

-- Retry delays matching DKAssist (3, 6, 10, 15 seconds)
local function StartRetryLoop()
    local delays = {3, 6, 10, 15}
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function() DKRescan() end)
    end
end

-- ---- DK event handler -------------------------------------------------------
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
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()

    elseif event == "PLAYER_REGEN_DISABLED" then
        if CXUI_DB[DB_COUNTER] then Counter:StartTicker(); UpdateCounter() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        Counter:StopTicker()
        StopPutrefyWarning()

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() DKRescan() end)
        StartRetryLoop()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        Counter:StopTicker()
        HideFesteringGlow()
        StopPutrefyWarning()
        StopNpTracker(); StartNpTracker()
        C_Timer.After(2, function() DKRescan() end)

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") and CXUI_DB[DB_COUNTER] then UpdateCounter() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == SPELL_FESTERING_SCYTHE then  -- 458128 only triggers timer
            StartFesteringTimer()
        elseif spellID == SPELL_DARK_TRANSFORMATION then
            OnDarkTransformationCast()
        end
    end
end)

SLASH_CXAOEDEBUG1 = "/cxaoe"
SlashCmdList["CXAOEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" then
        DKRescan()
        local cf, cp = 0, 0
        for _ in pairs(cdmFesteringOverlays) do cf = cf + 1 end
        for _ in pairs(cdmPutrefyOverlays)   do cp = cp + 1 end
        print("|cff0070ddcxUI:|r counter=" .. (function() local n=0; for _ in pairs(counterFrames) do n=n+1 end; return n end)()
            .. "  festering=" .. cf .. "  putrefy=" .. cp)
    elseif cmd == "status" then
        local count = GetEnemyCount()
        local npCount = 0; for _ in pairs(npActive) do npCount = npCount + 1 end
        print("|cff0070ddcxUI:|r spec=" .. tostring(GetSpecialization())
            .. "  enemies=" .. count .. "  npActive=" .. npCount
            .. "  festering=" .. tostring(festeringGlowActive)
            .. "  putrefy=" .. tostring(putrefyWarningActive))
    else print("|cff0070ddcxUI:|r /cxaoe [scan|status]") end
end

end  -- CLASS_ID == 6


-- ===========================================================================
-- MAGE (classID 8)
-- ===========================================================================
if CLASS_ID == 8 then

local SPELL_FLURRY   = 44614
local SPELL_ICE_LANCE = 30455
local CROSS_DURATION  = 6   -- seconds

-- Flurry texture string — computed at load time
local flurryTexStr = nil
local function GetFlurryTexStr()
    if flurryTexStr then return flurryTexStr end
    local t = C_Spell.GetSpellTexture(SPELL_FLURRY)
    if t then flurryTexStr = tostring(t) end
    return flurryTexStr
end

local DB_FLURRY = "cdmFlurryCross"

local cdmFlurryOverlays = {}
local flurryCrossActive = false
local flurryTimer       = nil

local function CreateFlurryCDMOverlays()
    for _, ov in pairs(cdmFlurryOverlays) do ov:Hide() end
    wipe(cdmFlurryOverlays)
    flurryCrossActive = false
    local texStr = GetFlurryTexStr()
    if not texStr then return end
    ScanFramesByTexture({texStr}, function(frame)
        if not cdmFlurryOverlays[frame] then
            local ov = CreateOverlay(frame)
            AttachXCross(ov)
            cdmFlurryOverlays[frame] = ov
        end
    end)
end

local function HideFlurryCross()
    if flurryTimer then flurryTimer:Cancel(); flurryTimer = nil end
    flurryCrossActive = false
    for _, ov in pairs(cdmFlurryOverlays) do HideXCross(ov) end
end

local function ShowFlurryCross()
    if not CXUI_DB[DB_FLURRY] then return end
    if flurryTimer then flurryTimer:Cancel() end
    flurryCrossActive = true
    for _, ov in pairs(cdmFlurryOverlays) do ShowXCross(ov) end
    flurryTimer = C_Timer.NewTimer(CROSS_DURATION, function()
        flurryTimer = nil; HideFlurryCross()
    end)
end

local function StartMageRetryLoop()
    local delays = {3, 6, 10, 15}
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function() CreateFlurryCDMOverlays() end)
    end
end

local mageFrame = CreateFrame("Frame")
mageFrame:RegisterEvent("PLAYER_LOGIN")

mageFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, cid = UnitClass("player")
        if cid ~= 8 then self:UnregisterAllEvents(); return end
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.After(1, function() CreateFlurryCDMOverlays() end)
        StartMageRetryLoop()

    elseif event == "PLAYER_REGEN_ENABLED" then
        HideFlurryCross()

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() CreateFlurryCDMOverlays() end)
        StartMageRetryLoop()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        HideFlurryCross()
        C_Timer.After(2, function() CreateFlurryCDMOverlays() end)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == SPELL_FLURRY then
            ShowFlurryCross()
        elseif spellID == SPELL_ICE_LANCE then
            HideFlurryCross()
        end
    end
end)

SLASH_CXMAGEDEBUG1 = "/cxmage"
SlashCmdList["CXMAGEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" then
        CreateFlurryCDMOverlays()
        local n = 0; for _ in pairs(cdmFlurryOverlays) do n = n + 1 end
        print("|cff0070ddcxUI Mage:|r flurry_frames=" .. n
            .. "  texStr=" .. tostring(flurryTexStr)
            .. "  active=" .. tostring(flurryCrossActive))
    elseif cmd == "force" then
        ShowFlurryCross()
        local n = 0; for _ in pairs(cdmFlurryOverlays) do n = n + 1 end
        print("|cff0070ddcxUI Mage:|r forced cross on " .. n .. " overlay(s)")
    else
        print("|cff0070ddcxUI Mage:|r /cxmage [scan|force]")
    end
end

end  -- CLASS_ID == 8