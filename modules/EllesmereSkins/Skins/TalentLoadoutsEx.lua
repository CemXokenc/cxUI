local addonName, ns = ...

-- ===========================================================================
-- SKIN: TalentLoadoutsEx
-- The loadout panel TalentLoadoutsEx hangs on the right side of the talent
-- window (TalentLoadoutExMainFrame, an InsetFrameTemplate panel): the panel's
-- inset and the stock widgets inside it (Import / Export / Preset / Load /
-- Save / Edit buttons, dropdowns, edit boxes, scroll bars). The talent window
-- is Blizzard's and is skinned by EllesmereUI; the loadout icons and rows are
-- TalentLoadoutsEx' own art.
--
-- The panel is built when the talent window first loads, so the skin waits for
-- it and skins it again each time it is shown.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinPanel(S)
    local panel = _G.TalentLoadoutExMainFrame
    if not panel then return false end
    if panel.NineSlice and panel.Bg then S.Inset(panel) end
    Sk.SkinStandard(S, panel, 6)
    return true
end

Sk.NewSkin{
    addon = "TalentLoadoutsEx",
    apply = function(S)
        local hooked = false
        local function Skin()
            if not SkinPanel(S) or hooked then return end
            hooked = true
            _G.TalentLoadoutExMainFrame:HookScript("OnShow", Sk.Safe(function() SkinPanel(S) end))
        end
        Sk.WhenFrameCreated("TalentLoadoutExMainFrame", Skin)
    end,
}
