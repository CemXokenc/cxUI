local addonName, ns = ...

-- SOUNDS: LOW HEALTH ALERT
-- Plays a custom sound whenever Blizzard's low-health screen warning appears.

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "lowHealthAlert",
    name = "Low Health Sound Alert",
    desc = "Plays a custom sound when your health is low.",
    sound = { kind = "file", value = ns.Media("LowHealthSound", "LowHealthSound.ogg"), name = "Low Health" },
}

function F:OnEnable()
    self:HookScript(LowHealthFrame, "OnShow", function()
        F:PlaySound()
    end)
end
