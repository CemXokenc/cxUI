local addonName, ns = ...

-- ===========================================================================
-- MODULE 3: CDM GLOW LOGIC
-- ===========================================================================

CDMProcGlowDB = CDMProcGlowDB or { enabled = true }
local DB = CDMProcGlowDB

local PROC_CONFIG = {
    DEATHKNIGHT = { [81340] = { 47541, 207317 } },
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

local function IsSafeFrame(frame)
    if not frame then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

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
            if w > 0 and h > 0 then pcall(f.SetSize, f, w * 1.4, h * 1.4) else pcall(f.SetAllPoints, f, btn) end
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

local function StartProcAnimations(alert)
    if not alert then return end
    local start = alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn
    local loop  = alert.ProcLoopAnim  or alert.procLoopAnim  or alert.AnimLoop or alert.animLoop
    local out   = alert.ProcEndAnim   or alert.procEndAnim   or alert.AnimOut  or alert.animOut
    
    if out and out.IsPlaying then 
        local ok, isPlaying = pcall(out.IsPlaying, out)
        if ok and isPlaying then pcall(out.Stop, out) end
    end
    
    local function SafePlay(obj) if obj and obj.Play then pcall(obj.Play, obj) end end
    SafePlay(start or alert.ProcStartFlipbook or alert.procStartFlipbook)
    SafePlay(loop or alert.ProcLoopAnim or alert.animLoop)
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
    if not IsSafeFrame(btn) then return end
    local alert = EnsureGlowOverlay(btn)
    if alert then pcall(alert.Show, alert); StartProcAnimations(alert) end 
end

local function HideGlow(btn) 
    if not IsSafeFrame(btn) then return end
    local alert = btn.__CDMGlow_Alert
    if alert then StopProcAnimations(alert); pcall(alert.Hide, alert) end 
end

local CDMGlow = { class = nil, spellsByAura = {}, trackedSpells = {}, buttonsByAura = {}, activeAuras = {}, overlayProcSpells = {}, baseCost = {} }

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

local function ScanFrameTree(root, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true
    if root.GetObjectType then
        local ok, ot = pcall(root.GetObjectType, root)
        if ok and (ot == "Button" or ot == "Frame") then
            local spellID = GetButtonSpellID(root)
            if spellID and CDMGlow.trackedSpells[spellID] then results[#results + 1] = { button = root, spellID = spellID } end
        end
    end
    if root.GetChildren then 
        local ok, children = pcall(function() return {root:GetChildren()} end)
        if ok and children then for i = 1, #children do ScanFrameTree(children[i], results, seen, depth + 1) end end
    end
end

local function GetSpellRunicCost(spellID)
    local rpType = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        if ok and costs then for i = 1, #costs do if costs[i].type == rpType then return costs[i].cost or costs[i].minCost end end end
    end
    return nil
end

function CDMGlow:UpdateBaselineCosts()
    for auraID, spells in pairs(self.spellsByAura) do
        for i = 1, #spells do
            local cost = GetSpellRunicCost(spells[i])
            if cost then self.baseCost[spells[i]] = math.max(self.baseCost[spells[i]] or 0, cost) end
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

function CDMGlow:ScanCDMButtons()
    if InCombatLockdown() then return end
    for auraID, buttons in pairs(self.buttonsByAura) do
        if self.activeAuras[auraID] then for i = 1, #buttons do HideGlow(buttons[i]) end end
    end
    table.wipe(self.buttonsByAura)
    local knownNames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "CooldownViewer", "BlizzardCooldownFrame" }
    local allButtons, seen = {}, {}
    for _, name in ipairs(knownNames) do if _G[name] then ScanFrameTree(_G[name], allButtons, seen, 0) end end
    for auraID in pairs(self.spellsByAura) do self.buttonsByAura[auraID] = {} end
    for i = 1, #allButtons do
        local entry = allButtons[i]
        for auraID, spells in pairs(self.spellsByAura) do
            for j = 1, #spells do if spells[j] == entry.spellID then table.insert(self.buttonsByAura[auraID], entry.button) end end
        end
    end
    for auraID, buttons in pairs(self.buttonsByAura) do
        if self.activeAuras[auraID] then for i = 1, #buttons do ShowGlow(buttons[i]) end end
    end
end

function CDMGlow:UpdateGlows()
    if not CXUI_DB.cdmGlow or not DB.enabled then
        for auraID in pairs(self.activeAuras) do
            local btns = self.buttonsByAura[auraID]
            if btns then for i = 1, #btns do HideGlow(btns[i]) end end
        end
        return
    end
    for auraID in pairs(self.spellsByAura) do
        local hasAura = false
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
            hasAura = (ok and aura ~= nil)
        end
        hasAura = hasAura or self.overlayProcSpells[auraID] or self:HasProcViaCost(auraID)
        if self.activeAuras[auraID] ~= hasAura then
            self.activeAuras[auraID] = hasAura
            local btns = self.buttonsByAura[auraID]
            if btns then for _, b in ipairs(btns) do if hasAura then ShowGlow(b) else HideGlow(b) end end end
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
        C_Timer.After(1.5, function() CDMGlow:ScanCDMButtons(); CDMGlow:UpdateBaselineCosts(); CDMGlow:UpdateGlows() end)
    elseif event == "UNIT_AURA" and (...) == "player" then CDMGlow:UpdateGlows()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local sid = ...
        if CDMGlow.spellsByAura[sid] then CDMGlow.overlayProcSpells[sid] = true; CDMGlow:UpdateGlows() end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        if CDMGlow.overlayProcSpells[sid] then CDMGlow.overlayProcSpells[sid] = nil; CDMGlow:UpdateGlows() end
    end
end)

SLASH_CDMGLOW1 = "/cdmglow"
SlashCmdList["CDMGLOW"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "rescan" then CDMGlow:ScanCDMButtons(); print("|cff0070ddcxUI:|r Rescanning...")
    elseif cmd == "on" then DB.enabled = true; CDMGlow:UpdateGlows(); print("|cff0070ddcxUI:|r Enabled")
    elseif cmd == "off" then DB.enabled = false; CDMGlow:UpdateGlows(); print("|cff0070ddcxUI:|r Disabled")
    else print("|cff0070ddcxUI CDM Glow:|r /cdmglow [on|off|rescan]") end
end