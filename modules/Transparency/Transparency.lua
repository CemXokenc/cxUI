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
-- ---------------------------------------------------------------------------

local function WantedActionBarsAlpha()
    -- nil = feature disabled, don't touch this frame's alpha at all
    -- (lets other addons manage it without us fighting them)
    if not CXUI_DB.hideBars then return nil end
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
    -- nil = feature disabled, don't touch this frame's alpha at all
    -- (lets other addons manage the micro menu without us fighting them)
    if not CXUI_DB.hideMicro then return nil end
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
        -- nil = feature is toggled off, so don't enforce anything here;
        -- otherwise we'd override alpha set by other addons (e.g. ElvUI,
        -- micro menu addons) that also manage this frame.
        if wanted == nil then return end
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

    -- nil = feature disabled; skip SetAlpha entirely so we don't keep
    -- stomping on alpha values set by other addons every 0.1s.
    if barsAlpha ~= nil then
        for _, bar in ipairs(actionBarFrames) do
            if bar then bar:SetAlpha(barsAlpha) end
        end
    end
    if groupAlpha ~= nil then
        for _, frame in ipairs(uiGroupFrames) do
            if frame then frame:SetAlpha(groupAlpha) end
        end
    end

    -- ObjectiveTrackerFrame: apply alpha only from OnUpdate (never from hooks
    -- or event callbacks) to avoid tainting the Blizzard managed frame system.
    -- IMPORTANT: only touch this frame at all when hideQuests is enabled.
    -- Otherwise we'd keep calling SetAlpha(1) on it every 0.1s forever,
    -- fighting with ElvUI (or any other addon) that also manages this frame.
    if CXUI_DB.hideQuests and ObjectiveTrackerFrame then
		-- Wrap in issecretvalue check + pcall to prevent taint cascade in arena
		local ok, h = pcall(function() return ObjectiveTrackerFrame:GetHeight() end)
		if ok and h and not issecretvalue(h) then
			local trackerAlpha = WantedQuestTrackerAlpha()
			ObjectiveTrackerFrame:SetAlpha(trackerAlpha)
		end
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
-- An invisible frame covering the top 60% of the tracker used as a hover
-- sensor. Alpha is driven ONLY by the OnUpdate tick — never by OnEnter/OnLeave
-- scripts — because SetScript callbacks on frames anchored to managed Blizzard
-- frames taint those frames when they call SetAlpha on them.
-- ---------------------------------------------------------------------------

local function SetupQuestTrackerHover()
    if questTrackerHoverFrame or not CXUI_DB.hideQuests then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    questTrackerHoverFrame = CreateFrame("Frame", nil, UIParent)
    questTrackerHoverFrame:SetFrameStrata("LOW")
    questTrackerHoverFrame:EnableMouse(true)

    local function UpdateHoverBounds()
        -- Defer if GetHeight returns a secret/tainted value (e.g. during Edit Mode)
        local ok, h = pcall(function() return tracker:GetHeight() end)
        if not ok or not h or issecretvalue(h) or h == 0 then
            C_Timer.After(0, UpdateHoverBounds)
            return
        end
        questTrackerHoverFrame:ClearAllPoints()
        questTrackerHoverFrame:SetPoint("TOPLEFT",     tracker, "TOPLEFT",  -15,  15)
        questTrackerHoverFrame:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT",  15, -(h * 0.6))
    end

    UpdateHoverBounds()

    -- Defer OnSizeChanged out of secure context to avoid taint
    tracker:HookScript("OnSizeChanged", function()
        C_Timer.After(0.1, UpdateHoverBounds)
    end)

    -- NO OnEnter/OnLeave scripts here — they would taint ObjectiveTrackerFrame
    -- when calling tracker:SetAlpha(). Alpha is handled purely by OnUpdate.
    tracker:SetAlpha(0)
end

-- ---------------------------------------------------------------------------
-- TICK
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
transparencyCore:RegisterEvent("PLAYER_REGEN_DISABLED")
transparencyCore:RegisterEvent("PLAYER_REGEN_ENABLED")
transparencyCore:RegisterEvent("PLAYER_ENTERING_WORLD")

transparencyCore:SetScript("OnEvent", function(self, event, arg)

    if event == "ADDON_LOADED" and arg == addonName then
        InstallAlphaGuards()
        ApplyAllAlpha()
        -- Only touch button mouse state if hideBars is actually enabled —
        -- otherwise we'd stomp on mouse-enabled state managed by other addons.
        if CXUI_DB.hideBars then SetButtonsMouseEnabled(true) end
        -- QueueStatusButton is part of the micro menu group — only manage its
        -- alpha/ignore-parent-alpha when hideMicro is enabled, otherwise leave
        -- it fully alone so other addons can manage it without conflict.
        if CXUI_DB.hideMicro and QueueStatusButton then
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
        -- Only re-enable mouse if hideBars is on (we're the ones who disabled
        -- it going into combat). If it's off, we never touched it — leave it be.
        if CXUI_DB.hideBars then SetButtonsMouseEnabled(true) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, SetupQuestTrackerHover)

    end
end)