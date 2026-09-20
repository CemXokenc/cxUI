local addonName, ns = ...

-- ===========================================================================
-- SOUNDS: QUEUE POP
-- Plays a sound the instant a dungeon/raid, battleground or arena queue pops.
-- Ported from BetterBlizzQueue (sound part only).
-- ===========================================================================

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "queuePopSound",
    name = "Queue Pop Sound",
    desc = "Plays a sound the moment a dungeon/raid, battleground, or arena queue pops.",
}

local QUEUE_POP_SOUND = 567458 -- same file BetterBlizzQueue used

function F:OnEnable()
    -- Dungeon / Raid (LFG proposal)
    local ev = self:NewEventFrame()
    ev:RegisterEvent("LFG_PROPOSAL_SHOW")
    ev:SetScript("OnEvent", function()
        local proposalExists, _, _, _, _, _, _, hasResponded = GetLFGProposal()
        if not proposalExists or hasResponded then return end
        S.PlayFile(QUEUE_POP_SOUND)
    end)

    -- Battleground / Arena
    self:Hook("PVPReadyDialog_Display", function() S.PlayFile(QUEUE_POP_SOUND) end)
end
