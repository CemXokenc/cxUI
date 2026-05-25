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
    cdmEnemyCounter           = true,
    cdmFesteringGlow          = true,
    cdmPutrefyCross           = true,
    cdmFlurryCross            = true,
    cdmReaperCross            = true,
    inviteSound               = true,
    pullTimerSound            = true,
    cdmFrostBarSwap           = true,
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
        cdmEnemyCounter           = true,
        cdmFesteringGlow          = true,
        cdmPutrefyCross           = true,
        cdmFlurryCross            = true,
        cdmReaperCross            = true,
        inviteSound               = true,
        pullTimerSound            = true,
        cdmFrostBarSwap           = true,
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
    line:SetSize(500, 1)
    line:SetPoint("TOPLEFT", 16, yOffset - 15)
    line:SetColorTexture(1, 1, 1, 0.2)
    return header
end

local function CreateCheckbox(label, dbKey, tooltipText, yOffset, needsReload, xOffset)
    local check = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", xOffset or 16, yOffset)
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

local L = 16   -- left column x
local R = 285  -- right column x

-- ---------------------------------------------------------------------------
-- Module 1 — 2 columns
-- ---------------------------------------------------------------------------
CreateHeader("Module 1: Transparency & Auto-hide", -10)
CreateCheckbox("Action Bar Auto-hide", "hideBars",   "Hides bars out of combat. Hover to reveal.",  -35, false, L)
CreateCheckbox("Micro Menu Auto-hide", "hideMicro",  "Hides Micro Menu and Bags. Hover to reveal.", -35, false, R)
CreateCheckbox("Quest Tracker Hover",  "hideQuests", "Quest tracker only visible on mouseover.",     -65, true,  L)

-- ---------------------------------------------------------------------------
-- Module 2
-- ---------------------------------------------------------------------------
CreateHeader("Module 2: Absorb Display", -105)
CreateCheckbox("Enable Absorb Display",  "showAbsorb", "Shows total shield amount in screen center.", -130, true)

-- ---------------------------------------------------------------------------
-- Module 3 — 2 columns
-- ---------------------------------------------------------------------------
CreateHeader("Module 3: CDM Glow", -170)
CreateCheckbox("Enable CDM Proc Glow",          "cdmGlow",                 "Special highlights for class-specific procs.",                    -195, false, L)
CreateCheckbox("Suppress Blizzard Glow on CDM", "cdmGlowSuppressUntracked","Hides all Blizzard proc glows on CDM frames. Action bars unaffected.", -195, false, R)

-- ---------------------------------------------------------------------------
-- Module 4 — 2 columns
-- ---------------------------------------------------------------------------
CreateHeader("Module 4: Small Tweaks", -235)
CreateCheckbox("Hide Talent Alerts",          "hideAlerts",         "Hides annoying talent-related notifications.",                            -260, true,  L)
CreateCheckbox("Mega Macro Override",         "overrideMacroFrame", "Redirects the default 'Macros' menu button to Mega Macro.",               -260, false, R)
CreateCheckbox("Ready Check Alert",           "altTabAlerts",       "Plays ready check sound through Master channel. Audible when alt-tabbed.", -290, false, L)
CreateCheckbox("Block Right-Click in Combat", "rcm",                "Prevents accidental right-click targeting in dungeons and raids.",         -290, false, R)
CreateCheckbox("Group Invite Sound",          "inviteSound",        "Plays a sound through Master when a group invite arrives.",                 -320, false, L)
CreateCheckbox("Pull Timer Countdown Sound",  "pullTimerSound",     "Plays audio for the preparation countdown (5, 4, 3, 2, 1).",               -320, false, R)
CreateCheckbox("Low Health Sound Alert",      "lowHealthAlert",     "Plays a custom sound when your health is low.",                            -350, false, L)

-- ---------------------------------------------------------------------------
-- Module 5 — 2 columns
-- ---------------------------------------------------------------------------
CreateHeader("Module 5: Class Features", -390)
CreateCheckbox("Enemy Counter — Unholy DK",         "cdmEnemyCounter",  "Shows enemy count on Death Coil CDM icon.",                         -415, false, L)
CreateCheckbox("Festering Strike Glow — Unholy DK", "cdmFesteringGlow", "White glow on Festering Strike/Scythe when buff has <5s left.",     -415, false, R)
CreateCheckbox("Putrefy Cross — Unholy DK",         "cdmPutrefyCross",  "Red x on Putrefy CDM when Dark Transformation has <9s CD.",         -445, false, L)
CreateCheckbox("Flurry Cross — Frost Mage",         "cdmFlurryCross",   "Red x on Flurry CDM when both procs (190446 & 1247729) active.",    -445, false, R)
CreateCheckbox("Swap ST/AOE — Frost DK",            "cdmFrostBarSwap",  "Swap Obli/Scythe and FS/GA icons on CDM after action bars swaps.",  -475, false, L)
CreateCheckbox("Reaper Cross — Unholy DK",          "cdmReaperCross",   "Red x on Reaper CDM when Dark Transformation has <10s CD.",         -475, false, R)

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