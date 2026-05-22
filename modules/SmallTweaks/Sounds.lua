local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: AUDIO ALERTS
-- Ready Check, Group Invite, and Pull Timer countdown sounds.
-- All play through the Master channel to stay audible when alt-tabbed.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- READY CHECK
-- ---------------------------------------------------------------------------

local function OnReadyCheck()
    if not CXUI_DB.altTabAlerts then return end
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
end

-- ---------------------------------------------------------------------------
-- GROUP INVITE
-- Covers both direct player invites and Group Finder invites (M+, raid, etc.)
-- ---------------------------------------------------------------------------

local function OnGroupInvite()
    if not CXUI_DB.inviteSound then return end
    PlaySound(8960, "Master")
end

-- ---------------------------------------------------------------------------
-- PULL TIMER COUNTDOWN
-- Plays SharedMedia_Causese sounds at 10, 5, 4, 3, 2, 1 seconds remaining.
-- Falls back to SOUNDKIT.READY_CHECK if a file is not found.
-- Supported sources: /pull, BigWigs, DBM, BG/arena prep timers.
-- ---------------------------------------------------------------------------

local PULL_SOUND_PATHS = {
    [10] = "Interface\\AddOns\\SharedMedia_Causese\\sound\\10.ogg",
    [5]  = "Interface\\AddOns\\SharedMedia_Causese\\sound\\5.ogg",
    [4]  = "Interface\\AddOns\\SharedMedia_Causese\\sound\\4.ogg",
    [3]  = "Interface\\AddOns\\SharedMedia_Causese\\sound\\3.ogg",
    [2]  = "Interface\\AddOns\\SharedMedia_Causese\\sound\\2.ogg",
    [1]  = "Interface\\AddOns\\SharedMedia_Causese\\sound\\1.ogg",
    [0]  = "Interface\\AddOns\\Wildu_SharedMedia\\Media\\Sound\\Jenny\\Pull.ogg",
}

local PULL_COUNTDOWN_MARKS = { 10, 5, 4, 3, 2, 1, 0 }

local function PlayCountdownSound(mark)
    local path = PULL_SOUND_PATHS[mark]
    if path then
        PlaySoundFile(path, "Master")
    else
        PlaySound(SOUNDKIT.READY_CHECK, "Master")
    end
end

local pullCountdownGen = 0

local function SchedulePullCountdown(secondsRemaining)
    if not CXUI_DB.pullTimerSound then return end
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
-- LOW HEALTH ALERT
-- ---------------------------------------------------------------------------

local function OnLowHealthShow()
    if CXUI_DB and CXUI_DB.lowHealthAlert then
        PlaySoundFile("Interface\\AddOns\\cxUI\\Media\\lowhp.ogg", "Master")
    end
end

if LowHealthFrame then
    LowHealthFrame:HookScript("OnShow", OnLowHealthShow)
end

-- ---------------------------------------------------------------------------
-- EVENT HANDLER
-- ---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("READY_CHECK")
f:RegisterEvent("PARTY_INVITE_REQUEST")
f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
f:RegisterEvent("START_PLAYER_COUNTDOWN")
f:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
f:RegisterEvent("START_TIMER")
f:RegisterEvent("PLAYER_REGEN_DISABLED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "READY_CHECK" then
        OnReadyCheck()

    elseif event == "PARTY_INVITE_REQUEST" then
        OnGroupInvite()

    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local _, newStatus = ...
        if newStatus == "invited" then OnGroupInvite() end

    elseif event == "START_PLAYER_COUNTDOWN" then
        local _, timeSeconds = ...
        SchedulePullCountdown(tonumber(timeSeconds) or 0)

    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        CancelPullCountdown()

    elseif event == "START_TIMER" then
        local timerType, timeSeconds = ...
        if tonumber(timerType) == 3 then
            SchedulePullCountdown(tonumber(timeSeconds) or 0)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        CancelPullCountdown()
    end
end)
