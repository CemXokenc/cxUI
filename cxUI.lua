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
        -- Always display current DB state
        self:SetChecked(CXUI_DB[dbKey])
        UpdateReloadButtonStyle()
    end)
    
    check:SetScript("OnClick", function(self)
        local newValue = self:GetChecked()
        CXUI_DB[dbKey] = newValue
        -- Force save to disk
        if type(CXUI_DB) == "table" then
            -- DB will auto-save, but we ensure the value is written immediately
        end
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
    -- Take snapshot of current settings when panel opens
    -- This becomes the baseline for detecting changes
    table.wipe(panelOpenSnapshot)
    for k, v in pairs(CXUI_DB) do 
        panelOpenSnapshot[k] = v 
    end
    UpdateReloadButtonStyle()
end)

-- Safe registration for Settings API (Midnight compatibility)
local function RegisterSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
    elseif InterfaceOptions_AddCategory then
        -- Fallback for older API
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

C_Timer.After(0.1, RegisterSettings)

-- ===========================================================================
-- MODULE 1: TRANSPARENCY LOGIC
-- ===========================================================================

local actionBarFrames = { MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, StanceBar, PetActionBar }
local uiGroupFrames = { MicroMenuContainer, BagsBar }
local UPDATE_INTERVAL, timeSinceLastUpdate, isInCombat, questTrackerHoverFrame = 0.1, 0, false, nil
local spellFlyout = SpellFlyout

-- Check if mouse is hovering over a frame or its internal buttons
local function IsMouseOverUIFrame(frame)
    if not frame then return false end
    if frame:IsMouseOver() then return true end
    if frame.actionButtons then
        for _, button in pairs(frame.actionButtons) do
            if button and button:IsMouseOver() then return true end
        end
    end
    return false
end

-- Mouseover check for all action bars
local function IsMouseOverActionBars()
    if not CXUI_DB.hideBars or isInCombat then return false end
    if spellFlyout and spellFlyout:IsShown() and spellFlyout:IsMouseOver() then return true end
    for _, bar in ipairs(actionBarFrames) do
        if IsMouseOverUIFrame(bar) then return true end
    end
    return false
end

-- Mouseover check for Micro Menu and Bags
local function IsMouseOverUIGroup()
    if not CXUI_DB.hideMicro then return false end
    for _, frame in ipairs(uiGroupFrames) do
        if IsMouseOverUIFrame(frame) then return true end
    end
    return false
end

local function SetActionBarsAlpha(alpha)
    for _, bar in ipairs(actionBarFrames) do if bar then bar:SetAlpha(alpha) end end
end

local function SetUIGroupAlpha(alpha)
    for _, frame in ipairs(uiGroupFrames) do if frame then frame:SetAlpha(alpha) end end
end

-- Maintain visibility for essential UI elements (e.g., LFG status)
local function SetAlwaysVisibleFrames()
    if QueueStatusButton then
        QueueStatusButton:SetAlpha(1)
        QueueStatusButton:SetIgnoreParentAlpha(true)
    end
end

-- Toggle clickability for hidden elements to prevent misclicks
local function SetButtonsMouseEnabled(enabled)
    for _, bar in ipairs(actionBarFrames) do
        if bar and bar.actionButtons then
            for _, button in pairs(bar.actionButtons) do
                if button then
                    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(enabled) end
                    button:EnableMouse(enabled)
                end
            end
        end
    end
end

-- Create a dedicated hover frame for the Objective Tracker
local function SetupQuestTrackerHover()
    if questTrackerHoverFrame or not CXUI_DB.hideQuests then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    questTrackerHoverFrame = CreateFrame("Frame", nil, UIParent)
    questTrackerHoverFrame:SetFrameStrata("LOW")
    questTrackerHoverFrame:SetPoint("TOPLEFT", tracker, -15, 15)
    questTrackerHoverFrame:SetPoint("BOTTOMRIGHT", tracker, 15, -15)
    questTrackerHoverFrame:EnableMouse(true)
    tracker:SetAlpha(0)
    questTrackerHoverFrame:SetScript("OnEnter", function() tracker:SetAlpha(1) end)
    questTrackerHoverFrame:SetScript("OnLeave", function() tracker:SetAlpha(0) end)
    questTrackerHoverFrame:SetScript("OnUpdate", function(self)
        if self.lastUpdate and GetTime() - self.lastUpdate < 0.5 then return end
        self.lastUpdate = GetTime()
        if tracker:IsShown() then self:SetPoint("BOTTOMRIGHT", tracker, 15, -15) end
    end)
end

-- Update alpha based on combat and hover states
-- FIXED: Now respects hideBars setting even during combat
local function UpdateAlpha()
    if isInCombat then 
        -- Respect the hideBars setting even in combat
        SetActionBarsAlpha(CXUI_DB.hideBars and 0 or 1)
    else 
        SetActionBarsAlpha(IsMouseOverActionBars() and 1 or (CXUI_DB.hideBars and 0 or 1)) 
    end
    SetUIGroupAlpha(IsMouseOverUIGroup() and 1 or (CXUI_DB.hideMicro and 0 or 1))
    SetAlwaysVisibleFrames()
end

local transparencyCore = CreateFrame("Frame")
transparencyCore:RegisterEvent("ADDON_LOADED")
transparencyCore:RegisterEvent("PLAYER_REGEN_DISABLED")
transparencyCore:RegisterEvent("PLAYER_REGEN_ENABLED")
transparencyCore:RegisterEvent("PLAYER_ENTERING_WORLD")

transparencyCore:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "cemxokenc" then
        UpdateAlpha()
        SetButtonsMouseEnabled(true)
        C_Timer.After(0.5, SetupQuestTrackerHover)
    elseif event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        -- Only disable mouse if hiding is enabled
        if CXUI_DB.hideBars then 
            SetButtonsMouseEnabled(false) 
        end
        -- UpdateAlpha will handle the visibility based on settings
        UpdateAlpha()
    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        SetButtonsMouseEnabled(true)
        UpdateAlpha()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function() UpdateAlpha(); SetupQuestTrackerHover() end)
    end
end)

-- Periodically check mouse position
transparencyCore:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= UPDATE_INTERVAL then
        timeSinceLastUpdate = 0
        UpdateAlpha()
    end
end)

-- ===========================================================================
-- MODULE 2: ABSORB LOGIC
-- ===========================================================================

local absorbFrame = CreateFrame("Frame", nil, UIParent)
absorbFrame:SetSize(200, 30)
absorbFrame:SetPoint("CENTER", 0, 30)
local absorbText = absorbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
absorbText:SetPoint("CENTER")
absorbText:SetTextColor(1, 1, 1, 1)
absorbText:SetFont(absorbText:GetFont(), 18, "OUTLINE")

-- Update the absorb numeric text
local function UpdateAbsorbDisplay()
    if not CXUI_DB.showAbsorb then absorbText:SetText(""); return end
    local totalAbsorb = UnitGetTotalAbsorbs("player") or 0
    absorbText:SetText(AbbreviateNumbers(totalAbsorb))
end

absorbFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
absorbFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
absorbFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" and unit ~= "player" then return end
    UpdateAbsorbDisplay()
end)

-- ===========================================================================
-- MODULE 3: CDM GLOW LOGIC
-- ===========================================================================

CDMProcGlowDB = CDMProcGlowDB or { enabled = true }
local DB = CDMProcGlowDB

-- Spell mapping for class procs
local PROC_CONFIG = {
    DEATHKNIGHT = { [81340] = { 47541, 207317 } },
    WARRIOR = {}, PALADIN = {}, HUNTER = {}, ROGUE = {}, PRIEST = {},
    SHAMAN = {}, MAGE = {}, WARLOCK = {}, MONK = {}, DRUID = {},
    DEMONHUNTER = {}, EVOKER = {},
}

-- List of usable glow templates from Blizzard's UI
local PROC_TEMPLATES = {
    "ActionButtonSpellAlertTemplate",
    "ActionBarButtonSpellActivationAlert",
    "ActionButtonSpellActivationAlert",
    "SpellActivationAlertTemplate",
    "SpellActivationAlert",
}

-- Safety check for Blizzard's protected values (Midnight security)
local function IsSecret(v) 
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false 
end

-- Safe frame check for forbidden frames (Midnight protection)
local function IsSafeFrame(frame)
    if not frame then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

-- Create or find a glow overlay frame for a given button
local function EnsureGlowOverlay(btn)
    if not IsSafeFrame(btn) then return nil end
    if btn.__CDMGlow_Alert then return btn.__CDMGlow_Alert end
    
    local w, h = 0, 0
    if btn.GetSize then 
        local ok, width, height = pcall(btn.GetSize, btn)
        if ok then w, h = width, height end
    end
    
    for i = 1, #PROC_TEMPLATES do
        local tmpl = PROC_TEMPLATES[i]
        local ok, f = pcall(CreateFrame, "Frame", nil, btn, tmpl)
        if ok and f and IsSafeFrame(f) then
            if w > 0 and h > 0 then 
                pcall(f.SetSize, f, w * 1.4, h * 1.4) 
            else 
                pcall(f.SetAllPoints, f, btn) 
            end
            pcall(f.SetPoint, f, "CENTER", 0, 0)
            pcall(f.SetFrameStrata, f, "HIGH")
            local level = 0
            if btn.GetFrameLevel then 
                local ok2, lvl = pcall(btn.GetFrameLevel, btn)
                if ok2 then level = lvl end
            end
            pcall(f.SetFrameLevel, f, level + 50)
            f:Hide()
            btn.__CDMGlow_Alert = f
            return f
        end
    end
    return nil
end

-- Handle animations for showing the glow
local function StartProcAnimations(alert)
    if not alert then return end
    local start = alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn
    local loop  = alert.ProcLoopAnim  or alert.procLoopAnim  or alert.AnimLoop or alert.animLoop
    local out   = alert.ProcEndAnim   or alert.procEndAnim   or alert.AnimOut  or alert.animOut
    
    if out and out.IsPlaying then 
        local ok, isPlaying = pcall(out.IsPlaying, out)
        if ok and isPlaying then pcall(out.Stop, out) end
    end
    
    local function SafePlay(obj) 
        if obj and obj.Play then pcall(obj.Play, obj) end 
    end
    
    SafePlay(start or alert.ProcStartFlipbook or alert.procStartFlipbook)
    SafePlay(loop or alert.ProcLoopFlipbook or alert.procLoopFlipbook)
    SafePlay(alert.ProcLoopFlipbook2 or alert.procLoopFlipbook2)
    SafePlay(alert.ProcLoopFlipbook3 or alert.procLoopFlipbook3)
end

-- Handle animations for hiding the glow
local function StopProcAnimations(alert)
    if not alert then return end
    local out = alert.ProcEndAnim or alert.procEndAnim or alert.AnimOut or alert.animOut
    if out and out.Play then pcall(out.Play, out); return end
    
    local function SafeStop(obj) 
        if obj and obj.Stop then pcall(obj.Stop, obj) end 
    end
    
    SafeStop(alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn)
    SafeStop(alert.ProcLoopAnim or alert.procLoopAnim or alert.AnimLoop or alert.animLoop)
end

local function ShowGlow(btn) 
    if not IsSafeFrame(btn) then return end
    local alert = EnsureGlowOverlay(btn)
    if alert then 
        pcall(alert.Show, alert)
        StartProcAnimations(alert) 
    end 
end

local function HideGlow(btn) 
    if not IsSafeFrame(btn) then return end
    local alert = btn.__CDMGlow_Alert
    if alert then 
        StopProcAnimations(alert)
        pcall(alert.Hide, alert)
    end 
end

local CDMGlow = { 
    class = nil, 
    spellsByAura = {}, 
    trackedSpells = {}, 
    buttonsByAura = {}, 
    activeAuras = {}, 
    overlayProcSpells = {}, 
    baseCost = {}, 
    _updateTimer = nil 
}

-- Try to resolve spellID from a button frame
local function GetButtonSpellID(frame)
    if not IsSafeFrame(frame) then return nil end
    
    local sid = frame.spellID or frame.spellId or frame.spellid
    if type(sid) == "number" and not IsSecret(sid) then return sid end
    
    if frame.GetSpellID then 
        local ok, v = pcall(frame.GetSpellID, frame)
        if ok and type(v) == "number" and not IsSecret(v) then return v end
    end
    
    return nil
end

-- Search for specific action buttons in the global UI tree
local function ScanFrameTree(root, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    
    seen[root] = true
    
    if root.GetObjectType then
        local ok, ot = pcall(root.GetObjectType, root)
        if ok and (ot == "Button" or ot == "Frame") then
            local spellID = GetButtonSpellID(root)
            if spellID and CDMGlow.trackedSpells[spellID] then 
                results[#results + 1] = { button = root, spellID = spellID } 
            end
        end
    end
    
    if root.GetChildren then 
        local ok, children = pcall(function() return {root:GetChildren()} end)
        if ok and children then 
            for i = 1, #children do 
                ScanFrameTree(children[i], results, seen, depth + 1) 
            end 
        end
    end
end

-- Get Runic Power cost for a spell (Midnight compatible)
local function GetSpellRunicCost(spellID)
    local rpType = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6
    
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        if ok and costs then 
            for i = 1, #costs do 
                if costs[i].type == rpType then 
                    return costs[i].cost or costs[i].minCost 
                end 
            end 
        end
    end
    
    return nil
end

-- Record the baseline costs of tracked spells
function CDMGlow:UpdateBaselineCosts()
    for auraID, spells in pairs(self.spellsByAura) do
        for i = 1, #spells do
            local cost = GetSpellRunicCost(spells[i])
            if cost then self.baseCost[spells[i]] = math.max(self.baseCost[spells[i]] or 0, cost) end
        end
    end
end

-- Check if a spell currently has a cost reduction proc
function CDMGlow:HasProcViaCost(auraID)
    local spells = self.spellsByAura[auraID]
    if not spells then return false end
    for i = 1, #spells do
        local base = self.baseCost[spells[i]]
        local current = GetSpellRunicCost(spells[i])
        if base and current and current <= (base - 1) then return true end
    end
    return false
end

-- Associate found buttons with tracked aura IDs
function CDMGlow:ScanCDMButtons()
    if InCombatLockdown() then return end
    
    -- Clear old glows
    for auraID, buttons in pairs(self.buttonsByAura) do
        if self.activeAuras[auraID] then 
            for i = 1, #buttons do HideGlow(buttons[i]) end 
        end
    end
    
    table.wipe(self.buttonsByAura)
    
    local knownNames = {
        "EssentialCooldownViewer", 
        "UtilityCooldownViewer", 
        "BuffIconCooldownViewer", 
        "CooldownViewer", 
        "BlizzardCooldownFrame"
    }
    
    local allButtons, seen = {}, {}
    for _, name in ipairs(knownNames) do 
        if _G[name] then
            ScanFrameTree(_G[name], allButtons, seen, 0) 
        end
    end
    
    for auraID in pairs(self.spellsByAura) do 
        self.buttonsByAura[auraID] = {} 
    end
    
    for i = 1, #allButtons do
        local entry = allButtons[i]
        for auraID, spells in pairs(self.spellsByAura) do
            for j = 1, #spells do 
                if spells[j] == entry.spellID then 
                    table.insert(self.buttonsByAura[auraID], entry.button) 
                end 
            end
        end
    end
    
    -- Reapply active glows
    for auraID, buttons in pairs(self.buttonsByAura) do
        if self.activeAuras[auraID] then 
            for i = 1, #buttons do ShowGlow(buttons[i]) end 
        end
    end
end

-- Manage glow visibility based on aura presence or cost shifts
function CDMGlow:UpdateGlows()
    if not CXUI_DB.cdmGlow or not DB.enabled then
        for auraID in pairs(self.activeAuras) do
            local btns = self.buttonsByAura[auraID]
            if btns then 
                for i = 1, #btns do HideGlow(btns[i]) end 
            end
        end
        return
    end
    
    for auraID in pairs(self.spellsByAura) do
        local hasAura = false
        
        -- Check via C_UnitAuras (Midnight compatible)
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
            hasAura = (ok and aura ~= nil)
        end
        
        -- Check overlay or cost reduction
        hasAura = hasAura or self.overlayProcSpells[auraID] or self:HasProcViaCost(auraID)
        
        if self.activeAuras[auraID] ~= hasAura then
            self.activeAuras[auraID] = hasAura
            local btns = self.buttonsByAura[auraID]
            if btns then 
                for _, b in ipairs(btns) do 
                    if hasAura then ShowGlow(b) else HideGlow(b) end 
                end 
            end
        end
    end
end

local procEventFrame = CreateFrame("Frame")
procEventFrame:RegisterEvent("PLAYER_LOGIN")
procEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        if not PROC_CONFIG[class] then return end
        
        for auraID, spells in pairs(PROC_CONFIG[class]) do
            CDMGlow.spellsByAura[auraID] = spells
            for i = 1, #spells do CDMGlow.trackedSpells[spells[i]] = true end
        end
        
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        
        C_Timer.After(1.5, function() 
            CDMGlow:ScanCDMButtons()
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows() 
        end)
    elseif event == "UNIT_AURA" and (...) == "player" then 
        CDMGlow:UpdateGlows()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local sid = ...
        if CDMGlow.spellsByAura[sid] then 
            CDMGlow.overlayProcSpells[sid] = true
            CDMGlow:UpdateGlows() 
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        if CDMGlow.overlayProcSpells[sid] then 
            CDMGlow.overlayProcSpells[sid] = nil
            CDMGlow:UpdateGlows() 
        end
    end
end)

-- Slash command handlers
SLASH_CDMGLOW1 = "/cdmglow"
SlashCmdList["CDMGLOW"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "rescan" then 
        CDMGlow:ScanCDMButtons()
        print("|cff0070ddcxUI:|r Rescanning CDM buttons...")
    elseif cmd == "on" then 
        DB.enabled = true
        CDMGlow:UpdateGlows()
        print("|cff0070ddcxUI:|r CDM Glow enabled")
    elseif cmd == "off" then 
        DB.enabled = false
        CDMGlow:UpdateGlows() 
        print("|cff0070ddcxUI:|r CDM Glow disabled")
    else
        print("|cff0070ddcxUI CDM Glow:|r /cdmglow [on|off|rescan]")
    end
end
