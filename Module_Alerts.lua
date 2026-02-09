local addonName, ns = ...

-- ===========================================================================
-- MODULE: HIDE ALERTS (Talent Notifications)
-- ===========================================================================

-- This module hides annoying notifications about unspent talents,
-- hero talents, and other similar tips

local helpTipShowHooked = false

-- Function to hide all HelpTips
local function HideAllHelpTips(owner, info)
    if not CXUI_DB.hideAlerts then return end
    
    if HelpTip then
        if HelpTip.HideAllSystem then 
            HelpTip:HideAllSystem() 
        end
        if HelpTip.HideAll then 
            HelpTip:HideAll(owner or UIParent) 
        end
        if HelpTip.Hide and info and info.text then
            HelpTip:Hide(owner, info.text)
        end
    end
end

-- Hook the HelpTip show function
local function EnsureHelpTipHooks()
    if helpTipShowHooked then return end
    if not HelpTip then return end
    
    hooksecurefunc(HelpTip, "Show", function(_, owner, info)
        HideAllHelpTips(owner, info)
    end)
    
    helpTipShowHooked = true
end

-- Module initialization
local function InitHideAlerts()
    if not CXUI_DB.hideAlerts then return end
    
    -- Install hooks
    EnsureHelpTipHooks()
    
    -- Hide all existing tips
    HideAllHelpTips(UIParent, nil)
end

-- Initialize on load
local testFrame = CreateFrame("Frame")
testFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
testFrame:RegisterEvent("ADDON_LOADED")

testFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, InitHideAlerts)
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HelpTip" then
        -- HelpTip addon loaded - install hooks
        if CXUI_DB.hideAlerts then
            EnsureHelpTipHooks()
            HideAllHelpTips(UIParent, nil)
        end
    end
end)