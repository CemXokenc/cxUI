local addonName, ns = ...

-- ===========================================================================
-- MODULE: SETTINGS UI & DATABASE
-- ===========================================================================

CXUI_DB = CXUI_DB or {
    hideBars                  = true,
    hideMicro                 = true,
    hideQuests                = true,
    cdmGlow                   = true,
    cdmGlowSuppressUntracked  = false,
    showAbsorb                = true,
    hideAlerts                = true,
    overrideMacroFrame        = true,
    lowHealthAlert            = true,
    altTabAlerts              = true,
    rcm                       = true,
    cdmAoESwap                = false,
}

local function EnsureDBDefaults()
    local defaults = {
        hideBars                  = true,
        hideMicro                 = true,
        hideQuests                = true,
        cdmGlow                   = true,
        cdmGlowSuppressUntracked  = false,
        showAbsorb                = true,
        hideAlerts                = true,
        overrideMacroFrame        = true,
        lowHealthAlert            = true,
        altTabAlerts              = true,
        rcm                       = true,
        cdmAoESwap                = false,
    }
    for k, v in pairs(defaults) do
        if CXUI_DB[k] == nil then CXUI_DB[k] = v end
    end
end

-- ---------------------------------------------------------------------------
-- Options panel
-- ---------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "CXUI_OptionsPanel", UIParent)
optionsPanel.name = "cxUI"

-- Title (outside scroll, always visible at top)
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff0070ddCem Xokenc |cffffff00UI|r")

-- Reload button (outside scroll, always visible at bottom)
local reloadButton = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate, UIPanelButtonTemplate")
reloadButton:SetSize(140, 30)
reloadButton:SetPoint("BOTTOMLEFT", 16, 16)
reloadButton:SetText("Reload UI")
reloadButton:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
reloadButton:SetBackdropColor(0.5, 0.1, 0.1, 1)
reloadButton:SetScript("OnClick", ReloadUI)

-- ScrollFrame fills the space between title and reload button.
local scrollFrame = CreateFrame("ScrollFrame", "CXUI_OptionsScroll", optionsPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",     optionsPanel, "TOPLEFT",     5,   -45)
scrollFrame:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -27,  55)

-- Content frame — tall enough to hold all checkboxes.
local content = CreateFrame("Frame", "CXUI_OptionsContent", scrollFrame)
content:SetSize(560, 800)
scrollFrame:SetScrollChild(content)

-- ---------------------------------------------------------------------------
-- Helpers — all widgets parent to `content`, positions are relative to it
-- ---------------------------------------------------------------------------
local function CreateHeader(text, yOffset)
    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, yOffset)
    header:SetText(text)
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetSize(380, 1)
    line:SetPoint("TOPLEFT", 16, yOffset - 15)
    line:SetColorTexture(1, 1, 1, 0.2)
    return header
end

local function CreateCheckbox(label, dbKey, tooltipText, yOffset, needsReload)
    local check = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
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
        EnsureDBDefaults()
        self:SetChecked(CXUI_DB[dbKey])
    end)

    check:SetScript("OnClick", function(self)
        CXUI_DB[dbKey] = self:GetChecked()
    end)

    return check
end

-- ---------------------------------------------------------------------------
-- Module 1
-- ---------------------------------------------------------------------------
CreateHeader("Module 1: Transparency & Auto-hide", -10)
CreateCheckbox("Action Bar Auto-hide",   "hideBars",   "Hides bars out of combat. Hover to reveal.",              -35,  false)
CreateCheckbox("Micro Menu Auto-hide",   "hideMicro",  "Hides Micro Menu and Bags. Hover to reveal.",             -65,  false)
CreateCheckbox("Quest Tracker Hover",    "hideQuests", "Quest tracker only visible on mouseover.",                 -95,  true)

-- ---------------------------------------------------------------------------
-- Module 2
-- ---------------------------------------------------------------------------
CreateHeader("Module 2: Absorb Display", -135)
CreateCheckbox("Enable Absorb Display",  "showAbsorb", "Shows total shield amount in screen center.",              -160, true)

-- ---------------------------------------------------------------------------
-- Module 3
-- ---------------------------------------------------------------------------
CreateHeader("Module 3: CDM Glow", -200)
CreateCheckbox("Enable CDM Proc Glow",       "cdmGlow",                  "Special highlights for class-specific procs.",                                         -225, false)
CreateCheckbox("Suppress Untracked Glows",   "cdmGlowSuppressUntracked", "Only glow procs in PROC_CONFIG. All other CDM proc glows are hidden.",                 -255, false)

-- ---------------------------------------------------------------------------
-- Module 4
-- ---------------------------------------------------------------------------
CreateHeader("Module 4: Small Tweaks", -295)
CreateCheckbox("Hide Talent Alerts",                               "hideAlerts",        "Hides annoying talent-related notifications.",                            -320, true)
CreateCheckbox("Mega Macro Override",                              "overrideMacroFrame","Redirects the default 'Macros' menu button to Mega Macro.",               -350, false)
CreateCheckbox("Ready Check Alert",                                "altTabAlerts",      "Plays ready check sound through Master channel. Audible when alt-tabbed.",-380, false)
CreateCheckbox("Block Right-Click Targeting in Combat (Dungeons & Raids)", "rcm",      "Prevents accidental right-click targeting in dungeons and raids.",         -410, false)

-- ---------------------------------------------------------------------------
-- Module 5
-- ---------------------------------------------------------------------------
CreateHeader("Module 5: Health Safety", -450)
CreateCheckbox("Low Health Sound Alert", "lowHealthAlert", "Plays a custom sound when your health is low.",        -475, false)

-- ---------------------------------------------------------------------------
-- Module 6
-- ---------------------------------------------------------------------------
CreateHeader("Module 6: Class Features", -515)
CreateCheckbox(
    "AoE Swap — Unholy DK",
    "cdmAoESwap",
    "Swaps the Death Coil icon in CDM with the recommended AoE spell based on visible enemy count.\n"
    .. "3+ enemies: Epidemic | Army active (<6): Necrotic Coil | Army active (6+): Graveyard.",
    -540,
    false
)

-- ---------------------------------------------------------------------------
-- Panel events
-- ---------------------------------------------------------------------------
optionsPanel:SetScript("OnShow", function() EnsureDBDefaults() end)

-- ---------------------------------------------------------------------------
-- Settings API registration
-- ---------------------------------------------------------------------------
local function RegisterSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        category.ID = optionsPanel.name
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
    end
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "cxUI" then
        EnsureDBDefaults()
        C_Timer.After(0.5, RegisterSettings)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)