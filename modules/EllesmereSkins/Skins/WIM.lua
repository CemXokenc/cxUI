local addonName, ns = ...

-- ===========================================================================
-- SKIN: WIM
-- 1. The message windows: WIM's own "EllesmereUI" skin (and "EllesmereUI -
--    Light"), taken unchanged from the EllesmereSkin_WIM addon (Vendor/WIM/).
--    It is a WIM skin, not an EllesmereUI one: it registers with WIM's skin
--    system and reads EllesmereUI's accent, font and border engine live. The
--    skin is chosen in WIM as before (/wim -> Skin). The original re-applies the
--    selected skin at PLAYER_LOGIN so a saved choice takes effect; that moment
--    has passed by the time this runs, so the same check is made here, right
--    after the skin is registered.
--
-- 2. The History Viewer (WIM3_HistoryFrame). WIM 3.19 draws it from a
--    `history_viewer` section of the selected skin, and a skin without one
--    inherits WIM Classic's (the metal panel, gold labels, Blizzard tab and row
--    art). The vendored skin predates that section, so one is added to both of
--    its skins as they are registered: no metal chrome, flat tabs, plain row
--    highlight in the accent color, white labels, no atlas art. (Fields left out
--    keep WIM Classic's values; `false` is used where an inherited art entry has
--    to be switched off.) The window itself, its close button, title and the stock
--    widgets inside it (dropdowns, edit boxes, scroll bars) are then skinned
--    through EllesmereUI, from the moment the viewer is opened
--    (ShowHistoryViewer) and every time it is shown.
-- ===========================================================================

local Sk = ns.ESkin

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- the part of a WIM skin table that dresses the History Viewer
local function HistoryViewerSection(Theme)
    local r, g, b = 0.05, 0.82, 0.62
    if Theme and Theme.Accent then
        local ar, ag, ab = Theme.Accent()
        if ar then r, g, b = ar, ag, ab end
    end
    return {
        frame_style   = "flat",                     -- not "panel": no metal chrome
        tab_style     = "legacy",                   -- flat strips instead of the Settings tab plates
        divider_color = { 1, 1, 1, 0.10 },
        title  = { font_color = { 1, 1, 1 } },
        header = { font_color = { 1, 1, 1 }, atlas = false },
        row = {
            font_color = { 0.90, 0.90, 0.90 },
            highlight  = { atlas = false, texture = WHITE, alpha_mode = "ADD",
                           color = { r * 0.25, g * 0.25, b * 0.25 } },
            selected   = { atlas = false },
        },
    }
end

local function SkinHistory(S)
    local win = _G.WIM3_HistoryFrame
    if not win then return false end
    S.Shell(win)
    Sk.FadeBackdrop(win)
    if win.close and win.close.IsObjectType then S.CloseButton(win.close) end
    if win.title and win.title.IsObjectType and win.title:IsObjectType("FontString") then S.Font(win.title) end
    Sk.SkinStandard(S, win, 8)
    return true
end

Sk.NewSkin{
    addon = "WIM",
    run = function()
        local shared = {}
        local WIM = _G.WIM
        local original = WIM and WIM.RegisterSkin

        if original then
            -- add the history_viewer section to our two skins as they register
            WIM.RegisterSkin = function(skin, ...)
                local titles = shared.L
                if type(skin) == "table" and titles and not skin.history_viewer
                    and (skin.title == titles["SKIN_TITLE"] or skin.title == titles["SKIN_TITLE_LIGHT"]) then
                    skin.history_viewer = HistoryViewerSection(shared.Theme)
                end
                return original(skin, ...)
            end
        end
        Sk.RunChunks("WIM", "EllesmereSkin_WIM", shared)
        if original then WIM.RegisterSkin = original end

        local titles = shared.L
        if WIM and WIM.LoadSkin and WIM.db and WIM.db.skin and titles then
            local selected = WIM.db.skin.selected
            if selected == titles["SKIN_TITLE"] or selected == titles["SKIN_TITLE_LIGHT"] then
                WIM.LoadSkin(selected)
            end
        end
    end,
    apply = function(S)
        local hooked = false
        local function Skin()
            if not SkinHistory(S) or hooked then return end
            hooked = true
            -- the lists, tabs and filters are filled in on each open
            _G.WIM3_HistoryFrame:HookScript("OnShow", Sk.Safe(function() SkinHistory(S) end))
        end
        -- WIM keeps its own copy of CreateFrame, so the viewer's creation can't be watched
        -- directly; ShowHistoryViewer builds it on first use and always runs on opening.
        Sk.SafeHook(_G, "ShowHistoryViewer", Skin)
        Sk.WhenFrameCreated("WIM3_HistoryFrame", Skin)
        Skin()
    end,
}
