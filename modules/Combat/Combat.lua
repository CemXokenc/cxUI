local addonName, ns = ...

-- ===========================================================================
-- MODULE: COMBAT
-- In-combat helpers: absorb display, enemy counter, movement alert, input
-- safety and death / resurrection conveniences. One file per feature:
--   AbsorbDisplay, EnemyCounter, NoMovement, BlockRightClick, BlockSpaceCast,
--   AutoAcceptResurrection, AutoReleasePvP
-- ===========================================================================

ns:NewModule("Combat", {
    name  = "Combat",
    desc  = "Absorb, enemy counter, movement alert, input safety, resurrection",
    order = 4,
})
