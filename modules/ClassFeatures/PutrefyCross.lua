local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: PUTREFY CROSS (Unholy Death Knight)
-- Red X on the Putrefy CDM icon for PUTREFY_DURATION seconds, starting
-- PUTREFY_DELAY seconds after Dark Transformation was cast (its CD <9s).
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmPutrefyCross",
    name  = "Putrefy Cross — Unholy DK",
    desc  = "Red x on Putrefy CDM when Dark Transformation has <9s CD.",
    class = "DEATHKNIGHT",
}

local SPELL_PUTREFY          = 1247378
local SPELL_DARK_TRANSFORMATION = 1233448
local PUTREFY_DELAY, PUTREFY_DURATION = 36, 9

local overlays       = {}
local warningActive  = false
local warningTimer   = nil
local durationTimer  = nil

local function Stop()
    warningActive = false
    if warningTimer  then warningTimer:Cancel();  warningTimer  = nil end
    if durationTimer then durationTimer:Cancel(); durationTimer = nil end
    for _, ov in pairs(overlays) do CF.HideXCross(ov) end
end

local function Show()
    if durationTimer then durationTimer:Cancel(); durationTimer = nil end
    warningActive = true
    for _, ov in pairs(overlays) do CF.ShowXCross(ov) end
    durationTimer = F:NewTimer(PUTREFY_DURATION, function()
        durationTimer = nil; Stop()
    end)
end

local function OnDarkTransformation()
    Stop()
    warningTimer = F:NewTimer(PUTREFY_DELAY, function()
        warningTimer = nil; Show()
    end)
end

local function Rescan()
    if not F:IsOn() then return end
    local wasActive = warningActive
    for _, ov in pairs(overlays) do ov:Hide() end
    wipe(overlays); warningActive = false

    CF.ScanFramesBySpellID({ SPELL_PUTREFY }, function(frame)
        if not overlays[frame] then
            local ov = CF.CreateOverlay(frame); CF.AttachXCross(ov)
            overlays[frame] = ov
        end
    end)

    if wasActive then
        warningActive = true
        for _, ov in pairs(overlays) do CF.ShowXCross(ov) end
    end
end

CF.RegisterStatus(function()
    if not F:IsOn() then return nil end
    local n = 0
    for _ in pairs(overlays) do n = n + 1 end
    return ("putrefy=%s  frames=%d"):format(tostring(warningActive), n)
end)

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if spellID == SPELL_DARK_TRANSFORMATION then OnDarkTransformation() end
        else
            Stop() -- combat ended / spec changed
        end
    end)
    CF.AddRescan("putrefy", Rescan)
end

function F:OnDisable()
    CF.RemoveRescan("putrefy")
    warningTimer, durationTimer = nil, nil -- cancelled by F:Silence()
    warningActive = false
    for _, ov in pairs(overlays) do CF.HideXCross(ov) end
    wipe(overlays)
end
