local addonName, ns = ...

-- ===========================================================================
-- SKIN: Rematch
-- The Rematch window skin from the Rematch_EllesmereUI_Skin addon (Vendor/
-- Rematch/Backend.lua and Skin.lua), taken unchanged except for its start-up
-- block: the original waits for PLAYER_LOGIN on a frame of its own, and that
-- moment is the one this runs in, so the same body is called directly
-- (ns.Boot) once the two files are loaded.
--
-- Its own 12.1 workarounds (the removed MouseIsOver, NPC names hidden inside
-- instances) are the shared fixes of this module, applied with this checkbox,
-- together with one more: PetTracker's Rivals tab, which collides with
-- Rematch's journal, is hidden.
-- Settings it keeps go in RematchEllesmereUISkinDB, as before; /rematchskin
-- still works.
-- Rematch has to load before cxUI (cxUI.toc OptionalDeps): the skin expects
-- Rematch's own PLAYER_LOGIN handlers to have run.
-- ===========================================================================

local Sk = ns.ESkin

Sk.NewSkin{
    addon = "Rematch",
    fixes = { "MouseIsOver", "RematchHiddenNames", "HidePetTrackerRivals" },
    run = function()
        local shared = {}
        Sk.RunChunks("Rematch", "Rematch", shared)
        if shared.Boot then shared.Boot() end
    end,
}
