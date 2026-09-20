local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: REAPER CROSS (Unholy Death Knight)
-- Red X on the Soul Reaper CDM icon for REAPER_DURATION seconds right after
-- Dark Transformation is cast.
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmReaperCross",
    name  = "Reaper Cross — Unholy DK",
    desc  = "Red x on Reaper CDM for 6s right after Dark Transformation is cast.",
    class = "DEATHKNIGHT",
}

local SPELL_REAPER              = 343294 -- Soul Reaper
local SPELL_DARK_TRANSFORMATION = 1233448
local REAPER_DURATION           = 6

local overlays      = {}
local warningActive = false
local durationTimer = nil

local function Stop()
    warningActive = false
    if durationTimer then durationTimer:Cancel(); durationTimer = nil end
    for _, ov in pairs(overlays) do CF.HideXCross(ov) end
end

local function Show()
    if durationTimer then durationTimer:Cancel(); durationTimer = nil end
    warningActive = true
    for _, ov in pairs(overlays) do CF.ShowXCross(ov) end
    durationTimer = F:NewTimer(REAPER_DURATION, function()
        durationTimer = nil; Stop()
    end)
end

local function Rescan()
    if not F:IsOn() then return end
    local wasActive = warningActive
    for _, ov in pairs(overlays) do ov:Hide() end
    wipe(overlays); warningActive = false

    CF.ScanFramesBySpellID({ SPELL_REAPER }, function(frame)
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
    return ("reaper=%s  frames=%d"):format(tostring(warningActive), n)
end)

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if spellID == SPELL_DARK_TRANSFORMATION then Stop(); Show() end
        else
            Stop() -- combat ended / spec changed
        end
    end)
    CF.AddRescan("reaper", Rescan)
end

function F:OnDisable()
    CF.RemoveRescan("reaper")
    durationTimer = nil -- cancelled by F:Silence()
    warningActive = false
    for _, ov in pairs(overlays) do CF.HideXCross(ov) end
    wipe(overlays)
end
