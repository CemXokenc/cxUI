local addonName, ns = ...

-- ===========================================================================
-- COMBAT: BLOCK RIGHT-CLICK TARGETING (RCM)
-- Stops mouselook from a right-click in dungeons and raids while in combat.
-- ===========================================================================

local M = ns:GetModule("Combat")

local F = M:NewFeature{
    key  = "rcm",
    name = "Block Right-Click in Combat",
    desc = "Prevents accidental right-click targeting in dungeons and raids.",
}

function F:OnEnable()
    self:HookScript(WorldFrame, "OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid") and UnitAffectingCombat("player") then
            MouselookStop()
        end
    end)
end
