local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MYTHIC+: EXTERNAL COOLDOWN ALERT
--
-- Plays a custom sound whenever an external defensive cooldown is cast on
-- you. Watches TWO independent sources simultaneously and reacts to
-- whichever one is actually active (no reload needed to switch between them):
--
--   1. Blizzard's native "External Cooldowns" Edit Mode frame
--      (ExternalDefensivesFrame.AuraContainer).
--   2. EllesmereUIUnitFrames' own standalone "External Defensives" display
--      (global frame "EUF_ExternalDefensives").
--
-- DETECTION STRATEGY: rather than hooking OnShow on each icon button (which
-- can race), every known icon's :IsShown() state is polled on a short timer;
-- an alert fires on the false -> true transition.
--
-- The two timers exist ONLY while the option is on.
-- ---------------------------------------------------------------------------

local MP = ns:GetModule("MythicPlus")

local F = MP:NewFeature{
    key  = "externalAlertSound",
    name = "External Cooldown Alert",
    desc = "Plays a sound whenever an external defensive (Pain Suppression, Guardian Spirit, etc.) is cast on you.",
}

local POLL_INTERVAL   = 0.2 -- how often to check for newly-shown icons
local RESCAN_INTERVAL = 2.0 -- how often to look for newly-created icon buttons

CXUI_ExternalAlertDebug = CXUI_ExternalAlertDebug or false
local function Debug(...)
    if CXUI_ExternalAlertDebug then
        print("|cff33ccff[cxUI ExternalAlert]|r", ...)
    end
end

local loginGracePeriod = true

local function PlayExternalAlertSound(source, frame)
    Debug("Trigger from", source, frame and (frame:GetName() or "(unnamed)") or "?")
    if MP.IsInEditMode() then
        Debug("  -> suppressed: in Edit Mode")
        return
    end
    local willPlay, handle = MP.PlayFile(ns.Media("ExternalAlert", "moan.ogg"))
    Debug("  -> PlaySoundFile ->", willPlay, handle)
end

-- frame -> { shown = bool, source = "blizzard"/"ellesmere" } (weak keys)
local tracked = setmetatable({}, { __mode = "k" })

local function RegisterFrame(frame, source)
    if tracked[frame] then return end
    -- Capture current state WITHOUT alerting: only future transitions matter.
    local shownNow = frame:IsShown()
    tracked[frame] = { shown = shownNow, source = source }
    Debug("Registered", source, "icon", frame:GetName() or "(unnamed)", "initial shown =", shownNow)
end

local function ScanChildrenInto(root, source)
    if not root then return false end
    local n = select('#', root:GetChildren())
    if n == 0 then return true end
    local kids = { root:GetChildren() }
    for i = 1, n do
        if kids[i] then RegisterFrame(kids[i], source) end
    end
    return true
end

local blizzardAvailable, ellesmereAvailable = false, false

local function ScanBlizzardExternals()
    local container = ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer
    blizzardAvailable = ScanChildrenInto(container, "blizzard")
end

local function ScanEllesmereExternals()
    ellesmereAvailable = ScanChildrenInto(_G.EUF_ExternalDefensives, "ellesmere")
end

local function TryHookBlizzardContainer()
    local container = ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer
    if not container then return end
    F:Hook(container, "SetShown", ScanBlizzardExternals)
    F:HookScript(container, "OnShow", ScanBlizzardExternals)
end

local function ScanAll()
    TryHookBlizzardContainer()
    ScanBlizzardExternals()
    ScanEllesmereExternals()
end

-- Edge-detect false -> true on every tracked icon.
local function PollTrackedFrames()
    if loginGracePeriod then return end
    for frame, state in pairs(tracked) do
        local nowShown = frame:IsShown()
        if nowShown and not state.shown then
            PlayExternalAlertSound(state.source, frame)
        end
        state.shown = nowShown
    end
end

local function StartGracePeriod()
    loginGracePeriod = true
    F:After(3, function()
        loginGracePeriod = false
        Debug("Login grace period ended")
    end)
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterUnitEvent("UNIT_AURA", "player")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then StartGracePeriod() end
        ScanAll()
    end)

    self:NewTicker(POLL_INTERVAL, PollTrackedFrames)
    self:NewTicker(RESCAN_INTERVAL, ScanAll) -- catches icons created without a UNIT_AURA firing

    StartGracePeriod()
    ScanAll()
end

function F:OnDisable()
    wipe(tracked)
end

SLASH_CXEXTERNAL1 = "/cxexternal"
SlashCmdList["CXEXTERNAL"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        CXUI_ExternalAlertDebug = not CXUI_ExternalAlertDebug
        print("|cff33ccff[cxUI ExternalAlert]|r debug", CXUI_ExternalAlertDebug and "ON" or "OFF")
    elseif msg == "scan" then
        print("|cff33ccff[cxUI ExternalAlert]|r forcing rescan...")
        if F:IsOn() then ScanAll() end
    elseif msg == "status" then
        local blizzCount, elleCount = 0, 0
        for _, state in pairs(tracked) do
            if state.source == "blizzard" then blizzCount = blizzCount + 1
            else elleCount = elleCount + 1 end
        end
        print("|cff33ccff[cxUI ExternalAlert]|r enabled:", F:IsOn() and "yes" or "no")
        print("  Blizzard source available:", tostring(blizzardAvailable), "| tracked icons:", blizzCount)
        print("  Ellesmere source available:", tostring(ellesmereAvailable), "| tracked icons:", elleCount)
    else
        print("|cff33ccff[cxUI ExternalAlert]|r usage: /cxexternal debug | scan | status")
    end
end
