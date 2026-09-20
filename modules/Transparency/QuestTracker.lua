local addonName, ns = ...

-- ===========================================================================
-- TRANSPARENCY: QUEST TRACKER HOVER
-- An invisible frame over the top 60% of the tracker is the hover sensor.
-- Alpha is driven ONLY by the tick (never from OnEnter/OnLeave or SetAlpha
-- hooks) because touching a Blizzard-managed frame from those taints it.
-- ===========================================================================

local T = ns:GetModule("Transparency")

local F = T:NewFeature{
    key  = "hideQuests",
    name = "Quest Tracker Hover",
    desc = "Quest tracker only visible on mouseover.",
}

local hoverFrame

local function WantedAlpha()
    if not hoverFrame then return 0 end
    local ok, isHovered = pcall(function() return hoverFrame:IsMouseOver() end)
    if not ok or issecretvalue(isHovered) then return 0 end
    return isHovered and 1 or 0
end

local function Tick()
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    -- pcall + secret check prevents a taint cascade in arena / Edit Mode
    local ok, h = pcall(function() return tracker:GetHeight() end)
    if ok and h and not issecretvalue(h) then
        tracker:SetAlpha(WantedAlpha())
    end
end

local function UpdateHoverBounds()
    local tracker = ObjectiveTrackerFrame
    if not (F:IsOn() and hoverFrame and tracker) then return end
    local ok, h = pcall(function() return tracker:GetHeight() end)
    if not ok or not h or issecretvalue(h) or h == 0 then
        F:After(0, UpdateHoverBounds)
        return
    end
    hoverFrame:ClearAllPoints()
    hoverFrame:SetPoint("TOPLEFT",     tracker, "TOPLEFT",  -15,  15)
    hoverFrame:SetPoint("BOTTOMRIGHT", tracker, "TOPRIGHT",  15, -(h * 0.6))
end

local function Setup()
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    if not hoverFrame then
        hoverFrame = CreateFrame("Frame", nil, UIParent)
        hoverFrame:SetFrameStrata("LOW")
        F:HookScript(tracker, "OnSizeChanged", function() F:After(0.1, UpdateHoverBounds) end)
    end
    hoverFrame:EnableMouse(true)
    hoverFrame:Show()
    UpdateHoverBounds()
end

function F:OnEnable()
    Setup()
    self:After(0.5, Setup) -- tracker may not be laid out yet at login

    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function() F:After(0.5, Setup) end)

    T.AddTick("hideQuests", Tick)
    if ObjectiveTrackerFrame then ObjectiveTrackerFrame:SetAlpha(0) end
end

function F:OnDisable()
    T.RemoveTick("hideQuests")
    if hoverFrame then
        hoverFrame:EnableMouse(false)
        hoverFrame:Hide()
    end
    if ObjectiveTrackerFrame then ObjectiveTrackerFrame:SetAlpha(1) end
end
