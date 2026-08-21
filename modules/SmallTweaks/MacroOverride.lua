local addonName, ns = ...
-- ===========================================================================
-- SMALL TWEAKS: MEGA MACRO OVERRIDE
-- Redirects the default Macros button/frame to Mega Macro addon.
-- ===========================================================================
local function OpenMegaMacro()
    if MegaMacroWindow and MegaMacroWindow.Show then
        MegaMacroWindow.Show()
    end
    if not InCombatLockdown() then
        if MacroFrame and MacroFrame:IsShown() then HideUIPanel(MacroFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    end
end
hooksecurefunc("ShowMacroFrame", function()
    if CXUI_DB and CXUI_DB.overrideMacroFrame then OpenMegaMacro() end
end)
if GameMenuButtonMacros then
    GameMenuButtonMacros:SetScript("OnClick", function()
        if CXUI_DB and CXUI_DB.overrideMacroFrame then
            OpenMegaMacro()
        else
            ShowMacroFrame()
        end
    end)
end
