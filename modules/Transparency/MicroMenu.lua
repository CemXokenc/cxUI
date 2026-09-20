local addonName, ns = ...

-- ===========================================================================
-- TRANSPARENCY: MICRO MENU & BAGS AUTO-HIDE
-- ===========================================================================

local T = ns:GetModule("Transparency")

local F = T:NewFeature{
    key  = "hideMicro",
    name = "Micro Menu Auto-hide",
    desc = "Hides Micro Menu and Bags. Hover to reveal.",
}

local groupFrames = {}
local prevIgnoreParentAlpha

local function Wanted()
    if not F:IsOn() then return nil end
    local ok, result = pcall(function()
        for _, frame in ipairs(groupFrames) do
            if frame:IsMouseOver() then return 1 end
        end
        return 0
    end)
    return (ok and result) or 0
end

local function Tick()
    local wanted = Wanted()
    if wanted == nil then return end
    for _, frame in ipairs(groupFrames) do frame:SetAlpha(wanted) end
end

function F:OnEnable()
    groupFrames = {}
    for _, frame in ipairs({ MicroMenuContainer, BagsBar }) do
        if frame then groupFrames[#groupFrames + 1] = frame end
    end
    for _, frame in ipairs(groupFrames) do T.GuardAlpha(frame, Wanted) end

    -- QueueStatusButton sits in the micro menu group: keep it visible.
    if QueueStatusButton then
        prevIgnoreParentAlpha = QueueStatusButton:IsIgnoringParentAlpha()
        QueueStatusButton:SetAlpha(1)
        QueueStatusButton:SetIgnoreParentAlpha(true)
    end

    T.AddTick("hideMicro", Tick)
    Tick()
end

function F:OnDisable()
    T.RemoveTick("hideMicro")
    for _, frame in ipairs(groupFrames) do frame:SetAlpha(1) end
    if QueueStatusButton then
        QueueStatusButton:SetIgnoreParentAlpha(prevIgnoreParentAlpha and true or false)
    end
end
