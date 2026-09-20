local addonName, ns = ...

-- ===========================================================================
-- MODULE: SOUNDS
-- Audio alerts. Everything plays through the Master channel so it stays
-- audible when the game is alt-tabbed. Helpers shared by the feature files:
-- ===========================================================================

local S = ns:NewModule("Sounds", {
    name  = "Sounds",
    desc  = "Audio alerts for ready checks, invites, queues and pulls",
    order = 6,
})

function S.PlayKit(soundKitID)
    PlaySound(soundKitID, "Master")
end

function S.PlayFile(pathOrFileID)
    return PlaySoundFile(pathOrFileID, "Master")
end
