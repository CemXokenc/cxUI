local addonName, ns = ...

-- ===========================================================================
-- MODULE: TRANSPARENCY LOGIC
-- ===========================================================================

local actionBarFrames = { MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, StanceBar, PetActionBar }
local uiGroupFrames   = { MicroMenuContainer, BagsBar }
local spellFlyout     = SpellFlyout

local UPDATE_INTERVAL     = 0.1
local timeSinceLastUpdate = 0
local isInCombat          = false
local questTrackerHoverFrame = nil
local lastTrackerHeight = nil

-- Guards prevent recursion when our hook calls SetAlpha again
local alphaGuards = {}

-- ---------------------------------------------------------------------------
-- DESIRED ALPHA RESOLVERS
-- ---------------------------------------------------------------------------

local function WantedActionBarsAlpha()
    if not CXUI_DB.hideBars then return 1 end
    if isInCombat then return 0 end
    local ok, result = pcall(function()
        if spellFlyout and spellFlyout:IsShown() and spellFlyout:IsMouseOver() then return 1 end
        for _, bar in ipairs(actionBarFrames) do
            if bar and bar:IsMouseOver() then return 1 end
            if bar and bar.actionButtons then
                for _, btn in pairs(bar.actionButtons) do
                    if btn and btn:IsMouseOver() then return 1 end
                end
            end
        end
        return 0
    end)
    return (ok and result) or 0
end

local function WantedUIGroupAlpha()
    if not CXUI_DB.hideMicro then return 1 end
    local ok, result = pcall(function()
        for _, frame in ipairs(uiGroupFrames) do
            if frame and frame:IsMouseOver() then return 1 end
        end
        return 0
    end)
    return (ok and result) or 0
end

local function WantedQuestTrackerAlpha()
    if not CXUI_DB.hideQuests then return 1 end
    if not questTrackerHoverFrame then return 0 end
    local ok, isHovered = pcall(function()
        return questTrackerHoverFrame:IsMouseOver()
    end)
    if not ok or issecretvalue(isHovered) then return 0 end
    return isHovered and 1 or 0
end

-- ---------------------------------------------------------------------------
-- ALPHA GUARD HOOK
-- Only installed on non-managed frames (action bars, micro menu).
-- ObjectiveTrackerFrame is intentionally excluded — it's a Blizzard managed
-- frame and hooking SetAlpha on it causes taint that breaks the entire
-- right UI container, tooltips, and bonus objectives (glows).
-- ---------------------------------------------------------------------------

local function GuardAlpha(frame, getWanted)
    hooksecurefunc(frame, "SetAlpha", function(self, alpha)
        if alphaGuards[self] then return end
        local wanted = getWanted()
        if alpha ~= wanted then
            alphaGuards[self] = true
            self:SetAlpha(wanted)
            alphaGuards[self] = false
        end
    end)
end

local function InstallAlphaGuards()
    for _, bar in ipairs(actionBarFrames) do
        if bar then GuardAlpha(bar, WantedActionBarsAlpha) end
    end
    for _, frame in ipairs(uiGroupFrames) do
        if frame then GuardAlpha(frame, WantedUIGroupAlpha) end
    end
    -- NOTE: ObjectiveTrackerFrame guard intentionally removed.
    -- Hooking SetAlpha on a Blizzard managed frame taints it,
    -- which cascades into MoneyFrame, MapCanvas, bonus objective glows, etc.
    -- Alpha is applied via ApplyAllAlpha() on every OnUpdate tick instead.
end

-- ---------------------------------------------------------------------------
-- APPLY CURRENT STATE
-- ---------------------------------------------------------------------------

local function ApplyAllAlpha()
    local barsAlpha  = WantedActionBarsAlpha()
    local groupAlpha = WantedUIGroupAlpha()

    for _, bar in ipairs(actionBarFrames) do
        if bar then bar:SetAlpha(barsAlpha) end
    end
    for _, frame in ipairs(uiGroupFrames) do
        if frame then frame:SetAlpha(groupAlpha) end
    end

    -- ObjectiveTrackerFrame: apply alpha only from OnUpdate (never from hooks
    -- or event callbacks) to avoid tainting the Blizzard managed frame system.
    -- NOTE: deliberately no GetHeight()/GetSize() read here — reading tracker
    -- geometry is itself what marks the value/execution as tainted ("secret
    -- number"), not just an unsafe check to guard against. SetAlpha alone,
    -- called only from this plain OnUpdate tick (never from a hook or an
    -- event fired inside Edit Mode's own callback chain), is the lowest-risk
    -- touch point we have left.
    if ObjectiveTrackerFrame then
        local trackerAlpha = WantedQuestTrackerAlpha()
        ObjectiveTrackerFrame:SetAlpha(trackerAlpha)
    end
end

-- ---------------------------------------------------------------------------
-- MOUSE INTERACTION
-- ---------------------------------------------------------------------------

local function SetButtonsMouseEnabled(enabled)
    for _, bar in ipairs(actionBarFrames) do
        if bar and bar.actionButtons then
            for _, button in pairs(bar.actionButtons) do
                if button then
                    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(enabled) end
                    button:EnableMouse(enabled)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- QUEST TRACKER HOVER FRAME
-- An invisible frame covering the top 60% of the tracker, used as a hover
-- sensor. The tricky part: the tracker's height CAN be read safely, but only
-- from a plain, decoupled OnUpdate tick — never from inside a hook/callback
-- that Blizzard's own protected code calls into (e.g. HookScript on the real
-- frame's OnSizeChanged runs synchronously inside EditModeManager's
-- InvokeOnAnyEditModeSystemAnchorChanged chain, and THAT is what turned the
-- read into a "secret number" / taint cascade last time). Polling from our
-- own independent ticker avoids that entirely. Alpha itself is still driven
-- ONLY by the OnUpdate tick — never by OnEnter/OnLeave scripts — because
-- SetScript callbacks tied to managed Blizzard frames taint them when they
-- call SetAlpha on them.
-- ---------------------------------------------------------------------------

local function UpdateHoverBounds()
    if not questTrackerHoverFrame then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    -- Safe here: this runs from our own decoupled OnUpdate tick, NOT from a
    -- hook/callback inside Blizzard's protected Edit Mode chain. Still guarded
    -- defensively in case a "secret" value ever leaks through anyway.
    local ok, h = pcall(function() return tracker:GetHeight() end)
    if not ok or not h or issecretvalue(h) or h <= 0 then return end
    if h == lastTrackerHeight then return end -- nothing changed, skip re-anchoring
    lastTrackerHeight = h

    questTrackerHoverFrame:ClearAllPoints()
    questTrackerHoverFrame:SetPoint("TOPLEFT",     tracker, "TOPLEFT",  -15,  15)
    questTrackerHoverFrame:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT",  15, -(h * 0.6))
end

local function SetupQuestTrackerHover()
    if questTrackerHoverFrame or not CXUI_DB.hideQuests then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    questTrackerHoverFrame = CreateFrame("Frame", nil, UIParent)
    questTrackerHoverFrame:SetFrameStrata("LOW")
    questTrackerHoverFrame:EnableMouse(true)

    -- No HookScript("OnSizeChanged") here — that's what previously injected
    -- our code into Blizzard's own protected callback chain. Bounds are kept
    -- in sync purely by polling from OnUpdate (see UpdateHoverBounds above).
    UpdateHoverBounds()

    -- NO OnEnter/OnLeave scripts here — they would taint ObjectiveTrackerFrame
    -- when calling tracker:SetAlpha(). Alpha is handled purely by OnUpdate.
end

-- ---------------------------------------------------------------------------
-- TICK
-- ---------------------------------------------------------------------------

local function OnUpdate(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate < UPDATE_INTERVAL then return end
    timeSinceLastUpdate = 0
    ApplyAllAlpha()
    UpdateHoverBounds()
end

-- ---------------------------------------------------------------------------
-- EVENT HANDLER
-- ---------------------------------------------------------------------------

local transparencyCore = CreateFrame("Frame")

transparencyCore:RegisterEvent("ADDON_LOADED")
transparencyCore:RegisterEvent("PLAYER_REGEN_DISABLED")
transparencyCore:RegisterEvent("PLAYER_REGEN_ENABLED")
transparencyCore:RegisterEvent("PLAYER_ENTERING_WORLD")

transparencyCore:SetScript("OnEvent", function(self, event, arg)

    if event == "ADDON_LOADED" and arg == addonName then
        InstallAlphaGuards()
        ApplyAllAlpha()
        SetButtonsMouseEnabled(true)
        if QueueStatusButton then
            QueueStatusButton:SetAlpha(1)
            QueueStatusButton:SetIgnoreParentAlpha(true)
        end
        C_Timer.After(0.5, SetupQuestTrackerHover)
        self:SetScript("OnUpdate", OnUpdate)

    elseif event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        if CXUI_DB.hideBars then SetButtonsMouseEnabled(false) end

    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        SetButtonsMouseEnabled(true)

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, SetupQuestTrackerHover)

    end
end)