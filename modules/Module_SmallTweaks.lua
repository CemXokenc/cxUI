local addonName, ns = ...

-- ===========================================================================
-- MODULE: SMALL TWEAKS
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- HIDE ALERTS (Talent Notifications)
-- ---------------------------------------------------------------------------

local helpTipShowHooked = false

local function HideAllHelpTips(owner, info)
    if not CXUI_DB.hideAlerts then return end
    if HelpTip then
        if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
        if HelpTip.HideAll then HelpTip:HideAll(owner or UIParent) end
        if HelpTip.Hide and info and info.text then HelpTip:Hide(owner, info.text) end
    end
end

local function EnsureHelpTipHooks()
    if helpTipShowHooked then return end
    if not HelpTip then return end
    hooksecurefunc(HelpTip, "Show", function(_, owner, info)
        HideAllHelpTips(owner, info)
    end)
    helpTipShowHooked = true
end

local function InitHideAlerts()
    if not CXUI_DB.hideAlerts then return end
    EnsureHelpTipHooks()
    HideAllHelpTips(UIParent, nil)
end

local testFrame = CreateFrame("Frame")
testFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
testFrame:RegisterEvent("ADDON_LOADED")
testFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, InitHideAlerts)
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HelpTip" then
        if CXUI_DB.hideAlerts then
            EnsureHelpTipHooks()
            HideAllHelpTips(UIParent, nil)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- MEGA MACRO OVERRIDE
-- ---------------------------------------------------------------------------

local function OpenMegaMacro()
    if MegaMacroWindow and MegaMacroWindow.Show then
        MegaMacroWindow.Show()
    end
    if not InCombatLockdown() then
        if MacroFrame and MacroFrame:IsShown() then HideUIPanel(MacroFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    end
end

hooksecurefunc("ShowMacroFrame", function()
    if CXUI_DB and CXUI_DB.overrideMacroFrame then OpenMegaMacro() end
end)

if GameMenuButtonMacros then
    GameMenuButtonMacros:SetScript("OnClick", function()
        if CXUI_DB and CXUI_DB.overrideMacroFrame then
            OpenMegaMacro()
        else
            ShowMacroFrame()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- AUDIO ALERTS
-- Plays ready check sound through the Master channel
-- ---------------------------------------------------------------------------

local function OnReadyCheck()
    if not CXUI_DB.altTabAlerts then return end
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
end

-- ---------------------------------------------------------------------------
-- GROUP INVITE SOUND
-- Same sound as dungeon finder queue pop, plays through Master.
-- ---------------------------------------------------------------------------

local function OnGroupInvite()
    if not CXUI_DB.inviteSound then return end
    -- LFG_QUEUE_STARTED = the "dungeon found" alarm sound
    PlaySound(SOUNDKIT.LFG_QUEUE_STARTED or SOUNDKIT.READY_CHECK, "Master")
end

-- ---------------------------------------------------------------------------
-- PULL TIMER COUNTDOWN
-- Plays SharedMedia_Causese sounds at 10, 5, 3, 2, 1 seconds remaining.
-- Falls back to SOUNDKIT.READY_CHECK if LibSharedMedia is unavailable.
--
-- Sound names map directly to filenames in SharedMedia_Causese/sound/:
--   [10] = "10", [5] = "5", [3] = "3", [2] = "2", [1] = "1"
-- Change the names here if your SharedMedia addon uses different keys.
-- ---------------------------------------------------------------------------

local PULL_COUNTDOWN_MARKS = { 10, 5, 3, 2, 1 }

local PULL_SOUND_NAMES = {
    [10] = "10",
    [5]  = "5",
    [3]  = "3",
    [2]  = "2",
    [1]  = "1",
}

local function PlayCountdownSound(mark)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local name = PULL_SOUND_NAMES[mark]
        local path = name and LSM:Fetch("sound", name)
        if path then
            PlaySoundFile(path, "Master")
            return
        end
    end
    -- Fallback if SharedMedia not available or sound not found
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
end

local pullCountdownGen = 0

local function SchedulePullCountdown(secondsRemaining)
    pullCountdownGen = pullCountdownGen + 1
    local gen = pullCountdownGen

    for _, mark in ipairs(PULL_COUNTDOWN_MARKS) do
        local delay = secondsRemaining - mark
        if delay >= 0 then
            C_Timer.After(delay, function()
                if gen ~= pullCountdownGen then return end
                if not CXUI_DB.pullTimerSound then return end
                PlayCountdownSound(mark)
            end)
        end
    end
end

local function CancelPullCountdown()
    pullCountdownGen = pullCountdownGen + 1
end

-- ---------------------------------------------------------------------------
-- EVENT HANDLER
-- ---------------------------------------------------------------------------

local tweaksFrame = CreateFrame("Frame")
tweaksFrame:RegisterEvent("READY_CHECK")
tweaksFrame:RegisterEvent("PARTY_INVITE_REQUEST")
tweaksFrame:RegisterEvent("START_TIMER")
tweaksFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

tweaksFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "READY_CHECK" then
        OnReadyCheck()

    elseif event == "PARTY_INVITE_REQUEST" then
        OnGroupInvite()

    elseif event == "START_TIMER" then
        -- timerType 3 = TIMER_TYPE_PREPARATION (pull countdown)
        local timerType, timeSeconds = ...
        if tonumber(timerType) == 3 then
            if not CXUI_DB.pullTimerSound then return end
            SchedulePullCountdown(tonumber(timeSeconds) or 0)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        CancelPullCountdown()
    end
end)

-- ---------------------------------------------------------------------------
-- RIGHT CLICK MODIFIER
-- Block Right-Click Targeting in Combat (Dungeons & Raids)
-- ---------------------------------------------------------------------------

WorldFrame:HookScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" then return end
    if not CXUI_DB.rcm then return end
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") and UnitAffectingCombat("player") then
        MouselookStop()
    end
end)