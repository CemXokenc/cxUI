local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: SHARED UTILITIES
-- Loaded first. Exports helpers to ns.CF for DeathKnight.lua and Mage.lua.
-- ===========================================================================

local _, _, CLASS_ID = UnitClass("player")

ns.CF = { CLASS_ID = CLASS_ID }
local CF = ns.CF

-- ===========================================================================
-- NO MOVEMENT TRACKER (all classes)
-- Shows "NO <SPELL> (X.Xs)" when the class movement ability is on cooldown.
-- ===========================================================================

local TRACKER_X         =  0
local TRACKER_Y         =  100
local TRACKER_FONT_SIZE =  16
local TRACKER_R, TRACKER_G, TRACKER_B = 1, 1, 1

local MOVEMENT_ABILITIES = {
    DEATHKNIGHT = {48265},                   -- death's advance
    DEMONHUNTER = {195072, 189110, 1234796}, -- fel rush, infernal strike, shift
    DRUID       = {252216, 102401},          -- tiger dash, wild charge
    EVOKER      = {358267},                  -- hover
    HUNTER      = {781},                     -- disengage
    MAGE        = {212653, 1953},            -- shimmer, blink
    MONK        = {109132, 115008},          -- roll, chi torpedo
    PALADIN     = {190784},                  -- divine steed
    PRIEST      = {121536},                  -- angelic feather
    ROGUE       = {36554, 195457},           -- shadowstep, grappling hook
    SHAMAN      = {192063},                  -- gust of wind
    WARLOCK     = {48020},                   -- demonic circle teleport
    WARRIOR     = {6544},                    -- heroic leap
}

local NAME_OVERRIDES = {
    [48265]  = "DA",       [195072] = "rush",    [189110] = "leap",
    [252216] = "dash",     [102401] = "charge",  [115008] = "torpedo",
    [190784] = "steed",    [121536] = "feather", [36554]  = "step",
    [195457] = "grapple",  [192063] = "gust",    [48020]  = "circle",
    [6544]   = "leap",
}

local MOVEMENT_SPELL_ID   = nil
local MOVEMENT_SPELL_NAME = nil

local movementText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
do
    local fontName = movementText:GetFont()
    movementText:SetFont(fontName, TRACKER_FONT_SIZE, "OUTLINE")
end
movementText:SetTextColor(TRACKER_R, TRACKER_G, TRACKER_B, 1)
movementText:SetShadowColor(0, 0, 0, 0)
movementText:SetPoint("CENTER", UIParent, "CENTER", TRACKER_X, TRACKER_Y)
movementText:SetJustifyH("CENTER")
movementText:Hide()

local function CacheMovementSpell()
    MOVEMENT_SPELL_ID   = nil
    MOVEMENT_SPELL_NAME = nil
    local _, playerClass = UnitClass("player")
    local abilities = MOVEMENT_ABILITIES[playerClass]
    if not abilities then return end
    for _, spellID in ipairs(abilities) do
        if C_SpellBook.IsSpellKnown(spellID) then
            MOVEMENT_SPELL_ID = spellID
            MOVEMENT_SPELL_NAME = NAME_OVERRIDES[spellID]
                or (function()
                    local info = C_Spell.GetSpellInfo(spellID)
                    return info and string.lower(info.name) or "movement"
                end)()
            return
        end
    end
end

local function UpdateMovementAlert()
    if not CXUI_DB or not CXUI_DB.noMovement or not MOVEMENT_SPELL_ID then
        movementText:Hide()
        return
    end
    local cdInfo = C_Spell.GetSpellCooldown(MOVEMENT_SPELL_ID)
    if cdInfo and cdInfo.timeUntilEndOfStartRecovery
       and not cdInfo.isOnGCD and cdInfo.isOnGCD ~= nil then
        movementText:SetText(string.format(
            "No %s %.1f", MOVEMENT_SPELL_NAME, cdInfo.timeUntilEndOfStartRecovery))
        movementText:Show()
    else
        movementText:Hide()
    end
end

local movementFrame = CreateFrame("Frame", "CXUI_MovementTrackerFrame", UIParent)
local movementTimer = 0
movementFrame:SetScript("OnUpdate", function(self, elapsed)
    movementTimer = movementTimer + elapsed
    if movementTimer >= 0.1 then
        UpdateMovementAlert()
        movementTimer = 0
    end
end)
movementFrame:RegisterEvent("PLAYER_LOGIN")
movementFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
movementFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
movementFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
movementFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CacheMovementSpell()
    else
        C_Timer.After(0.5, CacheMovementSpell)
    end
end)

-- ===========================================================================
-- ENEMY COUNTER (all classes)
-- Shows nearby enemy count at a fixed screen position while in combat.
-- Edit constants below to adjust position and appearance.
-- ===========================================================================

local COUNTER_X         =  -120
local COUNTER_Y         =  -150
local COUNTER_FONT_SIZE =  20
local COUNTER_R, COUNTER_G, COUNTER_B = 1, 1, 1

local counterText = UIParent:CreateFontString(nil, "OVERLAY")
do
    counterText:SetFont("Fonts\\FRIZQT__.TTF", COUNTER_FONT_SIZE, "OUTLINE")
end
counterText:SetTextColor(COUNTER_R, COUNTER_G, COUNTER_B, 1)
counterText:SetPoint("CENTER", UIParent, "CENTER", COUNTER_X, COUNTER_Y)
counterText:SetJustifyH("CENTER")
counterText:Hide()

local npActive = {}

local function IsValidEnemy(unit)
    return UnitExists(unit)
        and not UnitIsDead(unit)
        and UnitCanAttack("player", unit)
end

local function GetEnemyCount()
    local count = 0
    local targetCounted = false
    local hasTarget = UnitExists("target")
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            if UnitAffectingCombat(unit) or UnitThreatSituation("player", unit) ~= nil then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            end
        end
    end
    if not targetCounted and hasTarget and IsValidEnemy("target") then
        if UnitAffectingCombat("target") or UnitThreatSituation("player", "target") ~= nil then
            count = count + 1
        end
    end
    return count
end

local counterLastCount = -1
local counterTicker    = nil

local function UpdateCounter()
    if not CXUI_DB or not CXUI_DB.cdmEnemyCounter
       or not UnitAffectingCombat("player") then
        counterText:Hide()
        counterLastCount = -1
        return
    end
    local count = GetEnemyCount()
    if count == counterLastCount then return end
    counterLastCount = count
    if count > 0 then
        counterText:SetText(tostring(count))
        counterText:Show()
    else
        counterText:Hide()
    end
end

local function StartCounterTicker()
    if counterTicker then return end
    counterTicker = C_Timer.NewTicker(1.0, UpdateCounter)
end

local function StopCounterTicker()
    if counterTicker then counterTicker:Cancel(); counterTicker = nil end
    counterText:Hide()
    counterLastCount = -1
end

local counterFrame = CreateFrame("Frame", "CXUI_EnemyCounterFrame", UIParent)
counterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
counterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
counterFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
counterFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
counterFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
counterFrame:RegisterEvent("UNIT_FLAGS")
counterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
counterFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        StartCounterTicker()
        UpdateCounter()
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopCounterTicker()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") then UpdateCounter() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not UnitIsFriend("player", unit) then
            npActive[unit] = true
            if UnitAffectingCombat("player") then UpdateCounter() end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        npActive[unit] = nil
        if UnitAffectingCombat("player") then UpdateCounter() end
    elseif event == "UNIT_FLAGS" then
        if npActive[unit] and UnitIsFriend("player", unit) then
            npActive[unit] = nil
            if UnitAffectingCombat("player") then UpdateCounter() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(npActive)
        StopCounterTicker()
    end
end)

-- ===========================================================================
-- EARLY RETURN FOR NON-DK/MAGE
-- Everything below only runs for Death Knight (6) and Mage (8).
-- ===========================================================================

if CLASS_ID ~= 6 and CLASS_ID ~= 8 then return end

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
CF.LCG = LCG

-- ===========================================================================
-- EnumerateFrames scan
-- ===========================================================================

local function ScanFramesByTexture(texStrings, callback)
    local frame = EnumerateFrames()
    while frame do
        if frame.Icon and type(frame.Icon) == "table" and frame.Icon.GetTexture then
            local ok, matched = pcall(function()
                local tex = frame.Icon:GetTexture()
                if tex then
                    local texStr = tostring(tex)
                    for _, t in ipairs(texStrings) do
                        if texStr == t then return true end
                    end
                end
                return false
            end)
            if ok and matched then callback(frame) end
        end
        frame = EnumerateFrames(frame)
    end
end

-- ===========================================================================
-- Overlay helpers
-- ===========================================================================

local function CreateOverlay(cdmFrame)
    local ov = CreateFrame("Frame", nil, cdmFrame)    
    ov:SetAllPoints(cdmFrame)
    ov:SetFrameLevel(cdmFrame:GetFrameLevel() + 2)
    ov._targetFrame = cdmFrame
    ov._glowActive  = false
    ov:Hide()
    return ov
end

local GLOW_COLOR = { 0.85, 0.85, 0.95, 0.9 }

local function StartGlow(overlay)
    if overlay._glowActive then return end
    overlay._glowActive = true
    overlay:Show()
    if LCG and LCG.ProcGlow_Start then
        LCG.ProcGlow_Start(overlay, { color = GLOW_COLOR, startAnim = false })
    end
end

local function StopGlow(overlay)
    if not overlay._glowActive then return end
    overlay._glowActive = false
    if LCG and LCG.ProcGlow_Stop then LCG.ProcGlow_Stop(overlay) end
    overlay:Hide()
end

local X_THICK = 5

local function AttachXCross(overlay)
    if overlay._xl1 then return end
    local l1 = overlay:CreateTexture(nil, "OVERLAY")
    l1:SetColorTexture(1, 0, 0, 0.9)
    l1:SetPoint("CENTER", overlay, "CENTER")
    overlay._xl1 = l1
    local l2 = overlay:CreateTexture(nil, "OVERLAY")
    l2:SetColorTexture(1, 0, 0, 0.9)
    l2:SetPoint("CENTER", overlay, "CENTER")
    overlay._xl2 = l2
    local function ApplySize()
        local w, h = overlay:GetSize()
        if not w or w < 4 then return end
        local diag  = math.sqrt(w * w + h * h)
        local angle = math.atan(h / w)
        l1:SetSize(diag, X_THICK); l1:SetRotation( angle)
        l2:SetSize(diag, X_THICK); l2:SetRotation(-angle)
    end
    overlay:SetScript("OnSizeChanged", function() ApplySize() end)
    ApplySize()
end

local function ShowXCross(overlay)
    AttachXCross(overlay)
    if overlay._xl1 then overlay._xl1:Show(); overlay._xl2:Show() end
    overlay:Show()
end

local function HideXCross(overlay)
    if overlay._xl1 then overlay._xl1:Hide(); overlay._xl2:Hide() end
    overlay:Hide()
end

-- ===========================================================================
-- Export
-- ===========================================================================

CF.ScanFramesByTexture = ScanFramesByTexture
CF.CreateOverlay       = CreateOverlay
CF.StartGlow           = StartGlow
CF.StopGlow            = StopGlow
CF.AttachXCross        = AttachXCross
CF.ShowXCross          = ShowXCross
CF.HideXCross          = HideXCross