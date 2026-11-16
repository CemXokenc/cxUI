local addonName, ns = ...

-- ===========================================================================
-- SKIN: RareScanner
--  1. The "found something" popup (RARESCANNER_BUTTON), the clickable bar
--     that appears when a rare, treasure or event shows up. It is a secure
--     action button (clicking it targets the find), so the skin stays purely
--     visual: art faded, own regions added, never its size, position,
--     attributes or scripts. The 3D model above it, the loot bar below, the
--     navigation arrows and the filter icon buttons keep RareScanner's look.
--  2. The explorer window (RSExplorerFrame): the window plate and border,
--     the parchment behind the three panels and the loot boxes, and the
--     stock widgets inside (buttons, checkboxes, dropdowns, search box,
--     scroll bars). Rows, icons and the map stay as they are.
-- Both frames come from RareScanner's XML/load code, so they exist when the
-- skin runs.
-- ===========================================================================

local Sk = ns.ESkin

local POPUP_NAME = "RARESCANNER_BUTTON"

-- the region keys BackdropTemplate stores its edge and center pieces under
local BACKDROP_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

local LOOT_BOXES = { "Mounts", "Pets", "Toys", "Drakewatcher", "Decor", "Custom", "Appearances" }
local PANELS = { "RareNPCList", "RareInfo", "RareLoot", "CustomLoot" }

local edgeHooked = false

local function SkinPopup(S)
    local popup = _G[POPUP_NAME]
    if not popup then return end

    -- The parchment (normal texture), the title ribbon and the tooltip-style backdrop edge are all
    -- regions of the button, so S.Button takes them along and lays down the flat house block with
    -- its border and hover wash. The wash takes over the hover cue of RareScanner's backdrop edge.
    S.Button(popup)

    -- RareScanner's OnEnter turns the tooltip-style edge white, which only makes sense around its
    -- parchment and showed through the house look as a white frame on hover. Fade the edge pieces
    -- again after each of its color writes (OnEnter and OnLeave both go through this method).
    local function FadeBackdropEdge()
        for _, key in ipairs(BACKDROP_PIECES) do
            local piece = popup[key]
            if piece and piece.SetAlpha then piece:SetAlpha(0) end
        end
    end
    FadeBackdropEdge()
    if not edgeHooked and type(popup.SetBackdropBorderColor) == "function" then
        edgeHooked = true
        Sk.SafeHook(popup, "SetBackdropBorderColor", FadeBackdropEdge)
    end

    if popup.CloseButton then S.CloseButton(popup.CloseButton) end

    -- the name and the "click to target" line, in the user's UI font
    if popup.Title then S.Font(popup.Title) end
    if popup.Description_text then S.Font(popup.Description_text) end
end

local function SkinExplorer(S)
    local root = _G.RSExplorerFrame
    if not root then return end

    -- RSExplorerUITemplate: the parchment is a region of the frame, the gold border and the
    -- embellishments are regions of its Border child frame
    S.Shell(root)
    if root.Border then Sk.Fade(S, root.Border) end
    if root.CloseButton then S.CloseButton(root.CloseButton) end

    -- each panel carries its own parchment (and a Border child with the same art)
    for _, key in ipairs(PANELS) do
        local panel = root[key]
        if panel then
            Sk.Fade(S, panel)
            if panel.Border then Sk.Fade(S, panel.Border) end
        end
    end
    -- the loot boxes inside the rare info panel: a background and a header wash each
    local info = root.RareInfo
    if info then
        for _, key in ipairs(LOOT_BOXES) do
            if info[key] then Sk.Fade(S, info[key]) end
        end
    end

    Sk.SkinStandard(S, root, 6)
end

Sk.NewSkin{
    addon = "RareScanner",
    apply = function(S)
        SkinPopup(S)
        SkinExplorer(S)
        -- widgets the explorer creates later (list rows' scroll bars, panels built on demand)
        local root = _G.RSExplorerFrame
        if root then root:HookScript("OnShow", Sk.Safe(function() SkinExplorer(S) end)) end
    end,
}
