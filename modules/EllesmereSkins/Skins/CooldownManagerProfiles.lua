local addonName, ns = ...

-- ===========================================================================
-- SKIN: CooldownManagerProfiles
-- Standard Blizzard widgets only (panel buttons, stock checkboxes, edit
-- boxes, dropdowns, scroll bars) inside the profile manager. The window and
-- its three columns are the addon's own drawing and stay as they are.
--
-- The window is anonymous, so it is found through one of its named scroll
-- frames (CMGlobalProfScroll): the ancestor sitting directly under UIParent.
-- It is built on first use, so the skin waits for that scroll frame.
-- ===========================================================================

local Sk = ns.ESkin

local function WindowOf(frame)
    local parent = frame:GetParent()
    while parent and parent ~= UIParent and parent.GetParent do
        frame = parent
        parent = parent:GetParent()
    end
    return frame
end

Sk.NewSkin{
    addon = "CooldownManagerProfiles",
    apply = function(S)
        Sk.WhenFrameCreated("CMGlobalProfScroll", function()
            local scroll = _G.CMGlobalProfScroll
            if not scroll then return end
            local window = WindowOf(scroll)
            Sk.SkinStandard(S, window, 8)
            window:HookScript("OnShow", Sk.Safe(function() Sk.SkinStandard(S, window, 8) end))
        end)
    end,
}
