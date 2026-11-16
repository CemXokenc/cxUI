local addonName, ns = ...

-- ===========================================================================
-- SKIN: TomTom
-- The waypoint paste window (TomTomPaste, a DefaultPanelTemplate window):
-- house window, close button, and the stock widgets inside it. The arrow,
-- the coordinate block, the world-map overlay and the Ace option pages are
-- not touched.
--
-- The window is built the first time it is opened, so the skin waits for it.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinPaste(S)
    local frame = _G.TomTomPaste
    if not frame then return end
    S.Shell(frame)
    if frame.NineSlice then S.FadeNineSlice(frame.NineSlice) end
    if frame.CloseButton then S.CloseButton(frame.CloseButton) end
    Sk.SkinStandard(S, frame, 5)
end

Sk.NewSkin{
    addon = "TomTom",
    apply = function(S)
        Sk.WhenFrameCreated("TomTomPaste", function()
            SkinPaste(S)
            local frame = _G.TomTomPaste
            if frame then frame:HookScript("OnShow", Sk.Safe(function() SkinPaste(S) end)) end
        end)
    end,
}
