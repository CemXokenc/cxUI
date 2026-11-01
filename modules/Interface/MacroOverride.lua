local addonName, ns = ...

-- ===========================================================================
-- INTERFACE: MACRO WINDOW OVERRIDE
-- Redirects the default Macros menu button / frame to the cxUI macro window
-- (modules/Macros). Does nothing while the Macro Manager is not managing
-- macros, so Blizzard's own window stays available as a fallback.
-- ===========================================================================

local I = ns:GetModule("Interface")

local F = I:NewFeature{
    key  = "overrideMacroFrame",
    name = "Macro Window Override",
    desc = "Opens the cxUI macro window instead of Blizzard's when you press the 'Macros' menu button.",
}

local originalOnClick, replacedOnClick = nil, false

local function Ready()
    return ns.Macros and ns.Macros.Window and ns.Macros.IsManaging and ns.Macros.IsManaging()
end

local function OpenOurs()
    if not Ready() then return end
    ns.Macros.Window.Show()
    if not InCombatLockdown() then
        if MacroFrame and MacroFrame:IsShown() then HideUIPanel(MacroFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    end
end

function F:OnEnable()
    self:Hook("ShowMacroFrame", OpenOurs)
    if GameMenuButtonMacros and not replacedOnClick then
        originalOnClick = GameMenuButtonMacros:GetScript("OnClick")
        replacedOnClick = true
        GameMenuButtonMacros:SetScript("OnClick", function(...)
            if Ready() then OpenOurs() elseif originalOnClick then originalOnClick(...) end
        end)
    end
end

function F:OnDisable()
    if GameMenuButtonMacros and replacedOnClick then
        GameMenuButtonMacros:SetScript("OnClick", originalOnClick)
        replacedOnClick = false
    end
end
