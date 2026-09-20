local addonName, ns = ...

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "altTabAlerts",
    name = "Ready Check Alert",
    desc = "Plays ready check sound through Master channel. Audible when alt-tabbed.",
}

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("READY_CHECK")
    ev:SetScript("OnEvent", function() S.PlayKit(SOUNDKIT.READY_CHECK) end)
end
