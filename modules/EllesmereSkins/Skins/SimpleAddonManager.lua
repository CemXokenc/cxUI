local addonName, ns = ...

-- ===========================================================================
-- SKIN: SimpleAddonManager
-- The addon list window (a ButtonFrameTemplate frame, global
-- "SimpleAddonManager"): search box, character dropdown, Profiles / OK /
-- Cancel / Enable-all / Disable-all buttons, the addon list and the category
-- list with their scroll bars, the row checkboxes, and the square toggle
-- buttons (category panel, options, search filter).
--
-- SimpleAddonManager creates every child frame on the window's first OnShow
-- (SAM:Initialize), so the skin is applied from an OnShow hook, after that
-- handler has run. The list rows are pooled by HybridScrollFrame and get
-- their checkbox the first time they exist, so rows are skinned again after
-- each list update (the primitives are idempotent).
-- ===========================================================================

local Sk = ns.ESkin

local function Btn(S, button, keep)
    if not button then return end
    S.Button(button, keep)
    S.StateButtonLabel(button)
end

local function SkinRows(S, scrollFrame)
    local rows = scrollFrame and scrollFrame.buttons
    if not rows then return end
    for _, row in ipairs(rows) do
        local check = row.EnabledButton
        if check then S.Checkbox(check) end
    end
end

local function SkinList(S, holder)
    local scrollFrame = holder and holder.ScrollFrame
    if not scrollFrame then return end
    if scrollFrame.ScrollBar then S.ScrollBar(scrollFrame.ScrollBar) end
    SkinRows(S, scrollFrame)
end

local function SkinWindow(S)
    local window = _G.SimpleAddonManager
    if not window or not window.SearchBox then return end -- not initialised yet

    -- ButtonFrameTemplate: own art on the frame, border and portrait on child frames
    S.Shell(window)
    if window.NineSlice then S.FadeNineSlice(window.NineSlice) end
    if window.PortraitContainer then Sk.Fade(S, window.PortraitContainer) end
    if window.CloseButton then S.CloseButton(window.CloseButton) end
    if window.Inset then S.Inset(window.Inset) end

    S.EditBox(window.SearchBox)
    if window.SearchBox.searchIcon then window.SearchBox.searchIcon:SetAlpha(1) end

    if window.CharacterDropDown then S.Dropdown(window.CharacterDropDown) end

    for _, key in ipairs({ "SetsButton", "OkButton", "CancelButton", "EnableAllButton", "DisableAllButton" }) do
        Btn(S, window[key])
    end

    local categories = window.CategoryFrame
    if categories then
        for _, key in ipairs({ "NewButton", "SelectAllButton", "ClearSelectionButton" }) do
            Btn(S, categories[key])
        end
    end

    -- UIPanelSquareButton: the glyph is its .icon region
    Btn(S, window.CategoryButton, { "icon" })

    SkinList(S, window.AddonListFrame)
    SkinList(S, window.CategoryFrame)
end

Sk.NewSkin{
    addon = "SimpleAddonManager",
    apply = function(S)
        local window = _G.SimpleAddonManager
        if not window then return end

        -- rows are (re)filled by each list's update function (hooked once per list)
        local hooked = {}
        local function HookList(holder)
            local scrollFrame = holder and holder.ScrollFrame
            if scrollFrame and not hooked[scrollFrame] then
                hooked[scrollFrame] = true
                Sk.SafeHook(scrollFrame, "update", function() SkinRows(S, scrollFrame) end)
            end
        end

        -- one OnShow hook: runs after SimpleAddonManager's own handler, which
        -- creates the children on the first show
        local function OnShow()
            HookList(window.AddonListFrame)
            HookList(window.CategoryFrame)
            SkinWindow(S)
        end
        window:HookScript("OnShow", Sk.Safe(OnShow))

        if window:IsShown() then OnShow() end
    end,
}
