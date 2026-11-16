local addonName, ns = ...

-- ===========================================================================
-- SKIN: BetterWardrobe
-- Standard Blizzard widgets only (panel buttons, stock checkboxes, edit
-- boxes, dropdowns, scroll bars) inside BetterWardrobe's own frames: the
-- collection list (inside the Collections journal), the outfit-name popup, the
-- situation preset editor and the alternate-appearance popout.
--
-- The Collections journal and the Transmogrify window themselves are
-- Blizzard's and are already skinned by EllesmereUI; the pieces BetterWardrobe
-- adds to them (its icon buttons, tabs and previews) stay as they are.
--
-- The frames are made when their feature is first used, so the skin waits for
-- each one and skins it again whenever it is shown.
-- ===========================================================================

local Sk = ns.ESkin

local FRAMES = {
    "BW_ColectionListFrame",        -- (sic) BetterWardrobe's spelling
    "BW_CustomSetNamePopup",
    "BW_SituationPresetEditFrame",
    "BW_AltAppearancePopout",
}

Sk.NewSkin{
    addon = "BetterWardrobe",
    apply = function(S)
        for _, name in ipairs(FRAMES) do
            Sk.WhenFrameCreated(name, function()
                local frame = _G[name]
                if not frame then return end
                Sk.SkinStandard(S, frame, 6)
                frame:HookScript("OnShow", Sk.Safe(function() Sk.SkinStandard(S, frame, 6) end))
            end)
        end
    end,
}
