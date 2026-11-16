local addonName, ns = ...

-- ===========================================================================
-- SKIN: HomeBound
-- HomeBound's windows are near-black backdrop frames with a tooltip-style
-- edge: the main window and the vendor / support / upload / Wowhead-link
-- popups get the house window look; the two tooltips and the two preview boxes
-- get the house panel. The stock widgets inside (search box, filter dropdown,
-- checkboxes, edit boxes, scroll bar, buttons) are skinned too. The tabs, the
-- quest rows and the icons are HomeBound's own art and stay as they are.
--
-- HomeBound's settings window (HB_ConfigFrame) is NOT touched: it is registered
-- as a page of the Blizzard AddOns options tab, and nothing in that tab is
-- skinned (see README).
--
-- Every frame is created while HomeBound loads.
-- ===========================================================================

local Sk = ns.ESkin

local WINDOWS = { "HB_MainFrame", "HB_VendorPopup", "HB_SupportFrame", "HB_UploadFrame", "HB_WowheadLinkFrame" }
local PANELS  = { "HB_NoteTooltip", "HB_CostTooltip", "HB_RewardFrame", "HB_SmallPreviewFrame" }

local function SkinFrame(S, frame, asWindow)
    if not frame then return end
    if asWindow then S.Shell(frame) else S.Panel(frame) end
    Sk.FadeBackdrop(frame)
    Sk.SkinStandard(S, frame, 5)
end

Sk.NewSkin{
    addon = "HomeBound",
    apply = function(S)
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame then
                SkinFrame(S, frame, true)
                -- widgets filled in later (popup contents are rebuilt per mode)
                frame:HookScript("OnShow", Sk.Safe(function() Sk.SkinStandard(S, frame, 5) end))
            end
        end
        for _, name in ipairs(PANELS) do SkinFrame(S, _G[name], false) end
    end,
}
