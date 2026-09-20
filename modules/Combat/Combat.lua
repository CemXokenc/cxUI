local addonName, ns = ...

-- ===========================================================================
-- MODULE: COMBAT
-- In-combat helpers: absorb display, input safety and death / resurrection
-- conveniences. One file per feature:
--   AbsorbDisplay, BlockRightClick, BlockSpaceCast,
--   AutoAcceptResurrection, AutoReleasePvP
-- ===========================================================================

ns:NewModule("Combat", {
    name  = "Combat",
    desc  = "Absorb display, input safety, resurrection helpers",
    order = 4,
})
