local addonName, ns = ...

-- ===========================================================================
-- INTERFACE: MEGA MACRO OVERRIDE
-- Redirects the default Macros button/frame to the Mega Macro addon.
-- ===========================================================================

local I = ns:GetModule("Interface")

local F = I:NewFeature{
    key  = "overrideMacroFrame",
    name = "Mega Macro Override",
    desc = "Redirects the default 'Macros' menu button to Mega Macro.",
}

local originalOnClick, replacedOnClick = nil, false

local function OpenMegaMacro()
    if MegaMacroWindow and MegaMacroWindow.Show then
        MegaMacroWindow.Show()
    end
    if not InCombatLockdown() then
        if MacroFrame and MacroFrame:IsShown() then HideUIPanel(MacroFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    end
end

function F:OnEnable()
    self:Hook("ShowMacroFrame", OpenMegaMacro)
    if GameMenuButtonMacros and not replacedOnClick then
        originalOnClick = GameMenuButtonMacros:GetScript("OnClick")
        replacedOnClick = true
        GameMenuButtonMacros:SetScript("OnClick", function() OpenMegaMacro() end)
    end
end

function F:OnDisable()
    if GameMenuButtonMacros and replacedOnClick then
        GameMenuButtonMacros:SetScript("OnClick", originalOnClick)
        replacedOnClick = false
    end
end
