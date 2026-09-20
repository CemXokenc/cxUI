local addonName, ns = ...

-- ===========================================================================
-- COMBAT: NO MOVEMENT (all classes)
-- Shows "No <SPELL> (X.X)" while the class movement ability is on cooldown,
-- and "FREE MOVEMENT" during Time Spiral.
-- ===========================================================================

local M = ns:GetModule("Combat")

local F = M:NewFeature{
    key  = "noMovement",
    name = "No Movement",
    desc = "Shows movement ability cooldown when unavailable. Works for all classes.",
}

local TRACKER_X, TRACKER_Y  = 0, 100
local TRACKER_FONT_SIZE     = 16

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
    WARRIOR     = {100, 6544},               -- heroic leap, charge
}

local NAME_OVERRIDES = {
    [48265]  = "DA",       [195072] = "rush",    [189110] = "leap",
    [252216] = "dash",     [102401] = "charge",  [115008] = "torpedo",
    [190784] = "steed",    [121536] = "feather", [36554]  = "step",
    [195457] = "grapple",  [192063] = "gust",    [48020]  = "circle",
    [6544]   = "leap"
}

local MOVEMENT_SPELL_ID, MOVEMENT_SPELL_NAME

-- Time Spiral (Evoker) grants everyone nearby a free use of their movement
-- ability. The game signals it by glowing the ability's action button.
local FREE_MOVEMENT_DURATION = 10
local freeMovementUntil
local glowProcDebounce = 0

local movementText, freeMovementText

local function IsFreeMovementGlow(spellId)
    if not spellId or not MOVEMENT_SPELL_ID then return false end
    if spellId == MOVEMENT_SPELL_ID then return true end
    if C_Spell.GetOverrideSpell then
        local ok, overrideId = pcall(C_Spell.GetOverrideSpell, MOVEMENT_SPELL_ID)
        if ok and overrideId and overrideId == spellId then return true end
    end
    return false
end

local function CacheMovementSpell()
    MOVEMENT_SPELL_ID, MOVEMENT_SPELL_NAME = nil, nil
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
    if not MOVEMENT_SPELL_ID then
        movementText:Hide()
        freeMovementText:Hide()
        return
    end
    local cdInfo = C_Spell.GetSpellCooldown(MOVEMENT_SPELL_ID)
    if cdInfo and cdInfo.timeUntilEndOfStartRecovery
       and not cdInfo.isOnGCD and cdInfo.isOnGCD ~= nil then
        movementText:SetText(string.format("No %s %.1f", MOVEMENT_SPELL_NAME, cdInfo.timeUntilEndOfStartRecovery))
        movementText:Show()
    else
        movementText:Hide()
    end

    if freeMovementUntil then
        local remaining = freeMovementUntil - GetTime()
        if remaining > 0 then
            freeMovementText:SetText(string.format("FREE MOVEMENT %.1f", remaining))
            freeMovementText:Show()
        else
            freeMovementUntil = nil
            freeMovementText:Hide()
        end
    else
        freeMovementText:Hide()
    end
end

local function CreateTexts()
    if movementText then return end
    movementText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    movementText:SetFont((movementText:GetFont()), TRACKER_FONT_SIZE, "OUTLINE")
    movementText:SetTextColor(1, 1, 1, 1)
    movementText:SetShadowColor(0, 0, 0, 0)
    movementText:SetPoint("CENTER", UIParent, "CENTER", TRACKER_X, TRACKER_Y)
    movementText:SetJustifyH("CENTER")
    movementText:Hide()

    freeMovementText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    freeMovementText:SetFont((freeMovementText:GetFont()), TRACKER_FONT_SIZE, "OUTLINE")
    freeMovementText:SetTextColor(1, 0.82, 0, 1) -- gold, to stand out from the "No X" line
    freeMovementText:SetShadowColor(0, 0, 0, 0)
    freeMovementText:SetPoint("BOTTOM", movementText, "TOP", 0, 4)
    freeMovementText:SetJustifyH("CENTER")
    freeMovementText:Hide()
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        CacheMovementSpell()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellId = ...
        if IsFreeMovementGlow(spellId) then
            local now = GetTime()
            if (now - glowProcDebounce) >= 0.12 then
                glowProcDebounce = now
                freeMovementUntil = now + FREE_MOVEMENT_DURATION
                UpdateMovementAlert()
            end
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellId = ...
        if IsFreeMovementGlow(spellId) then
            freeMovementUntil = nil
            UpdateMovementAlert()
        end
    else -- spec / talent change
        F:After(0.5, CacheMovementSpell)
    end
end

function F:OnEnable()
    CreateTexts()
    CacheMovementSpell()

    local ev = self:NewEventFrame()
    ev:SetScript("OnEvent", OnEvent)
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_TALENT_UPDATE")
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

    self:NewTicker(0.1, UpdateMovementAlert)
end

function F:OnDisable()
    freeMovementUntil = nil
    if movementText then movementText:Hide() end
    if freeMovementText then freeMovementText:Hide() end
end
