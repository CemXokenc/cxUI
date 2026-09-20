local addonName, ns = ...

-- ===========================================================================
-- MODULE: MYTHIC+
-- Alerts, teleports and timer add-ons for Mythic+ and dungeon play. One file
-- per feature:
--   ExternalAlert, DispelAlert, ESCTeleports, BossTimerPreview
-- Shared helpers:
-- ===========================================================================

local MP = ns:NewModule("MythicPlus", {
    name  = "Mythic+",
    desc  = "Alerts, teleports and timer add-ons for dungeons",
    order = 9,
})

-- Alert sounds must stay silent while the player is arranging the UI.
function MP.IsInEditMode()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

function MP.PlayFile(pathOrFileID)
    return PlaySoundFile(pathOrFileID, "Master")
end
