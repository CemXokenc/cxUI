local addonName, ns = ...

-- ===========================================================================
-- INTERFACE: HIDE TALENT ALERTS
-- Suppresses talent-related HelpTip notifications.
-- ===========================================================================

local I = ns:GetModule("Interface")

local F = I:NewFeature{
    key  = "hideAlerts",
    name = "Hide Talent Alerts",
    desc = "Hides annoying talent-related notifications.",
}

local function HideAllHelpTips(owner, info)
    if not HelpTip then return end
    if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
    if HelpTip.HideAll then HelpTip:HideAll(owner or UIParent) end
    if HelpTip.Hide and info and info.text then HelpTip:Hide(owner, info.text) end
end

local function Init()
    if HelpTip then
        F:Hook(HelpTip, "Show", function(_, owner, info) HideAllHelpTips(owner, info) end)
    end
    HideAllHelpTips(UIParent, nil)
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            F:After(1, Init)
        elseif arg1 == "Blizzard_HelpTip" then
            Init()
        end
    end)
    Init()
end
