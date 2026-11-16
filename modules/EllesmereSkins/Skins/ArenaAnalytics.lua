local addonName, ns = ...

-- ===========================================================================
-- SKIN: ArenaAnalytics
-- Standard Blizzard widgets only (panel buttons, stock checkboxes, edit and
-- search boxes, dropdowns, scroll bars) inside the match-history window, plus
-- the import dialog (a BasicFrameTemplateWithInset) as a house window.
-- The window itself, the match rows, the class and spec icons and the filter
-- art are ArenaAnalytics' own and stay as they are.
--
-- Both frames are global; the import dialog is built the first time it is
-- needed, so the skin waits for each.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinImportDialog(S)
    local frame = _G.ArenaAnalyticsImportFrame
    if not frame then return end
    S.Shell(frame)
    if frame.NineSlice then S.FadeNineSlice(frame.NineSlice) end
    if frame.CloseButton then S.CloseButton(frame.CloseButton) end
    if frame.InsetBg then Sk.Fade(S, frame.InsetBg) end
    Sk.SkinStandard(S, frame, 5)
end

Sk.NewSkin{
    addon = "ArenaAnalytics",
    apply = function(S)
        Sk.WhenFrameCreated("ArenaAnalyticsScrollFrame", function()
            local window = _G.ArenaAnalyticsScrollFrame
            if not window then return end
            Sk.SkinStandard(S, window, 6)
            -- the settings checkboxes and filter widgets are made when the window first opens
            window:HookScript("OnShow", Sk.Safe(function() Sk.SkinStandard(S, window, 6) end))
        end)
        Sk.WhenFrameCreated("ArenaAnalyticsImportFrame", function()
            SkinImportDialog(S)
            local dialog = _G.ArenaAnalyticsImportFrame
            if dialog then dialog:HookScript("OnShow", Sk.Safe(function() SkinImportDialog(S) end)) end
        end)
    end,
}
