local addonName, ns = ...

-- ===========================================================================
-- SKIN: PetTracker
-- The "Pets" block PetTracker hangs on the objective tracker: its header and
-- its progress bar. The rest of PetTracker (journal tabs, rivals, battle UI,
-- map filters) is not touched.
--
--  * Header: PetTracker makes it from Blizzard's ObjectiveTrackerModuleHeader-
--    Template, so EllesmereUI's tracker skin never sees it (its own headers
--    belong to Blizzard's tracker modules). It is handed to
--    EllesmereUIQuestTracker.SkinHeader, the function that styles "Campaign",
--    "Quests" and the rest, so the font, color, divider line and +/- button
--    follow the user's tracker settings exactly. That function is the one
--    EllesmereUI's tracker exposes for this; it is not part of the documented
--    S.* API, and with the tracker module missing the header is left stock.
--  * Progress bar: art faded, flat dark plate behind the fills, thin border
--    over them, font in the user's UI font. The fills keep their colors:
--    PetTracker stacks one status bar per pet quality, and the colors are the
--    information, which S.ApplyBarFill (one color for every bar) would erase.
--
-- PetTracker publishes its tracker as PetTracker.Objectives. The bar exists
-- from load, the header is made at login, so the skin waits for it.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinBar(S, bar)
    Sk.Fade(S, bar)                         -- the translucent black plate
    local overlay = bar.Overlay                -- achievement-style bevel + the "3/9" text
    if overlay then
        Sk.Fade(S, overlay)
        S.Panel(overlay, { noBg = true })      -- border only: it sits above the fills
        if overlay.Text then S.Font(overlay.Text) end
    end
    S.Panel(bar, { inset = true, noBorder = true })  -- plate only: it sits below the fills
end

local function SkinHeader(header)
    local tracker = _G.EllesmereUIQuestTracker
    if tracker and tracker.SkinHeader then tracker.SkinHeader(header) end
end

Sk.NewSkin{
    addon = "PetTracker",
    apply = function(S)
        local barDone, hooked, tries = false, false, 0

        local function Skin(objectives)
            if not barDone and objectives.Bar then
                barDone = true
                SkinBar(S, objectives.Bar)
            end
            if objectives.Header then SkinHeader(objectives.Header) end
        end

        local function Try()
            local objectives = _G.PetTracker and _G.PetTracker.Objectives
            if objectives and objectives.Header then
                Skin(objectives)
                if not hooked then
                    hooked = true
                    -- Layout runs on every tracker update and options change; Toggle swaps the +/- glyph
                    for _, method in ipairs({ "Layout", "Toggle" }) do
                        Sk.SafeHook(objectives, method, function() Skin(objectives) end)
                    end
                    if objectives.Header.HookScript then
                        objectives.Header:HookScript("OnShow", Sk.Safe(function() Skin(objectives) end))
                    end
                end
                return
            end
            -- the header is created when PetTracker's Objectives module loads at login
            tries = tries + 1
            if tries < 20 then C_Timer.After(0.5, Try) end
        end

        Try()
    end,
}
