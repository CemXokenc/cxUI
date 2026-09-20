local addonName, ns = ...

-- ===========================================================================
-- COMBAT: ABSORB DISPLAY
-- Total shield amount in the middle of the screen while in combat.
-- ===========================================================================

local M = ns:GetModule("Combat")

local F = M:NewFeature{
    key  = "showAbsorb",
    name = "Enable Absorb Display",
    desc = "Shows total shield amount in screen center.",
}

local absorbText

local function Update()
    if not InCombatLockdown() then
        absorbText:SetText("")
        return
    end
    absorbText:SetText(AbbreviateNumbers(UnitGetTotalAbsorbs("player") or 0))
end

function F:OnEnable()
    if not absorbText then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(200, 30)
        holder:SetPoint("CENTER", 0, 30)
        absorbText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        absorbText:SetPoint("CENTER")
        absorbText:SetTextColor(1, 1, 1, 1)
        absorbText:SetFont(absorbText:GetFont(), 18, "OUTLINE")
    end

    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", Update)
    Update()
end

function F:OnDisable()
    if absorbText then absorbText:SetText("") end
end
