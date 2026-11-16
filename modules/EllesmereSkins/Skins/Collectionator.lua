local addonName, ns = ...

-- ===========================================================================
-- SKIN: Collectionator
-- Collectionator's tab in the auction house (AuctionHouseFrame.
-- CollectionatorSummaryTabFrame): its mode buttons (Transmog / Pets / Toys /
-- Decor / Mounts / Recipes), the buy frame's buttons, and every other stock
-- widget in the tab (checkboxes, edit boxes, dropdowns, scroll bars). The
-- results lists are Auctionator's list widgets and are dressed by the
-- Auctionator skin; Collectionator's rows and icons are its own art.
-- The auction house window itself is Blizzard's and is skinned by EllesmereUI.
-- Collectionator's settings page (Blizzard AddOns tab) is not touched.
--
-- The tab frame is a parentKey child of the auction house window (it has no
-- global name), so it is looked for whenever the auction house is shown, and
-- skinned again whenever the tab is.
-- ===========================================================================

local Sk = ns.ESkin

Sk.NewSkin{
    addon = "Collectionator",
    apply = function(S)
        local tabHooked = false

        local function SkinTab()
            local house = _G.AuctionHouseFrame
            local tab = house and house.CollectionatorSummaryTabFrame
            if not tab then return end
            Sk.SkinStandard(S, tab, 8)
            if not tabHooked then
                tabHooked = true
                -- the mode views and the buy frame are filled in as the tab is used
                tab:HookScript("OnShow", Sk.Safe(SkinTab))
            end
        end

        Sk.WhenLoaded("Blizzard_AuctionHouseUI", function()
            local house = _G.AuctionHouseFrame
            if not house then return end
            house:HookScript("OnShow", Sk.Safe(SkinTab))
            SkinTab()
        end)
    end,
}
