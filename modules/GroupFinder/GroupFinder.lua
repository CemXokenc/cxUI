local addonName, ns = ...

-- ===========================================================================
-- MODULE: GROUP FINDER
-- Dungeon Finder / LFG list tweaks. One file per feature:
--   DungeonFilter.lua   advanced search filters
--   MoveResetButton.lua "Reset Filter" button position
-- Shared helpers:
-- ===========================================================================

local GF = ns:NewModule("GroupFinder", {
    name  = "Group Finder",
    desc  = "Dungeon Finder filters and layout",
    order = 7,
})

-- Taint-safety guard: don't touch secure LFG frames while an addon action
-- restriction is active.
function GF.IsRestrictedContent()
    local restrictionTypes = Enum and Enum.AddOnRestrictionType
    local restrictedActions = _G.C_RestrictedActions
    if not (restrictionTypes and restrictedActions and restrictedActions.GetAddOnRestrictionState) then return false end
    for _, v in pairs(restrictionTypes) do
        if restrictedActions.GetAddOnRestrictionState(v) == 2 then return true end
    end
    return false
end

function GF.GetResetButton()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    return panel and panel.FilterButton and panel.FilterButton.ResetButton
end

-- Calls onReady() (0.5s deferred) once LFGListFrame.SearchPanel exists. The
-- LFG UI is load-on-demand, so this also listens for it loading. When
-- `repeatable` is true onReady runs again on every zone change / load.
-- Events are registered on a frame owned by feature F (cleared when F turns off).
function GF.WatchLFG(F, onReady, repeatable)
    local done = false
    local function try()
        if done then return end
        if not (LFGListFrame and LFGListFrame.SearchPanel) then return end
        if not repeatable then done = true end
        onReady()
    end

    local ev = F:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(self, event, arg1)
        if done then self:UnregisterAllEvents(); return end
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_LookingForGroupUI" and arg1 ~= "Blizzard_GroupFinder" then return end
        F:After(0.5, try)
    end)
    F:After(0.5, try) -- LFG UI may already be loaded
end
