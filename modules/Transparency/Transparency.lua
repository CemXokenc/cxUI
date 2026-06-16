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

-- Guards prevent recursion when our hook calls SetAlpha again
local alphaGuards = {}

-- ---------------------------------------------------------------------------
-- DESIRED ALPHA RESOLVERS
-- These functions return what the alpha *should* be right now for each group.
-- The hook and ApplyAllAlpha both call these — single source of truth.
-- ---------------------------------------------------------------------------

local function WantedActionBarsAlpha()
    if not CXUI_DB.hideBars then return 1 end
    if isInCombat then return 0 end
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
end

local function WantedUIGroupAlpha()
    if not CXUI_DB.hideMicro then return 1 end
    for _, frame in ipairs(uiGroupFrames) do
        if frame and frame:IsMouseOver() then return 1 end
    end
    return 0
end

local function WantedQuestTrackerAlpha()
    if not CXUI_DB.hideQuests then return 1 end
    if not questTrackerHoverFrame then return 0 end
    local ok, isHovered = pcall(function() return questTrackerHoverFrame:IsMouseOver() end)
    if not ok or issecretvalue(isHovered) then return 0 end
    return isHovered and 1 or 0
end

-- ---------------------------------------------------------------------------
-- ALPHA GUARD HOOK
-- Intercepts any SetAlpha call (from engine, other addons, cinematics, etc.)
-- and immediately restores the correct value if it doesn't match what we want.
-- ---------------------------------------------------------------------------

local function GuardAlpha(frame, getWanted)
    hooksecurefunc(frame, "SetAlpha", function(self, alpha)
        if alphaGuards[self] then return end  -- prevent recursion
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
    if ObjectiveTrackerFrame then
        GuardAlpha(ObjectiveTrackerFrame, WantedQuestTrackerAlpha)
    end
end

-- ---------------------------------------------------------------------------
-- APPLY CURRENT STATE
-- Pushes the correct alpha to every managed frame right now.
-- Called once on init; after that OnUpdate drives hover changes and
-- guards catch any engine-side resets.
-- ---------------------------------------------------------------------------

local function ApplyAllAlpha()
    local barsAlpha    = WantedActionBarsAlpha()
    local groupAlpha   = WantedUIGroupAlpha()
    local trackerAlpha = WantedQuestTrackerAlpha()

    for _, bar in ipairs(actionBarFrames) do
        if bar then bar:SetAlpha(barsAlpha) end
    end
    for _, frame in ipairs(uiGroupFrames) do
        if frame then frame:SetAlpha(groupAlpha) end
    end
    if ObjectiveTrackerFrame then
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
-- An invisible frame covering the top 60% of the tracker (by height) used as
-- a hover sensor, since a fully transparent frame won't fire OnEnter/OnLeave
-- reliably. The bottom 40% is intentionally excluded so hovering over the
-- lower portion of the tracker (e.g. bottom-right corner) does nothing.
-- Anchored to the tracker so WoW's layout system keeps it in sync automatically.
-- OnSizeChanged recalculates bounds whenever the quest list grows or shrinks.
-- ---------------------------------------------------------------------------

local function SetupQuestTrackerHover()
    if questTrackerHoverFrame or not CXUI_DB.hideQuests then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    questTrackerHoverFrame = CreateFrame("Frame", nil, UIParent)
    questTrackerHoverFrame:SetFrameStrata("LOW")
    questTrackerHoverFrame:EnableMouse(true)

    -- Recalculates bounds whenever the tracker resizes (quest list grows/shrinks).
    -- BOTTOMRIGHT is anchored to tracker's TOPRIGHT and pushed down by 60% of
    -- the current height — so only the top 60% of the tracker acts as a hover zone.
    local function UpdateHoverBounds()
        local ok, h = pcall(function() return tracker:GetHeight() end)
        if not ok or not h or issecretvalue(h) or h == 0 then return end
        questTrackerHoverFrame:ClearAllPoints()
        questTrackerHoverFrame:SetPoint("TOPLEFT",     tracker, "TOPLEFT",  -15,  15)
        questTrackerHoverFrame:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT",  15, -(h * 0.6))
    end

    UpdateHoverBounds()
    tracker:HookScript("OnSizeChanged", function()
        -- OnSizeChanged can fire from secure context (Edit Mode), defer to next frame
        C_Timer.After(0, UpdateHoverBounds)
    end)

    tracker:SetAlpha(0)

    -- OnEnter/OnLeave give instant visual feedback rather than waiting for the next tick
    questTrackerHoverFrame:SetScript("OnEnter", function() tracker:SetAlpha(1) end)
    questTrackerHoverFrame:SetScript("OnLeave", function() tracker:SetAlpha(0) end)
end

-- ---------------------------------------------------------------------------
-- TICK — hover detection only
-- Alpha corrections are handled by the guards; this only reacts to mouse
-- position changes, which have no event equivalent in WoW.
-- ---------------------------------------------------------------------------

local function OnUpdate(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate < UPDATE_INTERVAL then return end
    timeSinceLastUpdate = 0
    ApplyAllAlpha()
end

-- ---------------------------------------------------------------------------
-- EVENT HANDLER
-- ---------------------------------------------------------------------------

local transparencyCore = CreateFrame("Frame")

transparencyCore:RegisterEvent("ADDON_LOADED")
transparencyCore:RegisterEvent("PLAYER_REGEN_DISABLED")  -- entering combat
transparencyCore:RegisterEvent("PLAYER_REGEN_ENABLED")   -- leaving combat
transparencyCore:RegisterEvent("PLAYER_ENTERING_WORLD")  -- loading screen / instance transition

transparencyCore:SetScript("OnEvent", function(self, event, arg)

    if event == "ADDON_LOADED" and arg == addonName then
        InstallAlphaGuards()
        ApplyAllAlpha()
        SetButtonsMouseEnabled(true)
        -- QueueStatusButton is set once here; it never needs resetting
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