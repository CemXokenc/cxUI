local addonName, ns = ...

-- ===========================================================================
-- SKIN: TargetedSpells
-- The Designer window (TargetedSpellsDesigner, a ButtonFrameTemplate without
-- portrait or button bar): house window look, the inset panels, and the stock
-- widgets inside it (the resize buttons, the scroll frame's bar and so on).
-- The icon / bar previews it designs are TargetedSpells' own art and stay.
-- TargetedSpells' settings page (in the Blizzard AddOns tab) is not touched.
--
-- The Designer is built the first time it is opened, inside a local function,
-- so the skin waits for the frame (and skins it again each time it is shown).
-- ===========================================================================

local Sk = ns.ESkin

local function SkinDesigner(S)
    local frame = _G.TargetedSpellsDesigner
    if not frame then return false end
    S.Shell(frame)
    if frame.NineSlice then S.FadeNineSlice(frame.NineSlice) end
    Sk.Fade(S, frame.PortraitContainer)
    if frame.CloseButton then S.CloseButton(frame.CloseButton) end
    -- the insets it builds itself (InsetFrameTemplate: Bg + NineSlice)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.NineSlice and child.Bg and child ~= frame.Inset then S.Inset(child) end
    end
    Sk.SkinStandard(S, frame, 8)
    return true
end

Sk.NewSkin{
    addon = "TargetedSpells",
    apply = function(S)
        local hooked = false
        local function Skin()
            if not SkinDesigner(S) or hooked then return end
            hooked = true
            _G.TargetedSpellsDesigner:HookScript("OnShow", Sk.Safe(function() SkinDesigner(S) end))
        end
        Sk.WhenFrameCreated("TargetedSpellsDesigner", Skin)
    end,
}
