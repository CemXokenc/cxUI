local addonName, ns = ...

-- ===========================================================================
-- MODULE: SETTINGS UI & DATABASE
-- ===========================================================================

-- If SavedVariables don't exist yet (first launch) start with an empty table.
-- All default values live exclusively in EnsureDBDefaults below.
CXUI_DB = CXUI_DB or {}

local function EnsureDBDefaults()
    local defaults = {
		---------------------------------
        hideBars                  = true,
        hideMicro                 = true,
        hideQuests                = true,
		---------------------------------
        cdmGlow                   = true,
        cdmGlowSuppressUntracked  = false,
		---------------------------------
        hideAlerts                = true,
        showAbsorb                = true,
        altTabAlerts              = true,		
        rcm                       = true,
        inviteSound               = true,
        pullTimerSound            = true,
        lowHealthAlert            = true,
        overrideMacroFrame        = true,
        mogMountFlyingInGround    = true,
		---------------------------------
        cdmEnemyCounter           = true,
        noMovement                = true,
        cdmPutrefyCross           = true,
        cdmFlurryCross            = true,
        cdmReaperCross            = true,
        cdmFrostBarSwap           = true,
        cdmFesteringGlow          = true,
        burningRushReminder       = true,
		---------------------------------
        autoAcceptResurrection    = false,
        autoReleasePvP            = false,
        dungeonFilter             = false,
        moveResetButton           = false,
        mailRememberRecipient     = false,
		---------------------------------
    }
    for k, v in pairs(defaults) do
        if CXUI_DB[k] == nil then CXUI_DB[k] = v end
    end
end

-- Registry of all checkboxes for explicit state refresh when the panel opens.
local allCheckboxes = {}

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
content:SetSize(560, 1080)
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

    check:SetScript("OnClick", function(self)
        CXUI_DB[dbKey] = self:GetChecked()
    end)

    -- Register for explicit refresh from the panel OnShow
    allCheckboxes[#allCheckboxes + 1] = { frame = check, key = dbKey }

    return check
end

local function CreateNote(text, yOffset, xOffset)
    local note = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", xOffset or 16, yOffset)
    note:SetText(text)
    return note
end

local L = 16   -- left column x
local R = 285  -- right column x

-- ---------------------------------------------------------------------------
-- Module 1 — Transparency & Auto-hide
-- ---------------------------------------------------------------------------
CreateHeader("Module 1: Transparency & Auto-hide", -10)
CreateCheckbox("Action Bar Auto-hide", "hideBars",   "Hides bars out of combat. Hover to reveal.",  -35, false, L)
CreateCheckbox("Micro Menu Auto-hide", "hideMicro",  "Hides Micro Menu and Bags. Hover to reveal.", -35, false, R)
CreateCheckbox("Quest Tracker Hover",  "hideQuests", "Quest tracker only visible on mouseover.",     -65, true,  L)

-- ---------------------------------------------------------------------------
-- Module 2 — CDM Glow
-- ---------------------------------------------------------------------------
CreateHeader("Module 2: CDM Glow", -105)
CreateCheckbox("Enable CDM Proc Glow",          "cdmGlow",                 "Special highlights for class-specific procs.",                        -130, false, L)
CreateCheckbox("Suppress Blizzard Glow on CDM", "cdmGlowSuppressUntracked","Hides all Blizzard proc glows on CDM frames. Action bars unaffected.", -130, false, R)
CreateNote("|cffff2020* If you are using MiniCC, then in its options under the Misc tab set the glow-type option to anything other than proc glow.|r", -152, L)

-- ---------------------------------------------------------------------------
-- Module 3 — Small Tweaks
-- ---------------------------------------------------------------------------
CreateHeader("Module 3: Small Tweaks", -175)
CreateCheckbox("Hide Talent Alerts",          "hideAlerts",         "Hides annoying talent-related notifications.",                            -200, true,  L)
CreateCheckbox("Enable Absorb Display",       "showAbsorb",         "Shows total shield amount in screen center.",                              -200, true,  R)
CreateCheckbox("Ready Check Alert",           "altTabAlerts",       "Plays ready check sound through Master channel. Audible when alt-tabbed.", -230, false, L)
CreateCheckbox("Block Right-Click in Combat", "rcm",                "Prevents accidental right-click targeting in dungeons and raids.",         -230, false, R)
CreateCheckbox("Group Invite Sound",          "inviteSound",        "Plays a sound through Master when a group invite arrives.",                 -260, false, L)
CreateCheckbox("Pull Timer Countdown Sound",  "pullTimerSound",     "Plays audio for the preparation countdown (5, 4, 3, 2, 1).",               -260, false, R)
CreateCheckbox("Low Health Sound Alert",      "lowHealthAlert",     "Plays a custom sound when your health is low.",                            -290, false, L)
CreateCheckbox("Mega Macro Override",         "overrideMacroFrame", "Redirects the default 'Macros' menu button to Mega Macro.",               -290, false, R)
CreateCheckbox("MogMount: Flying in Ground",  "mogMountFlyingInGround", "Allows picking a flying mount in MogMount's Ground slot. Requires MogMount addon.", -320, false, L)

-- ---------------------------------------------------------------------------
-- Module 4 — Class Features
-- ---------------------------------------------------------------------------
CreateHeader("Module 4: Class Features", -360)
CreateCheckbox("Enemy Counter",                     "cdmEnemyCounter",  "Shows nearby enemy count in the center of the screen. Works for all classes.", -385, false, L)
CreateCheckbox("No Movement",                       "noMovement",       "Shows movement ability cooldown when unavailable. Works for all classes.", -385, false, R)
CreateCheckbox("Putrefy Cross — Unholy DK",         "cdmPutrefyCross",  "Red x on Putrefy CDM when Dark Transformation has <9s CD.",         -415, false, L)
CreateCheckbox("Flurry Cross — Frost Mage",         "cdmFlurryCross",   "Red x on Flurry CDM when both procs (190446 & 1247729) active.",    -415, false, R)
CreateCheckbox("Reaper Cross — Unholy DK",          "cdmReaperCross",   "Red x on Reaper CDM when Dark Transformation has <10s CD.",         -445, false, L)
CreateCheckbox("Swap ST/AOE — Frost DK",            "cdmFrostBarSwap",  "Swap Obli/Scythe and FS/GA icons on CDM after action bars swaps.",  -445, false, R)
CreateCheckbox("Festering Strike Glow — Unholy DK", "cdmFesteringGlow", "White glow on Festering Strike/Scythe when buff has <5s left.",     -475, false, L)
CreateCheckbox("Burning Rush Reminder — Warlock",   "burningRushReminder", "Pulsing on-screen alert while Burning Rush is active.",              -475, false, R)

-- ---------------------------------------------------------------------------
-- Module 6 — Death, LFG & Mail
-- ---------------------------------------------------------------------------
CreateHeader("Module 6: Death, LFG & Mail", -505)
CreateCheckbox("Auto-Accept Resurrection", "autoAcceptResurrection", "Automatically accepts resurrection requests, but not while the resurrecting unit is in combat.", -530, false, L)
CreateCheckbox("Auto-Release in PvP",      "autoReleasePvP",         "Automatically releases your spirit in battlegrounds and supported world PvP zones, unless you can self-resurrect.", -530, false, R)
CreateCheckbox("Dungeon Finder: Advanced Filters", "dungeonFilter",  "Adds party-fit, Bloodlust/Battle Res and same-spec filters to the Dungeon Finder search list.", -560, true, L)
CreateCheckbox("Move 'Reset Filter' Button",       "moveResetButton","Shifts the Dungeon Browser's 'Reset Filter' button to the left side to avoid overlap.",         -560, true, R)
CreateCheckbox("Mail: Remember Last Recipient",    "mailRememberRecipient", "Keeps the last recipient in the mailbox 'To' field after sending until the mailbox is closed.", -590, false, L)

-- ---------------------------------------------------------------------------
-- Panel events
-- ---------------------------------------------------------------------------
-- HookScript instead of SetScript — preserves WoW's own OnShow set by the Settings API.
-- Explicitly refresh every checkbox so the UI always reflects CXUI_DB.
optionsPanel:HookScript("OnShow", function()
    EnsureDBDefaults()
    for _, cb in ipairs(allCheckboxes) do
        cb.frame:SetChecked(CXUI_DB[cb.key])
    end
end)

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