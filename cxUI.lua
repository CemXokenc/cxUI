-- ===========================================================================
-- COMBINED UI UTILITIES: ALPHA TRANSPARENCY & CDM PROC GLOW
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- MODULE 1: ALPHA TRANSPARENCY & UI UTILITIES
-- ---------------------------------------------------------------------------

local actionBarFrames = {
    MainActionBar,
    MultiBarBottomLeft,
    MultiBarBottomRight,
    MultiBarRight,
    StanceBar,
    PetActionBar,
}

local uiGroupFrames = {
    MicroMenuContainer,
    BagsBar,
}

local UPDATE_INTERVAL = 0.1
local timeSinceLastUpdate = 0
local isInCombat = false
local questTrackerHoverFrame = nil
local spellFlyout = SpellFlyout

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

local function IsMouseOverActionBars()
    if isInCombat then return false end
    if spellFlyout and spellFlyout:IsShown() and spellFlyout:IsMouseOver() then return true end
    for _, bar in ipairs(actionBarFrames) do
        if IsMouseOverUIFrame(bar) then return true end
    end
    return false
end

local function IsMouseOverUIGroup()
    for _, frame in ipairs(uiGroupFrames) do
        if IsMouseOverUIFrame(frame) then return true end
    end
    return false
end

local function SetActionBarsAlpha(alpha)
    for _, bar in ipairs(actionBarFrames) do
        if bar then bar:SetAlpha(alpha) end
    end
end

local function SetUIGroupAlpha(alpha)
    for _, frame in ipairs(uiGroupFrames) do
        if frame then frame:SetAlpha(alpha) end
    end
end

local function SetAlwaysVisibleFrames()
    if QueueStatusButton then
        QueueStatusButton:SetAlpha(1)
        QueueStatusButton:SetIgnoreParentAlpha(true)
    end
end

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

local function SetupQuestTrackerHover()
    if questTrackerHoverFrame then return end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    questTrackerHoverFrame = CreateFrame("Frame", "QuestTrackerHoverTrigger", UIParent)
    questTrackerHoverFrame:SetFrameStrata("LOW")
    questTrackerHoverFrame:SetFrameLevel(tracker:GetFrameLevel() - 1)
    questTrackerHoverFrame:SetPoint("TOPLEFT", tracker, "TOPLEFT", -15, 15)
    questTrackerHoverFrame:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 15, -15)
    questTrackerHoverFrame:EnableMouse(true)
    tracker:SetAlpha(0)
    questTrackerHoverFrame:SetScript("OnEnter", function() tracker:SetAlpha(1) end)
    questTrackerHoverFrame:SetScript("OnLeave", function() tracker:SetAlpha(0) end)
    questTrackerHoverFrame:SetScript("OnUpdate", function(self)
        if self.lastUpdate and GetTime() - self.lastUpdate < 0.5 then return end
        self.lastUpdate = GetTime()
        if tracker:IsShown() then self:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 15, -15) end
    end)
end

local absorbFrame = CreateFrame("Frame", "AlphaTransparencyAbsorbFrame", UIParent)
absorbFrame:SetSize(200, 30)
absorbFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
local absorbText = absorbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
absorbText:SetPoint("CENTER")
absorbText:SetTextColor(1, 1, 1, 1)
absorbText:SetText("")
absorbText:SetFont(absorbText:GetFont(), 18, "OUTLINE")

local function UpdateAbsorbDisplay()
    local totalAbsorb = UnitGetTotalAbsorbs("player") or 0
    absorbText:SetText(AbbreviateNumbers(totalAbsorb))
end

absorbFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
absorbFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
absorbFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" and unit ~= "player" then return end
    UpdateAbsorbDisplay()
end)

local function UpdateAlpha()
    if isInCombat then
        SetActionBarsAlpha(0)
    else
        local actionBarsAlpha = IsMouseOverActionBars() and 1 or 0
        SetActionBarsAlpha(actionBarsAlpha)
    end
    local uiGroupAlpha = IsMouseOverUIGroup() and 1 or 0
    SetUIGroupAlpha(uiGroupAlpha)
    SetAlwaysVisibleFrames()
end

local transparencyCore = CreateFrame("Frame")
transparencyCore:RegisterEvent("ADDON_LOADED")
transparencyCore:RegisterEvent("PLAYER_REGEN_DISABLED")
transparencyCore:RegisterEvent("PLAYER_REGEN_ENABLED")
transparencyCore:RegisterEvent("PLAYER_ENTERING_WORLD")

transparencyCore:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "AlphaTransparency" then
        SetActionBarsAlpha(0)
        SetUIGroupAlpha(0)
        SetAlwaysVisibleFrames()
        SetButtonsMouseEnabled(true)
        C_Timer.After(0.5, SetupQuestTrackerHover)
    elseif event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        SetActionBarsAlpha(0) 
        SetButtonsMouseEnabled(false) 
        SetAlwaysVisibleFrames()
    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        SetButtonsMouseEnabled(true)
        UpdateAlpha()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            SetActionBarsAlpha(0)
            SetUIGroupAlpha(0)
            SetAlwaysVisibleFrames()
            SetupQuestTrackerHover()
        end)
    end
end)

transparencyCore:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= UPDATE_INTERVAL then
        timeSinceLastUpdate = 0
        UpdateAlpha()
    end
end)

-- ---------------------------------------------------------------------------
-- MODULE 2: CDM PROC GLOW
-- ---------------------------------------------------------------------------

CDMProcGlowDB = CDMProcGlowDB or {}
local DB = CDMProcGlowDB
if DB.debug == nil then DB.debug = false end
if DB.enabled == nil then DB.enabled = true end

local PROC_CONFIG = {
    DEATHKNIGHT = { [81340] = { 47541, 207317 }, },
    WARRIOR = {}, PALADIN = {}, HUNTER = {}, ROGUE = {}, PRIEST = {},
    SHAMAN = {}, MAGE = {}, WARLOCK = {}, MONK = {}, DRUID = {},
    DEMONHUNTER = {}, EVOKER = {},
}

local PROC_TEMPLATES = {
    "ActionButtonSpellAlertTemplate",
    "ActionBarButtonSpellActivationAlert",
    "ActionButtonSpellActivationAlert",
    "SpellActivationAlertTemplate",
    "SpellActivationAlert",
}

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function EnsureGlowOverlay(btn)
    if not btn or (btn.IsForbidden and btn:IsForbidden()) then return nil end
    if btn.__CDMGlow_Alert then return btn.__CDMGlow_Alert end
    local w, h = 0, 0
    if btn.GetSize then w, h = btn:GetSize() end
    for i = 1, #PROC_TEMPLATES do
        local tmpl = PROC_TEMPLATES[i]
        local ok, f = pcall(CreateFrame, "Frame", nil, btn, tmpl)
        if ok and f then
            if w > 0 and h > 0 then f:SetSize(w * 1.4, h * 1.4) else f:SetAllPoints(btn) end
            f:SetPoint("CENTER", btn, "CENTER", 0, 0)
            f:SetFrameStrata("HIGH")
            f:SetFrameLevel((btn.GetFrameLevel and btn:GetFrameLevel() or 0) + 50)
            f:Hide()
            btn.__CDMGlow_Alert = f
            return f
        end
    end
    return nil
end

local function StartProcAnimations(alert)
    if not alert then return end
    local start = alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn
    local loop  = alert.ProcLoopAnim  or alert.procLoopAnim  or alert.AnimLoop or alert.animLoop
    local out   = alert.ProcEndAnim   or alert.procEndAnim   or alert.AnimOut  or alert.animOut
    if out and out.IsPlaying and out:IsPlaying() then pcall(out.Stop, out) end
    local function SafePlay(obj) if obj and obj.Play then pcall(obj.Play, obj) end end
    SafePlay(start or alert.ProcStartFlipbook or alert.procStartFlipbook)
    SafePlay(loop or alert.ProcLoopFlipbook or alert.procLoopFlipbook)
    SafePlay(alert.ProcLoopFlipbook2 or alert.procLoopFlipbook2)
    SafePlay(alert.ProcLoopFlipbook3 or alert.procLoopFlipbook3)
end

local function StopProcAnimations(alert)
    if not alert then return end
    local out = alert.ProcEndAnim or alert.procEndAnim or alert.AnimOut or alert.animOut
    if out and out.Play then pcall(out.Play, out); return end
    local function SafeStop(obj) if obj and obj.Stop then pcall(obj.Stop, obj) end end
    SafeStop(alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn)
    SafeStop(alert.ProcLoopAnim or alert.procLoopAnim or alert.AnimLoop or alert.animLoop)
end

local function ShowGlow(btn)
    local alert = EnsureGlowOverlay(btn)
    if alert then alert:Show(); StartProcAnimations(alert) end
end

local function HideGlow(btn)
    local alert = btn and btn.__CDMGlow_Alert
    if alert then StopProcAnimations(alert); alert:Hide() end
end

local CDMGlow = {
    class = nil, spellsByAura = {}, trackedSpells = {},
    buttonsByAura = {}, activeAuras = {}, overlayProcSpells = {},
    baseCost = {}, _updateTimer = nil
}

local function GetButtonSpellID(frame)
    if not frame then return nil end
    local sid = frame.spellID or frame.spellId or frame.spellid
    if type(sid) == "number" and not IsSecret(sid) then return sid end
    if frame.GetSpellID then
        local ok, v = pcall(frame.GetSpellID, frame)
        if ok and type(v) == "number" and not IsSecret(v) then return v end
    end
    return nil
end

local function ScanFrameTree(root, results, seen, depth)
    if not root or (seen[root]) or (depth or 0) > 20 then return end
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
            for i = 1, #children do ScanFrameTree(children[i], results, seen, (depth or 0) + 1) end
        end
    end
end

function CDMGlow:ScanCDMButtons()
    if InCombatLockdown() then return end
    for auraID, buttons in pairs(self.buttonsByAura) do
        if self.activeAuras[auraID] then
            for i = 1, #buttons do HideGlow(buttons[i]) end
        end
    end
    table.wipe(self.buttonsByAura)
    local knownNames = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "CooldownViewer", "BlizzardCooldownFrame"}
    local allButtons, seen = {}, {}
    for _, name in ipairs(knownNames) do ScanFrameTree(_G[name], allButtons, seen, 0) end
    for auraID in pairs(self.spellsByAura) do self.buttonsByAura[auraID] = {} end
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
    for auraID, buttons in pairs(self.buttonsByAura) do
        if self.activeAuras[auraID] then
            for i = 1, #buttons do ShowGlow(buttons[i]) end
        end
    end
end

local function PlayerHasAura(spellID)
    if _G.C_UnitAuras then
        local aura = _G.C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then return true end
    end
    return false
end

local function GetSpellRunicCost(spellID)
    local rpType = (_G.Enum and _G.Enum.PowerType and _G.Enum.PowerType.RunicPower) or 6
    local costs = _G.C_Spell and _G.C_Spell.GetSpellPowerCost and _G.C_Spell.GetSpellPowerCost(spellID)
    if costs then
        for i = 1, #costs do
            if costs[i].type == rpType then return costs[i].cost or costs[i].minCost end
        end
    end
    return nil
end

function CDMGlow:UpdateBaselineCosts()
    for auraID, spells in pairs(self.spellsByAura) do
        for i = 1, #spells do
            local cost = GetSpellRunicCost(spells[i])
            if cost then
                self.baseCost[spells[i]] = math.max(self.baseCost[spells[i]] or 0, cost)
            end
        end
    end
end

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

function CDMGlow:SetGlowForAura(auraID, active)
    if self.activeAuras[auraID] == active then return end
    local buttons = self.buttonsByAura[auraID]
    self.activeAuras[auraID] = active or nil
    if not buttons then return end
    if active then
        for i = 1, #buttons do ShowGlow(buttons[i]) end
    else
        for i = 1, #buttons do HideGlow(buttons[i]) end
    end
end

function CDMGlow:UpdateGlows()
    if not DB.enabled then
        for auraID in pairs(self.activeAuras) do self:SetGlowForAura(auraID, false) end
        return
    end
    for auraID in pairs(self.spellsByAura) do
        local hasAura = PlayerHasAura(auraID) or self.overlayProcSpells[auraID] or self:HasProcViaCost(auraID)
        self:SetGlowForAura(auraID, hasAura)
    end
end

function CDMGlow:ScheduleUpdate()
    if self._updateTimer then return end
    self._updateTimer = C_Timer.NewTimer(0.1, function()
        CDMGlow._updateTimer = nil
        CDMGlow:UpdateGlows()
    end)
end

local procEventFrame = CreateFrame("Frame")
procEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        CDMGlow.class = class
        if not PROC_CONFIG[class] then return end
        for auraID, spells in pairs(PROC_CONFIG[class]) do
            CDMGlow.spellsByAura[auraID] = spells
            for i = 1, #spells do CDMGlow.trackedSpells[spells[i]] = true end
        end
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        C_Timer.After(1.5, function()
            CDMGlow:ScanCDMButtons()
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)
    elseif event == "UNIT_AURA" and (...) == "player" then
        CDMGlow:ScheduleUpdate()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local sid = ...
        if CDMGlow.spellsByAura[sid] then 
            CDMGlow.overlayProcSpells[sid] = true
            CDMGlow:ScheduleUpdate()
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        if CDMGlow.overlayProcSpells[sid] then
            CDMGlow.overlayProcSpells[sid] = nil
            CDMGlow:ScheduleUpdate()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        CDMGlow:ScheduleUpdate()
    end
end)
procEventFrame:RegisterEvent("PLAYER_LOGIN")

SLASH_CDMGLOW1 = "/cdmglow"
SlashCmdList["CDMGLOW"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "rescan" then
        CDMGlow:ScanCDMButtons()
    elseif cmd == "on" then
        DB.enabled = true; CDMGlow:UpdateGlows()
    elseif cmd == "off" then
        DB.enabled = false; CDMGlow:UpdateGlows()
    end
end