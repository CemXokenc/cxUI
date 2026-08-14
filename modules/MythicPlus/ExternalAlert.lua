local addonName, ns = ...
-- ---------------------------------------------------------------------------
-- MODULE: MYTHIC+ -> EXTERNAL COOLDOWN ALERT
--
-- Plays a custom sound whenever an external defensive cooldown is cast on
-- you. Watches TWO independent sources simultaneously and reacts to
-- whichever one is actually active -- no reload needed if you toggle
-- between them in Edit Mode / EllesmereUI settings mid-session:
--
--   1. Blizzard's native "External Cooldowns" Edit Mode frame
--      (ExternalDefensivesFrame.AuraContainer).
--   2. EllesmereUIUnitFrames' own standalone "External Defensives" display
--      (global frame "EUF_ExternalDefensives").
--
-- DETECTION STRATEGY: rather than hooking OnShow on each icon button (which
-- can race -- a button can appear and fire OnShow in the same instant it's
-- first discovered, before the hook is installed, silently swallowing the
-- alert), we track every known icon's :IsShown() state and poll it on a
-- short timer. An alert fires on the false -> true transition. This is
-- immune to hook-install timing and works identically for both sources.
-- ---------------------------------------------------------------------------
local EXTERNAL_ALERT_SOUND = "Interface\\AddOns\\cxUI\\media\\moan.ogg"
local POLL_INTERVAL = 0.2   -- how often to check for newly-shown icons
local RESCAN_INTERVAL = 2.0 -- how often to look for newly-created icon buttons

CXUI_ExternalAlertDebug = CXUI_ExternalAlertDebug or false
local function Debug(...)
    if CXUI_ExternalAlertDebug then
        print("|cff33ccff[cxUI ExternalAlert]|r", ...)
    end
end

local function IsEnabled()
    return CXUI_DB and CXUI_DB.externalAlertSound
end

local function IsInEditMode()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

local loginGracePeriod = true

local function PlayExternalAlertSound(source, frame)
    Debug("Trigger from", source, frame and (frame:GetName() or "(unnamed)") or "?")
    if not IsEnabled() then
        Debug("  -> suppressed: externalAlertSound is OFF")
        return
    end
    if IsInEditMode() then
        Debug("  -> suppressed: in Edit Mode")
        return
    end
    local willPlay, handle = PlaySoundFile(EXTERNAL_ALERT_SOUND, "Master")
    Debug("  -> PlaySoundFile ->", willPlay, handle)
end

-- ---------------------------------------------------------------------------
-- Tracked icon registry: frame -> { shown = bool, source = "blizzard"/"ellesmere" }
-- Weak-keyed so recycled/destroyed buttons can be collected.
-- ---------------------------------------------------------------------------
local tracked = setmetatable({}, { __mode = "k" })

local function RegisterFrame(frame, source)
    if tracked[frame] then return end
    -- Capture current state WITHOUT alerting -- we only care about future
    -- transitions, not whatever was already on screen when we found it.
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

local blizzContainerHooked = false
local function TryHookBlizzardContainer()
    if blizzContainerHooked then return end
    local container = ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer
    if not container then return end
    blizzContainerHooked = true
    Debug("Blizzard AuraContainer found, installing SetShown/OnShow hooks")
    hooksecurefunc(container, "SetShown", ScanBlizzardExternals)
    container:HookScript("OnShow", ScanBlizzardExternals)
end

local function ScanAll()
    TryHookBlizzardContainer()
    ScanBlizzardExternals()
    ScanEllesmereExternals()
end

-- ---------------------------------------------------------------------------
-- Poll: edge-detect false -> true on every tracked icon, regardless of
-- which source it came from or when it was registered.
-- ---------------------------------------------------------------------------
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

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterUnitEvent("UNIT_AURA", "player")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, function()
            loginGracePeriod = false
            Debug("Login grace period ended")
        end)
    end
    ScanAll()
end)

C_Timer.NewTicker(POLL_INTERVAL, PollTrackedFrames)
C_Timer.NewTicker(RESCAN_INTERVAL, ScanAll) -- catches icons created without a UNIT_AURA firing

SLASH_CXEXTERNAL1 = "/cxexternal"
SlashCmdList["CXEXTERNAL"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        CXUI_ExternalAlertDebug = not CXUI_ExternalAlertDebug
        print("|cff33ccff[cxUI ExternalAlert]|r debug", CXUI_ExternalAlertDebug and "ON" or "OFF")
    elseif msg == "scan" then
        print("|cff33ccff[cxUI ExternalAlert]|r forcing rescan...")
        ScanAll()
    elseif msg == "status" then
        local blizzCount, elleCount = 0, 0
        for _, state in pairs(tracked) do
            if state.source == "blizzard" then blizzCount = blizzCount + 1
            else elleCount = elleCount + 1 end
        end
        print("|cff33ccff[cxUI ExternalAlert]|r enabled:", IsEnabled() and "yes" or "no")
        print("  Blizzard source available:", tostring(blizzardAvailable), "| tracked icons:", blizzCount)
        print("  Ellesmere source available:", tostring(ellesmereAvailable), "| tracked icons:", elleCount)
    else
        print("|cff33ccff[cxUI ExternalAlert]|r usage: /cxexternal debug | scan | status")
    end
end