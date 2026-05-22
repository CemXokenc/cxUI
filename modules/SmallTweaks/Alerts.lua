local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: HIDE ALERTS
-- Suppresses talent-related HelpTip notifications.
-- ===========================================================================

local helpTipShowHooked = false

local function HideAllHelpTips(owner, info)
    if not CXUI_DB.hideAlerts then return end
    if HelpTip then
        if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
        if HelpTip.HideAll then HelpTip:HideAll(owner or UIParent) end
        if HelpTip.Hide and info and info.text then HelpTip:Hide(owner, info.text) end
    end
end

local function EnsureHelpTipHooks()
    if helpTipShowHooked then return end
    if not HelpTip then return end
    hooksecurefunc(HelpTip, "Show", function(_, owner, info)
        HideAllHelpTips(owner, info)
    end)
    helpTipShowHooked = true
end

local function InitHideAlerts()
    if not CXUI_DB.hideAlerts then return end
    EnsureHelpTipHooks()
    HideAllHelpTips(UIParent, nil)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, InitHideAlerts)
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HelpTip" then
        if CXUI_DB.hideAlerts then
            EnsureHelpTipHooks()
            HideAllHelpTips(UIParent, nil)
        end
    end
end)
