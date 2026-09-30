local addonName, ns = ...

-- ===========================================================================
-- PREMIUM SOUNDS: the list of files the Premium random pools can draw from.
--
-- Turn Premium on/off with  /cx premium.  While it is on, the sound picker of
-- Execute Alert and Low Health Sound gets a "Premium" button; there you tick,
-- per feature, which of the files below join that feature's random pool
-- (together with the sound the feature currently has). Ticks are remembered
-- while Premium is off.
--
-- To add a sound:
--   1. put the .ogg into  media/Premium/
--   2. add its file name (with .ogg) as one more line below
-- The name shown in the window is the file name without ".ogg". The list order
-- is the order in the window. A file that is listed but missing is skipped
-- silently at play time.
-- ===========================================================================

ns.Sounds.PremiumFiles = {
    -- "Example Sound.ogg",
	"ExecuteAlert Summer.ogg",
	"LowHealthSound Summer.ogg",
}
