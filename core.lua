local addonName, ns = ...

-- ===========================================================================
-- MODULE: SETTINGS UI & DATABASE
-- ===========================================================================

-- Initialize database with default values if it doesn't exist
CXUI_DB = CXUI_DB or {
    hideBars = true,
    hideMicro = true,
    hideQuests = true,
    cdmGlow = true,
    cdmGlowSuppressUntracked = false,
    showAbsorb = true,
    hideAlerts = true,
	overrideMacroFrame = true,
	lowHealthAlert = true,
	altTabAlerts = true,
	rcm = true,
}

-- Ensure all keys exist (for existing characters with old DB)
local function EnsureDBDefaults()
    local defaults = {
        hideBars = true,
        hideMicro = true,
        hideQuests = true,
        cdmGlow = true,
        cdmGlowSuppressUntracked = false,
        showAbsorb = true,
        hideAlerts = true,
		overrideMacroFrame = true,
		lowHealthAlert = true,
		altTabAlerts = true,
		rcm = true,
    }
    for k, v in pairs(defaults) do
        if CXUI_DB[k] == nil then
            CXUI_DB[k] = v
        end
    end
end

local optionsPanel = CreateFrame("Frame", "CXUI_OptionsPanel", UIParent)
optionsPanel.name = "cxUI"

local reloadButton

-- Helper: Create a section header with a decorative line
local function CreateHeader(text, yOffset)
    local header = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, yOffset)
    header:SetText(text)
    local line = optionsPanel:CreateTexture(nil, "ARTWORK")
    line:SetSize(380, 1)
    line:SetPoint("TOPLEFT", 16, yOffset - 15)
    line:SetColorTexture(1, 1, 1, 0.2)
    return header
end

-- Helper: Create a checkbox linked to CXUI_DB
local function CreateCheckbox(label, dbKey, tooltipText, yOffset, needsReload)
    local check = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", 16, yOffset)
    local text = label
    if needsReload then text = text .. " |cffff0000(Requires Reload)*|r" end
    check.Text:SetText(text)
    
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltipText, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Set initial state when panel is shown
    check:SetScript("OnShow", function(self)
        -- Ensure DB is initialized
        EnsureDBDefaults()
        self:SetChecked(CXUI_DB[dbKey])
    end)
    
    check:SetScript("OnClick", function(self)
        local newValue = self:GetChecked()
        CXUI_DB[dbKey] = newValue
    end)
    return check
end

-- Title setup
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff0070ddCem Xokenc |cffffff00UI|r")

-- Module 1 Setup
CreateHeader("Module 1: Transparency & Auto-hide", -50)
CreateCheckbox("Action Bar Auto-hide", "hideBars", "Hides bars out of combat. Hover to reveal.", -75, false)
CreateCheckbox("Micro Menu Auto-hide", "hideMicro", "Hides Micro Menu and Bags. Hover to reveal.", -105, false)
CreateCheckbox("Quest Tracker Hover", "hideQuests", "Quest tracker only visible on mouseover.", -135, true)

-- Module 2 Setup
CreateHeader("Module 2: Absorb Display", -175)
CreateCheckbox("Enable Absorb Display", "showAbsorb", "Shows total shield amount in screen center.", -200, true)

-- Module 3 Setup
CreateHeader("Module 3: CDM Glow", -240)
CreateCheckbox("Enable CDM Proc Glow", "cdmGlow", "Special highlights for class-specific procs.", -265, false)
CreateCheckbox("Suppress Untracked Glows", "cdmGlowSuppressUntracked", "Only glow procs configured in PROC_CONFIG. All other CDM proc glows are hidden.", -295, false)

-- Module 4 Setup
CreateHeader("Module 4: Small Tweaks", -335)
CreateCheckbox("Hide Talent Alerts", "hideAlerts", "Hides annoying talent-related notifications.", -360, true)
CreateCheckbox("Mega Macro Override", "overrideMacroFrame", "Redirects the default 'Macros' menu button to Mega Macro.", -390, false)
CreateCheckbox("Ready Check Alert", "altTabAlerts", "Plays ready check sound through Master channel. Audible when alt-tabbed.", -420, false)
CreateCheckbox("Block Right-Click Targeting in Combat (Dungeons & Raids)", "rcm", "Prevents accidental right-click targeting in dungeons and raids.", -450, false)

-- Module 5 Setup: Low Health Alert
CreateHeader("Module 5: Health Safety", -490)
CreateCheckbox("Low Health Sound Alert", "lowHealthAlert", "Plays a custom sound when your health is low.", -515, false)


-- Reload Button setup (always red)
reloadButton = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate, UIPanelButtonTemplate")
reloadButton:SetSize(140, 30)
reloadButton:SetPoint("BOTTOMLEFT", 16, 16)
reloadButton:SetText("Reload UI")
reloadButton:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
-- Button is always red
reloadButton:SetBackdropColor(0.5, 0.1, 0.1, 1)
reloadButton:SetScript("OnClick", ReloadUI)

-- Ensure all settings are loaded when panel is shown
optionsPanel:SetScript("OnShow", function()
    EnsureDBDefaults()
end)

-- Safe registration for Settings API (multiple methods)
local function RegisterSettings()
    -- Method 1: Modern Settings API (11.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        category.ID = optionsPanel.name
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
    end
    
    -- Method 2: Legacy API (older versions)
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end
    
    -- Method 3: Direct addon settings (fallback)
    if SettingsPanel and SettingsPanel.AddOns then
        -- Register in addons list
        optionsPanel:SetParent(SettingsPanel.AddOns)
    end
end

-- Register after addon is loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "cxUI" then
        -- Ensure DB is fully initialized
        EnsureDBDefaults()
        -- Register settings panel with delay to ensure UI is ready
        C_Timer.After(0.5, RegisterSettings)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)