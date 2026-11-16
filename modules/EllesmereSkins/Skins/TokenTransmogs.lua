local addonName, ns = ...

-- ===========================================================================
-- SKIN: TokenTransmogs
-- The item browser (TokenTransmogsBrowserFrame, a ButtonFrameTemplate): the
-- inset around the list, its scroll bar, the set-ID input, the copy box and
-- the lookup button. The item rows and the slot toggles are the addon's own
-- art and stay as they are.
--
-- The window is built inside the /tokentransmogs handler, in a local function,
-- so the skin waits for the frame to appear.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinBrowser(S)
    local frame = _G.TokenTransmogsBrowserFrame
    if not frame then return end

    S.Shell(frame)
    if frame.NineSlice then S.FadeNineSlice(frame.NineSlice) end
    if frame.PortraitContainer then S.FadeRegions(frame.PortraitContainer) end
    if frame.CloseButton then S.CloseButton(frame.CloseButton) end
    if frame.Inset then S.Inset(frame.Inset) end

    -- the list's own InsetFrameTemplate container (Bg + NineSlice)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= frame.Inset and child.NineSlice and child.Bg then S.Inset(child) end
    end

    Sk.SkinStandard(S, frame, 4)
end

Sk.NewSkin{
    addon = "TokenTransmogs",
    apply = function(S)
        Sk.WhenFrameCreated("TokenTransmogsBrowserFrame", function()
            SkinBrowser(S)
        end)
    end,
}
