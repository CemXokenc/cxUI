local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: RIGHT-CLICK MODIFIER (RCM)
-- Blocks right-click targeting in Dungeons & Raids during combat.
-- ===========================================================================

WorldFrame:HookScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" then return end
    if not CXUI_DB.rcm then return end
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") and UnitAffectingCombat("player") then
        MouselookStop()
    end
end)
