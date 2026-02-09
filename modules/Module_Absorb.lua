local addonName, ns = ...

-- ===========================================================================
-- MODULE: ABSORB LOGIC
-- ===========================================================================

local absorbFrame = CreateFrame("Frame", nil, UIParent)
absorbFrame:SetSize(200, 30)
absorbFrame:SetPoint("CENTER", 0, 30)
local absorbText = absorbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
absorbText:SetPoint("CENTER")
absorbText:SetTextColor(1, 1, 1, 1)
absorbText:SetFont(absorbText:GetFont(), 18, "OUTLINE")

local function UpdateAbsorbDisplay()
    if not CXUI_DB.showAbsorb then absorbText:SetText(""); return end
    local totalAbsorb = UnitGetTotalAbsorbs("player") or 0
    absorbText:SetText(AbbreviateNumbers(totalAbsorb))
end

absorbFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
absorbFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
absorbFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" and unit ~= "player" then return end
    UpdateAbsorbDisplay()
end)