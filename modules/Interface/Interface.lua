local addonName, ns = ...

-- ===========================================================================
-- MODULE: INTERFACE
-- Blizzard UI cleanup and behaviour tweaks. One file per feature:
--   HideHelpTips, HideDurabilityMount, HideExtraActionDecor,
--   NoAutoClose, MacroOverride, TransmogOutfits
-- ===========================================================================

ns:NewModule("Interface", {
    name  = "Interface",
    desc  = "Blizzard UI cleanup and behaviour tweaks",
    order = 5,
})
