local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: FESTERING STRIKE GLOW (Unholy Death Knight)
-- White glow on the Festering Strike CDM icon FESTERING_DELAY seconds after
-- Festering Scythe was cast (i.e. when the buff has <5s left).
-- Identification is by spellID (icon textures are secret values).
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmFesteringGlow",
    name  = "Festering Strike Glow — Unholy DK",
    desc  = "White glow on Festering Strike when the buff has <5s left.",
    class = "DEATHKNIGHT",
}

local SPELL_FESTERING_STRIKE = 85948
local SPELL_FESTERING_SCYTHE = 458128
local FESTERING_DELAY        = 20

local overlays   = {}
local timer      = nil
local glowActive = false
local watchdog   = nil

local function Debug(...)
    if CXUI_DB.cxaoeDebugFestering then print(...) end
end

local function HideGlow()
    if timer then timer:Cancel(); timer = nil end
    glowActive = false
    for _, ov in pairs(overlays) do CF.StopGlow(ov) end
    if CXUI_DB.cxaoeDebugFestering then
        print("|cffff8800cxUI:|r HideFesteringGlow() called - caller stack:")
        print(debugstack(2, 8, 0))
    end
end

local function ShowGlow()
    if not F:IsOn() or GetSpecialization() ~= 3 then return end
    glowActive = true
    for _, ov in pairs(overlays) do CF.StartGlow(ov) end
end

local function StartTimer()
    HideGlow()
    if not F:IsOn() or GetSpecialization() ~= 3 then return end
    timer = F:NewTimer(FESTERING_DELAY, function()
        timer = nil; ShowGlow()
    end)
end

-- Rebuilds the overlay frames (CDM icons get recreated / moved). Rebuilding is
-- bookkeeping, not a reason to hide anything: the visual state is restored.
local function Rescan()
    if not F:IsOn() then return end
    local wasActive = glowActive
    Debug(("|cff00ff00cxUI:|r ScanCDMOverlays() rebuild - wasFestering=%s"):format(tostring(wasActive)))

    for _, ov in pairs(overlays) do
        if ov._glowActive then CF.StopGlow(ov) end
        ov:Hide()
    end
    wipe(overlays); glowActive = false

    CF.ScanFramesBySpellID({ SPELL_FESTERING_STRIKE }, function(frame)
        if not overlays[frame] then overlays[frame] = CF.CreateOverlay(frame) end
    end)

    if wasActive and GetSpecialization() == 3 then
        glowActive = true
        if next(overlays) then
            for frame, ov in pairs(overlays) do
                CF.StartGlow(ov)
                Debug(string.format("|cff00ff00cxUI:|r festering restored - frame:IsShown()=%s frame:IsVisible()=%s ov:IsShown()=%s",
                    tostring(frame:IsShown()), tostring(frame:IsVisible()), tostring(ov:IsShown())))
            end
        else
            Debug("|cffff8800cxUI:|r festering was active but no CDM frame matched on this rescan")
        end
    end
end

-- Debug watchdog: only exists while `/cxaoe debug` is ON. Reports when the
-- glow vanishes without any cxUI code running (Blizzard/CDM hid the icon).
local function StopWatchdog()
    if watchdog then watchdog:Cancel(); watchdog = nil end
end

local function StartWatchdog()
    if watchdog then return end
    watchdog = F:NewTicker(2, function()
        if not glowActive then return end
        for frame, ov in pairs(overlays) do
            local frameShown, frameVisible, ovShown = frame:IsShown(), frame:IsVisible(), ov:IsShown()
            if not frameShown or not frameVisible or not ovShown then
                print(string.format("|cffff0000cxUI WATCHDOG:|r festeringGlowActive=true but frame:IsShown()=%s frame:IsVisible()=%s ov:IsShown()=%s - likely Blizzard/CDM itself hid the icon",
                    tostring(frameShown), tostring(frameVisible), tostring(ovShown)))
            end
        end
    end)
end

CF.OnDebugToggle(function(on)
    if not F:IsOn() then return end
    if on then StartWatchdog() else StopWatchdog() end
end)

CF.RegisterStatus(function()
    if not F:IsOn() then return nil end
    local n = 0
    for _ in pairs(overlays) do n = n + 1 end
    return ("festering=%s  frames=%d"):format(tostring(glowActive), n)
end)

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            HideGlow()
        elseif spellID == SPELL_FESTERING_SCYTHE then
            StartTimer()
        end
    end)

    CF.AddRescan("festering", Rescan)
    if CXUI_DB.cxaoeDebugFestering then StartWatchdog() end
end

function F:OnDisable()
    CF.RemoveRescan("festering")
    timer, watchdog = nil, nil -- cancelled by F:Silence()
    glowActive = false
    for _, ov in pairs(overlays) do CF.StopGlow(ov); ov:Hide() end
    wipe(overlays)
end
