local addonName, ns = ...

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "altTabAlerts",
    name = "Ready Check Alert",
    desc = "Plays ready check sound through Master channel. Audible when alt-tabbed.",
    sound = { kind = "kit", value = SOUNDKIT.READY_CHECK, name = "Ready Check" },
}

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("READY_CHECK")
    ev:SetScript("OnEvent", function() F:PlaySound() end)
end
