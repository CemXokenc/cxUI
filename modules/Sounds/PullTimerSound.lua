local addonName, ns = ...

-- ===========================================================================
-- SOUNDS: PULL TIMER COUNTDOWN
-- Plays SharedMedia_Causese sounds at 10, 5, 4, 3, 2, 1 seconds remaining and
-- a "pull" sound at 0. Falls back to the ready-check sound if a file is missing.
-- Sources: /pull, BigWigs, DBM, BG/arena prep timers.
-- ===========================================================================

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "pullTimerSound",
    name = "Pull Timer Countdown Sound",
    desc = "Plays audio for the preparation countdown (10, 5, 4, 3, 2, 1).",
}

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
        S.PlayFile(path)
    else
        S.PlayKit(SOUNDKIT.READY_CHECK)
    end
end

local gen = 0

local function Schedule(secondsRemaining)
    gen = gen + 1
    local myGen = gen
    for _, mark in ipairs(PULL_COUNTDOWN_MARKS) do
        local delay = secondsRemaining - mark
        if delay >= 0 then
            F:After(delay, function()
                if myGen ~= gen then return end
                PlayCountdownSound(mark)
            end)
        end
    end
end

local function Cancel() gen = gen + 1 end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("START_PLAYER_COUNTDOWN")
    ev:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
    ev:RegisterEvent("START_TIMER")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "START_PLAYER_COUNTDOWN" then
            local _, timeSeconds = ...
            Schedule(tonumber(timeSeconds) or 0)
        elseif event == "START_TIMER" then
            local timerType, timeSeconds = ...
            if tonumber(timerType) == 3 then Schedule(tonumber(timeSeconds) or 0) end
        else -- CANCEL_PLAYER_COUNTDOWN / PLAYER_REGEN_DISABLED
            Cancel()
        end
    end)
end

function F:OnDisable()
    Cancel()
end
