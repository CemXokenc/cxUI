local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MODULE: MYTHIC+ -> EXTERNAL COOLDOWN ALERT
--
-- Plays a custom sound whenever an external defensive cooldown is cast on
-- you (Pain Suppression, Guardian Spirit, Blessing of Protection, etc.).
--
-- Two independent sources are watched, because either one may be the one
-- actually on screen depending on the user's settings:
--   1. Blizzard's native "External Cooldowns" Edit Mode frame
--      (ExternalDefensivesFrame.AuraContainer).
--   2. EllesmereUIUnitFrames' own standalone "External Defensives" display
--      (global frame "EUF_ExternalDefensives"), used when the Blizzard one
--      is turned off in Edit Mode and Ellesmere's own is enabled instead.
-- Detection hooks OnShow on whichever icon frames actually exist, rather
-- than tracking specific spell IDs, so it covers everything either system
-- already classifies as an external.
-- ---------------------------------------------------------------------------

local EXTERNAL_ALERT_SOUND = "Interface\\AddOns\\cxUI\\media\\moan.ogg"

local function IsEnabled()
    return CXUI_DB and CXUI_DB.externalAlertSound
end

local function PlayExternalAlertSound()
    if not IsEnabled() then return end
    PlaySoundFile(EXTERNAL_ALERT_SOUND, "Master")
end

-- Track which aura frames we've already hooked (weak-keyed so frames can
-- still be garbage collected if either addon ever recycles them).
local hookedAuras = setmetatable({}, { __mode = "k" })
local loginGracePeriod = true -- suppress alerts briefly right after login/reload

local function IsInEditMode()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

local function HookAuraFrame(aura)
    if hookedAuras[aura] then return end
    hookedAuras[aura] = true
    aura:HookScript("OnShow", function()
        if not loginGracePeriod and not IsInEditMode() then
            PlayExternalAlertSound()
        end
    end)
end

-- Source 1: Blizzard's native External Cooldowns Edit Mode frame
local function ScanBlizzardExternals()
    local container = ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer
    if not container then return end
    for i = 1, select('#', container:GetChildren()) do
        local child = select(i, container:GetChildren())
        if child then HookAuraFrame(child) end
    end
end

-- Source 2: EllesmereUI's own standalone External Defensives frame
local function ScanEllesmereExternals()
    local root = _G.EUF_ExternalDefensives
    if not root then return end
    for i = 1, select('#', root:GetChildren()) do
        local child = select(i, root:GetChildren())
        if child then HookAuraFrame(child) end
    end
end

-- Hook Blizzard's AuraContainer so new children get caught the moment they
-- appear (once). Ellesmere's own root has no equivalent public hook point
-- for "new child button created", so its buttons are instead picked up by
-- the periodic UNIT_AURA rescan below -- cheap, since it's at most a
-- handful of buttons.
local blizzContainerHooked = false
local function TryHookBlizzardContainer()
    if blizzContainerHooked then return end
    local container = ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer
    if not container then return end
    blizzContainerHooked = true
    hooksecurefunc(container, "SetShown", ScanBlizzardExternals)
    container:HookScript("OnShow", ScanBlizzardExternals)
end

local function ScanAll()
    TryHookBlizzardContainer()
    ScanBlizzardExternals()
    ScanEllesmereExternals()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterUnitEvent("UNIT_AURA", "player")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Allow alerts after a short grace period so login frame-init
        -- doesn't trigger a sound the moment frames are first created.
        C_Timer.After(3, function() loginGracePeriod = false end)
    end
    ScanAll()
end)
