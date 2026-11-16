local addonName, ns = ...

-- ===========================================================================
-- SKIN: Simulationcraft
-- The export window (SimcFrame, a DialogBoxFrame): OK button, scroll bar,
-- the two checkboxes. The edit box is the content and stays untouched: no
-- SetText / HighlightText / SetFocus, so export strings, clipboard handling
-- and selection keep working. The resize grabber stays stock.
--
-- Simulationcraft builds the frame on the first GetMainFrame() call.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinSimc(S)
    local frame = _G.SimcFrame
    if not frame then return end

    S.Shell(frame)
    if frame.Border then S.FadeNineSlice(frame.Border) end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end -- Simulationcraft's own backdrop

    local button = _G.SimcFrameButton
    if button then
        S.Button(button)
        S.StateButtonLabel(button)
    end

    local scrollFrame = _G.SimcScrollFrame
    local bar = scrollFrame and (scrollFrame.ScrollBar or _G.SimcScrollFrameScrollBar)
    if bar then S.ScrollBar(bar) end

    for _, name in ipairs({ "AutomaticClose", "SimcOffspecLoadouts" }) do
        local check = _G[name]
        if check then
            S.Checkbox(check)
            if check.Text then S.White(check.Text) end
        end
    end
end

Sk.NewSkin{
    addon = "Simulationcraft",
    name  = "SimulationCraft",
    apply = function(S)
        local ace = LibStub and LibStub("AceAddon-3.0", true)
        local app = (ace and ace:GetAddon("Simulationcraft", true)) or _G.Simulationcraft
        if app then
            Sk.SafeHook(app, "GetMainFrame", function() SkinSimc(S) end)
        end
        SkinSimc(S) -- the window may already exist
    end,
}
