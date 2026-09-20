local addonName, ns = ...

-- Covers direct player invites and Group Finder invites (M+, raid, etc.)

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "inviteSound",
    name = "Group Invite Sound",
    desc = "Plays a sound through Master when a group invite arrives.",
    sound = { kind = "kit", value = 8960, name = "Dungeon Finder Alarm" },
}

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PARTY_INVITE_REQUEST")
    ev:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
            local _, newStatus = ...
            if newStatus ~= "invited" then return end
        end
        F:PlaySound()
    end)
end
