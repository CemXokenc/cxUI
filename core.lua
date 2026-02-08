local addonName, ns = ...

-- ===========================================================================
-- MODULE 0: SETTINGS UI & DATABASE
-- ===========================================================================

-- Initialize database with default values if it doesn't exist
CXUI_DB = CXUI_DB or {
    hideBars = true,
    hideMicro = true,
    hideQuests = true,
    cdmGlow = true,
    showAbsorb = true
}

-- Ensure all keys exist (for existing characters with old DB)
local function EnsureDBDefaults()
    local defaults = {
        hideBars = true,
        hideMicro = true,
        hideQuests = true,
        cdmGlow = true,
        showAbsorb = true,
        hideAlerts = true
    }
    for k, v in pairs(defaults) do
        if CXUI_DB[k] == nil then
            CXUI_DB[k] = v
        end
    end
end

EnsureDBDefaults()

local optionsPanel = CreateFrame("Frame", "CXUI_OptionsPanel", UIParent)
optionsPanel.name = "cxUI"

local panelOpenSnapshot = {}  -- Snapshot when panel opens
local reloadButton

-- Detect if critical settings (requiring ReloadUI) have changed since panel was opened
local function ReloadRequiredSettingsChanged()
    local criticalKeys = { "hideQuests", "showAbsorb" }
    for _, k in ipairs(criticalKeys) do
        if CXUI_DB[k] ~= panelOpenSnapshot[k] then return true end
    end
    return false
end

-- Change button color to red if a reload is necessary
local function UpdateReloadButtonStyle()
    if not reloadButton then return end
    if ReloadRequiredSettingsChanged() then
        reloadButton:SetBackdropColor(0.5, 0.1, 0.1, 1) -- Muted Red
    else
        reloadButton:SetBackdropColor(0.2, 0.2, 0.2, 1) -- Standard Grey
    end
end

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
    
    check:SetScript("OnShow", function(self)
        self:SetChecked(CXUI_DB[dbKey])
        UpdateReloadButtonStyle()
    end)
    
    check:SetScript("OnClick", function(self)
        local newValue = self:GetChecked()
        CXUI_DB[dbKey] = newValue
        UpdateReloadButtonStyle()
    end)
    return check
end

-- Title setup
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff0070ddcem|cffffff00xokenc|r UI")

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

-- Reload Button setup
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
reloadButton:SetScript("OnClick", ReloadUI)

optionsPanel:SetScript("OnShow", function()
    table.wipe(panelOpenSnapshot)
    for k, v in pairs(CXUI_DB) do 
        panelOpenSnapshot[k] = v 
    end
    UpdateReloadButtonStyle()
end)

-- Safe registration for Settings API
local function RegisterSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

C_Timer.After(0.1, RegisterSettings)