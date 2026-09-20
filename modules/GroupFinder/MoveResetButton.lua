local addonName, ns = ...

-- ===========================================================================
-- GROUP FINDER: MOVE "RESET FILTER" BUTTON
-- Shifts the Dungeon Browser's "Reset Filter" button to the left so it doesn't
-- overlap. Ported from EnhanceQoL (groupfinderMoveResetButton).
-- ===========================================================================

local GF = ns:GetModule("GroupFinder")

local F = GF:NewFeature{
    key  = "moveResetButton",
    name = "Move 'Reset Filter' Button",
    desc = "Shifts the Dungeon Browser's 'Reset Filter' button to the left side to avoid overlap.",
}

local original -- { point, relativeTo, relativePoint, x, y }

local function Apply()
    local button = GF.GetResetButton()
    if not button then return end
    if not original then original = { button:GetPoint() } end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", LFGListFrame.SearchPanel.FilterButton, "TOPLEFT", -7, 13)
end

function F:OnEnable()
    GF.WatchLFG(self, Apply, true)
end

function F:OnDisable()
    local button = GF.GetResetButton()
    if button and original and original[1] then
        button:ClearAllPoints()
        button:SetPoint(unpack(original))
    end
end
