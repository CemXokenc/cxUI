local addonName, ns = ...

-- ===========================================================================
-- SKIN: BtWQuests
-- The Quest Journal window (BtWQuestsFrame, a PortraitFrameTemplate): the
-- window plate and border get the house look, and the buttons are flattened:
-- the expansion cards (the "Active" mark is kept) and the per-expansion
-- "View All" / "Load AddOn" buttons. Everything else (the chain view, the
-- navigation arrows, the search box, the scroll bars, the checkboxes) stays as
-- it is.
--
-- The frame and its buttons are created from XML while BtWQuests loads.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinButtons(S, frame, depth)
    for _, key in ipairs({ "ViewAll", "Load" }) do
        local button = frame[key]
        if button and button.IsObjectType and button:IsObjectType("Button") then S.Button(button) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("Button") and type(child.Subtext) == "table" and child.Active then
            S.Button(child, { "Active" })       -- an expansion card
        elseif depth < 7 then
            SkinButtons(S, child, depth + 1)
        end
    end
end

local function SkinWindow(S)
    local window = _G.BtWQuestsFrame
    if not window then return end
    S.Shell(window)
    if window.NineSlice then S.FadeNineSlice(window.NineSlice) end
    Sk.Fade(S, window.PortraitContainer)
    if window.CloseButton then S.CloseButton(window.CloseButton) end
    SkinButtons(S, window, 1)
    Sk.SkinStandard(S, window, 7, { button = true })
end

Sk.NewSkin{
    addon = "BtWQuests",
    apply = function(S)
        local window = _G.BtWQuestsFrame
        if not window then return end
        SkinWindow(S)
        -- pages and expansion lists are filled in as the player navigates
        window:HookScript("OnShow", Sk.Safe(function() SkinWindow(S) end))
    end,
}
