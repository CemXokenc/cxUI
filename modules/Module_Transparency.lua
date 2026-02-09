local addonName, ns = ...

-- ===========================================================================
-- MODULE: TRANSPARENCY LOGIC
-- ===========================================================================

local actionBarFrames = { MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, StanceBar, PetActionBar }
local uiGroupFrames = { MicroMenuContainer, BagsBar }
local UPDATE_INTERVAL, timeSinceLastUpdate, isInCombat, questTrackerHoverFrame = 0.1, 0, false, nil
local spellFlyout = SpellFlyout

local function IsMouseOverUIFrame(frame)
    if not frame then return false end
    if frame:IsMouseOver() then return true end
    if frame.actionButtons then
        for _, button in pairs(frame.actionButtons) do
            if button and button:IsMouseOver() then return true end
        end
    end
    return false
end

local function IsMouseOverActionBars()
    if not CXUI_DB.hideBars or isInCombat then return false end
    if spellFlyout and spellFlyout:IsShown() and spellFlyout:IsMouseOver() then return true end
    for _, bar in ipairs(actionBarFrames) do
        if IsMouseOverUIFrame(bar) then return true end
    end
    return false
end

local function IsMouseOverUIGroup()
    if not CXUI_DB.hideMicro then return false end
    for _, frame in ipairs(uiGroupFrames) do
        if IsMouseOverUIFrame(frame) then return true end
    end
    return false
end

local function SetActionBarsAlpha(alpha)
    for _, bar in ipairs(actionBarFrames) do if bar then bar:SetAlpha(alpha) end end
end

local function SetUIGroupAlpha(alpha)
    for _, frame in ipairs(uiGroupFrames) do if frame then frame:SetAlpha(alpha) end end
end

local function SetAlwaysVisibleFrames()
    if QueueStatusButton then
        QueueStatusButton:SetAlpha(1)
        QueueStatusButton:SetIgnoreParentAlpha(true)
    end
end

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

local function SetupQuestTrackerHover()
    if questTrackerHoverFrame or not CXUI_DB.hideQuests then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    questTrackerHoverFrame = CreateFrame("Frame", nil, UIParent)
    questTrackerHoverFrame:SetFrameStrata("LOW")
    questTrackerHoverFrame:SetPoint("TOPLEFT", tracker, -15, 15)
    questTrackerHoverFrame:SetPoint("BOTTOMRIGHT", tracker, 15, -15)
    questTrackerHoverFrame:EnableMouse(true)
    tracker:SetAlpha(0)
    questTrackerHoverFrame:SetScript("OnEnter", function() tracker:SetAlpha(1) end)
    questTrackerHoverFrame:SetScript("OnLeave", function() tracker:SetAlpha(0) end)
    questTrackerHoverFrame:SetScript("OnUpdate", function(self)
        if self.lastUpdate and GetTime() - self.lastUpdate < 0.5 then return end
        self.lastUpdate = GetTime()
        if tracker:IsShown() then self:SetPoint("BOTTOMRIGHT", tracker, 15, -15) end
    end)
end

local function UpdateAlpha()
    if isInCombat then 
        SetActionBarsAlpha(CXUI_DB.hideBars and 0 or 1)
    else 
        SetActionBarsAlpha(IsMouseOverActionBars() and 1 or (CXUI_DB.hideBars and 0 or 1)) 
    end
    SetUIGroupAlpha(IsMouseOverUIGroup() and 1 or (CXUI_DB.hideMicro and 0 or 1))
    SetAlwaysVisibleFrames()
end

local transparencyCore = CreateFrame("Frame")
transparencyCore:RegisterEvent("ADDON_LOADED")
transparencyCore:RegisterEvent("PLAYER_REGEN_DISABLED")
transparencyCore:RegisterEvent("PLAYER_REGEN_ENABLED")
transparencyCore:RegisterEvent("PLAYER_ENTERING_WORLD")

transparencyCore:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "cemxokenc" then
        UpdateAlpha()
        SetButtonsMouseEnabled(true)
        C_Timer.After(0.5, SetupQuestTrackerHover)
    elseif event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        if CXUI_DB.hideBars then SetButtonsMouseEnabled(false) end
        UpdateAlpha()
    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        SetButtonsMouseEnabled(true)
        UpdateAlpha()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function() UpdateAlpha(); SetupQuestTrackerHover() end)
    end
end)

transparencyCore:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= UPDATE_INTERVAL then
        timeSinceLastUpdate = 0
        UpdateAlpha()
    end
end)