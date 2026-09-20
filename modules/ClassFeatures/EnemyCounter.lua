local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: ENEMY COUNTER (all classes)
-- Shows the number of nearby enemies fighting you while in combat.
-- Edit the constants to adjust position and appearance.
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key  = "cdmEnemyCounter",
    name = "Enemy Counter",
    desc = "Shows nearby enemy count in the center of the screen. Works for all classes.",
}

local COUNTER_X, COUNTER_Y  = -120, -100
local COUNTER_FONT_SIZE     = 20

local counterText
local npActive = {}
local counterLastCount = -1
local counterTicker

local function IsValidEnemy(unit)
    return UnitExists(unit) and not UnitIsDead(unit) and UnitCanAttack("player", unit)
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

local function UpdateCounter()
    if not UnitAffectingCombat("player") then
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

local function StartTicker()
    if counterTicker then return end
    counterTicker = F:NewTicker(1.0, UpdateCounter)
end

local function StopTicker()
    if counterTicker then counterTicker:Cancel(); counterTicker = nil end
    counterText:Hide()
    counterLastCount = -1
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        StartTicker()
        UpdateCounter()
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopTicker()
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
        StopTicker()
    end
end

function F:OnEnable()
    if not counterText then
        counterText = UIParent:CreateFontString(nil, "OVERLAY")
        counterText:SetFont("Fonts\\FRIZQT__.TTF", COUNTER_FONT_SIZE, "OUTLINE")
        counterText:SetTextColor(1, 1, 1, 1)
        counterText:SetPoint("CENTER", UIParent, "CENTER", COUNTER_X, COUNTER_Y)
        counterText:SetJustifyH("CENTER")
        counterText:Hide()
    end

    -- Pick up nameplates that already exist (matters when enabled mid-session).
    wipe(npActive)
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = np.namePlateUnitToken
            if unit and not UnitIsFriend("player", unit) then npActive[unit] = true end
        end
    end

    local ev = self:NewEventFrame()
    ev:SetScript("OnEvent", OnEvent)
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    ev:RegisterEvent("UNIT_FLAGS")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")

    if UnitAffectingCombat("player") then
        StartTicker()
        UpdateCounter()
    end
end

function F:OnDisable()
    counterTicker = nil -- cancelled by F:Silence()
    counterLastCount = -1
    wipe(npActive)
    if counterText then counterText:Hide() end
end
