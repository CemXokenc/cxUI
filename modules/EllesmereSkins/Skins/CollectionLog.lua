local addonName, ns = ...

-- ===========================================================================
-- SKIN: Collection Log
-- Standard Blizzard widgets only: panel buttons, stock checkboxes, single-line
-- edit boxes, dropdowns and scroll bars inside the main window and its
-- popups. CollectionLog draws its own window (a plain backdrop frame), rows
-- and icons, and those stay exactly as they are.
--
-- Needs the GetItemInfoInstant fix: CollectionLog calls the removed global in
-- dozens of places and its Appearance sets tab throws without it.
--
-- The window is built inside UI.Init() (the addon's private namespace), the
-- first time it is opened, so the skin waits for CollectionLogFrame.
-- ===========================================================================

local Sk = ns.ESkin

local POPUPS = {
    "CollectionLogWishlistTrackerOpacityFrame",
    "CollectionLogDonatePopup",
}

Sk.NewSkin{
    addon = "CollectionLog",
    name  = "Collection Log",
    fixes = { "GetItemInfoInstant" },
    apply = function(S)
        local function Skin()
            local frame = _G.CollectionLogFrame
            if frame then Sk.SkinStandard(S, frame, 8) end
            for _, name in ipairs(POPUPS) do
                local popup = _G[name]
                if popup then Sk.SkinStandard(S, popup, 4) end
            end
        end
        Sk.WhenFrameCreated("CollectionLogFrame", function()
            local frame = _G.CollectionLogFrame
            if frame then frame:HookScript("OnShow", Sk.Safe(Skin)) end
            Skin()
        end)
    end,
}
