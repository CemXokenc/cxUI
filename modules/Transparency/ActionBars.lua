local addonName, ns = ...

-- ===========================================================================
-- TRANSPARENCY: ACTION BAR AUTO-HIDE
-- Bars are hidden out of combat and revealed on mouseover; in combat they are
-- hidden and their buttons stop taking mouse input.
-- ===========================================================================

local T = ns:GetModule("Transparency")

local F = T:NewFeature{
    key  = "hideBars",
    name = "Action Bar Auto-hide",
    desc = "Hides bars out of combat. Hover to reveal.",
}

local bars = {}
local spellFlyout
local inCombat = false

local function Wanted()
    -- nil = feature off, don't touch alpha at all
    if not F:IsOn() then return nil end
    if inCombat then return 0 end
    local ok, result = pcall(function()
        if spellFlyout and spellFlyout:IsShown() and spellFlyout:IsMouseOver() then return 1 end
        for _, bar in ipairs(bars) do
            if bar:IsMouseOver() then return 1 end
            if bar.actionButtons then
                for _, btn in pairs(bar.actionButtons) do
                    if btn and btn:IsMouseOver() then return 1 end
                end
            end
        end
        return 0
    end)
    return (ok and result) or 0
end

local function SetButtonsMouseEnabled(enabled)
    for _, bar in ipairs(bars) do
        if bar.actionButtons then
            for _, button in pairs(bar.actionButtons) do
                if button then
                    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(enabled) end
                    button:EnableMouse(enabled)
                end
            end
        end
    end
end

local function Tick()
    local wanted = Wanted()
    if wanted == nil then return end
    for _, bar in ipairs(bars) do bar:SetAlpha(wanted) end
end

function F:OnEnable()
    bars = {}
    for _, bar in ipairs({ MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, StanceBar, PetActionBar }) do
        if bar then bars[#bars + 1] = bar end
    end
    spellFlyout = SpellFlyout
    inCombat = InCombatLockdown() and true or false

    for _, bar in ipairs(bars) do T.GuardAlpha(bar, Wanted) end

    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)
        inCombat = (event == "PLAYER_REGEN_DISABLED")
        SetButtonsMouseEnabled(not inCombat)
    end)

    SetButtonsMouseEnabled(not inCombat)
    T.AddTick("hideBars", Tick)
    Tick()
end

function F:OnDisable()
    T.RemoveTick("hideBars")
    for _, bar in ipairs(bars) do bar:SetAlpha(1) end
    pcall(SetButtonsMouseEnabled, true)
end
