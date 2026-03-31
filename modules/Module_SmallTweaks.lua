local addonName, ns = ...

-- ===========================================================================
-- MODULE: SMALL TWEAKS
-- ===========================================================================

-- HIDE ALERTS (Talent Notifications)
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

-- MEGA MACRO OVERRIDE

local function OpenMegaMacro()
    -- Directly call MegaMacro's window show function
    if MegaMacroWindow and MegaMacroWindow.Show then
        MegaMacroWindow.Show()
    end

    -- Close standard Blizzard frames to prevent overlapping
    if not InCombatLockdown() then
        if MacroFrame and MacroFrame:IsShown() then
            HideUIPanel(MacroFrame)
        end
        
        if GameMenuFrame and GameMenuFrame:IsShown() then
            HideUIPanel(GameMenuFrame)
        end
    end
end

-- Intercept the default Macro UI call
hooksecurefunc("ShowMacroFrame", function()
    if CXUI_DB and CXUI_DB.overrideMacroFrame then
        OpenMegaMacro()
    end
end)

-- Replace the Game Menu button script for a seamless transition
if GameMenuButtonMacros then
    GameMenuButtonMacros:SetScript("OnClick", function()
        if CXUI_DB and CXUI_DB.overrideMacroFrame then
            OpenMegaMacro()
        else
            -- Call default Blizzard behavior
            ShowMacroFrame()
        end
    end)
end

-- AUDIO ALERTS
-- Plays ready check sound through the Master channel
 
local function OnReadyCheck()
    if not CXUI_DB.altTabAlerts then return end
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
end
 
-- EVENT HANDLER
local tweaksFrame = CreateFrame("Frame")
tweaksFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
tweaksFrame:RegisterEvent("ADDON_LOADED")
tweaksFrame:RegisterEvent("READY_CHECK")
 
tweaksFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, InitHideAlerts)
 
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HelpTip" then
        if CXUI_DB.hideAlerts then
            EnsureHelpTipHooks()
            HideAllHelpTips(UIParent, nil)
        end
 
    elseif event == "READY_CHECK" then
        OnReadyCheck()
    end
end)

-- RIGHT CLICK MODIFIER
-- Block Right-Click Targeting in Combat (Dungeons & Raids)

WorldFrame:HookScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" then return end
    if not CXUI_DB.rcm then return end
    local inInstance, instanceType = IsInInstance()    
	if inInstance and (instanceType == "party" or instanceType == "raid") and UnitAffectingCombat("player") then
        MouselookStop()
    end
end)