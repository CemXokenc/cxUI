local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MODULE: DUNGEON DISPELLABLE DEBUFF ALERT
--
-- Plays a sound (and prints a text alert) the moment any party member gets
-- hit by a debuff that YOUR current spec can dispel.
--
-- This is a 1:1 port of the actual detection logic Decursive itself uses
-- (see Decursive.lua: the UnitDebuff() polyfill around line 409, and the
-- Type-resolution block around line 560-590):
--
--   1) Enumerate debuffs via C_UnitAuras.GetDebuffDataByIndex(unit, i,
--      "RAID_PLAYER_DISPELLABLE") -- Decursive's own polyfill for
--      UnitDebuff() on the modern client.
--   2) Read dispelName off the result and test canaccessvalue() on it.
--      When it's actually readable (not secret), match it exactly against
--      the dispel types known from the player's own spellbook.
--   3) When it IS secret, fall back to the same ColorCurve trick Decursive
--      uses (D.Status.dsCurve): a curve mapping "types I can cure" to one
--      color and everything else to another, evaluated by the engine via
--      C_UnitAuras.GetAuraDispelTypeColor so the secret comparison never
--      touches our tainted code. Only the color TABLE's nil/non-nil is
--      tested (never a field of it), matching Decursive's `elseif s_color
--      then` check. This tier can't distinguish exact type, same tradeoff
--      Decursive itself accepts in this situation.
-- ---------------------------------------------------------------------------

local DISPEL_ALERT_SOUND_FILE = "Interface\\AddOns\\cxUI\\media\\AfflictionAlert.ogg"

-- Debug mode: /cxdispel debug  (toggles verbose chat prints)
--             /cxdispel status (prints current gating state)
CXUI_DispelAlertDebug = CXUI_DispelAlertDebug or false

local function Debug(...)
    if CXUI_DispelAlertDebug then
        print("|cff33ccff[cxUI DispelAlert]|r", ...)
    end
end

local function IsEnabled()
    return CXUI_DB and CXUI_DB.mythicPlusDispelAlert
end

local function PlayDispelAlertSound(unit)
    local unitName = (UnitName and UnitName(unit)) or unit
    print(("|cffff8000[cxUI]|r Dispellable debuff on %s!"):format(unitName))

    if not IsEnabled() then
        Debug("Alert suppressed: mythicPlusDispelAlert is off in CXUI_DB")
        return
    end

    local willPlay, handle = PlaySoundFile(DISPEL_ALERT_SOUND_FILE, "Master")
    Debug("PlaySoundFile ->", willPlay, handle, "path:", DISPEL_ALERT_SOUND_FILE)
end

-- ---------------------------------------------------------------------------
-- What I can cure -- based on MY OWN known spells (never secret data).
-- Same list style Decursive builds its "CuringSpells" table from.
-- ---------------------------------------------------------------------------
local DISPEL_SPELLS = {
    [88423]  = { Magic = true },                  -- Nature's Cure (Druid, Restoration)
    [360823] = { Magic = true },                  -- Naturalize (Evoker, Preservation)
    [218164] = { Magic = true },                  -- Detox (Monk, Mistweaver)
    [4987]   = { Magic = true },                  -- Cleanse (Paladin, Holy)
    [213644] = { Poison = true, Disease = true }, -- Cleanse Toxins (Paladin, Protection/Retribution)
    [527]    = { Magic = true },                  -- Purify (Priest, Discipline/Holy)
    [213634] = { Disease = true },                -- Purify Disease (Priest, Shadow)
    [77130]  = { Magic = true },                  -- Purify Spirit (Shaman, Restoration)
    [51886]  = { Curse = true },                  -- Cleanse Spirit (Shaman, Elemental/Enhancement)
    [475]    = { Curse = true },                  -- Remove Curse (Mage)
    [89808]  = { Magic = true },                  -- Singe Magic (Warlock, via Imp)
}

local DISPEL_TALENT_ADDITIONS = {
    [392378] = { baseSpell = 88423,  add = { Curse = true, Poison = true } },   -- Improved Nature's Cure
    [388874] = { baseSpell = 218164, add = { Poison = true, Disease = true } }, -- Improved Detox
    [383016] = { baseSpell = 77130,  add = { Curse = true } },                  -- Improved Purify Spirit
}

-- Safety net: these classes have zero single-target dispel, period.
local CLASSES_WITH_NO_DISPEL = {
    DEATHKNIGHT = true,
    DEMONHUNTER = true,
    HUNTER      = true,
    ROGUE       = true,
    WARRIOR     = true,
}

-- Blizzard's own numeric dispel-type IDs (matches Decursive's DC.DTtoBT map).
local BLIZZARD_DISPEL_TYPE = {
    None    = 0,
    Magic   = 1,
    Curse   = 2,
    Disease = 3,
    Poison  = 4,
}

local MATCH_COLOR    = CreateColor(1, 1, 1, 1)
local NO_MATCH_COLOR = CreateColor(0, 0, 0, 0)

local myDispelTypes = {}

-- Same curve trick as Decursive's D.Status.dsCurve.
local dispelCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve()
if dispelCurve then
    dispelCurve:SetType(Enum.LuaCurveType.Step)
end

local function RebuildCurve()
    if not dispelCurve then return end
    dispelCurve:ClearPoints()
    for typeName, blizzardValue in pairs(BLIZZARD_DISPEL_TYPE) do
        if typeName == "None" then
            dispelCurve:AddPoint(blizzardValue, NO_MATCH_COLOR)
        else
            dispelCurve:AddPoint(blizzardValue, myDispelTypes[typeName] and MATCH_COLOR or NO_MATCH_COLOR)
        end
    end
end

local function RecomputeDispelTypes()
    wipe(myDispelTypes)

    local _, classToken = UnitClass("player")
    if CLASSES_WITH_NO_DISPEL[classToken] then
        Debug("Recompute: class", classToken, "has no single-target dispel, skipping")
        RebuildCurve()
        return
    end

    for spellID, types in pairs(DISPEL_SPELLS) do
        if IsPlayerSpell(spellID) then
            for dispelType in pairs(types) do
                myDispelTypes[dispelType] = true
            end
        end
    end

    for talentSpellID, info in pairs(DISPEL_TALENT_ADDITIONS) do
        if IsPlayerSpell(info.baseSpell) and IsPlayerSpell(talentSpellID) then
            for dispelType in pairs(info.add) do
                myDispelTypes[dispelType] = true
            end
        end
    end

    RebuildCurve()

    local summary = {}
    for dispelType in pairs(myDispelTypes) do
        summary[#summary + 1] = dispelType
    end
    Debug("Recompute: class", classToken, "level", UnitLevel("player"), "-> can cure:",
        (#summary > 0) and table.concat(summary, ", ") or "NOTHING (no known dispel spell yet)")
end

-- ---------------------------------------------------------------------------
-- Where this is allowed to run: dungeons (any difficulty, incl. Mythic+),
-- Delves, scenarios, and open world. NOT raids, and NOT PvP (arenas/BGs).
-- ---------------------------------------------------------------------------
local ALLOWED_INSTANCE_TYPES = {
    party    = true,
    scenario = true,
    none     = true,
}

local function IsInMythicPlus()
    local _, instanceType = IsInInstance()
    return ALLOWED_INSTANCE_TYPES[instanceType] or false
end

-- ---------------------------------------------------------------------------
-- Decursive's own UnitDebuff() polyfill for the modern client, copied 1:1.
-- ---------------------------------------------------------------------------
local DISPEL_FILTER = "RAID_PLAYER_DISPELLABLE"

local function GetUnitDebuff(unitToken, i)
    local auraData = C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex(unitToken, i, DISPEL_FILTER)
    if not auraData then
        return nil
    end
    return auraData.name, auraData.dispelName, auraData.spellId, auraData.auraInstanceID
end

-- ---------------------------------------------------------------------------
-- Aura tracking -- alert once per NEW application, not on every refresh tick.
-- ---------------------------------------------------------------------------
local alertedInstance = {} -- [unit] = auraInstanceID we already alerted for

local function CheckUnitForDispellableDebuff(unit)
    if not IsEnabled() then return end
    if not IsInMythicPlus() then return end
    if not next(myDispelTypes) then return end -- nothing this spec can dispel
    if not C_UnitAuras then return end

    local matchedInstanceID = nil

    for i = 1, 40 do
        local name, typeName, spellID, auraInstanceID = GetUnitDebuff(unit, i)
        if not name then break end

        -- canaccessvalue() is Decursive's own way to check readability
        -- without touching the value in a restricted way.
        local secretMode = canaccessvalue and (not canaccessvalue(typeName))

        if not secretMode then
            if typeName and typeName ~= "" and myDispelTypes[typeName] then
                Debug("Precise match on", unit, "type:", typeName)
                matchedInstanceID = auraInstanceID
                break
            end

        elseif dispelCurve and auraInstanceID then
            -- Decursive: `local s_color = ... GetAuraDispelTypeColor(...)`
            -- then `elseif s_color then` -- truthy test only, no field read.
            local s_color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, dispelCurve)
            if s_color then
                Debug("Curve fallback match on", unit, "-- type was secret")
                matchedInstanceID = auraInstanceID
                break
            end
        end
    end

    if matchedInstanceID then
        if alertedInstance[unit] ~= matchedInstanceID then
            alertedInstance[unit] = matchedInstanceID
            Debug("Match on", unit, "auraInstanceID", matchedInstanceID, "-> alerting")
            PlayDispelAlertSound(unit)
        end
    else
        alertedInstance[unit] = nil
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" then
        if unit and (unit == "player" or unit:match("^party%d$") or unit:match("^raid%d+$")) then
            CheckUnitForDispellableDebuff(unit)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        RecomputeDispelTypes()
        wipe(alertedInstance)

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED" then
        RecomputeDispelTypes()

    elseif event == "GROUP_ROSTER_UPDATE" then
        wipe(alertedInstance)
    end
end)

RecomputeDispelTypes()

-- ---------------------------------------------------------------------------
-- Slash command: /cxdispel debug  -- toggle verbose debug prints
--                 /cxdispel status -- print current gating state
-- ---------------------------------------------------------------------------
SLASH_CXDISPEL1 = "/cxdispel"
SlashCmdList["CXDISPEL"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "debug" then
        CXUI_DispelAlertDebug = not CXUI_DispelAlertDebug
        print("|cff33ccff[cxUI DispelAlert]|r debug", CXUI_DispelAlertDebug and "ON" or "OFF")

    elseif msg == "status" then
        local _, classToken = UnitClass("player")
        local summary = {}
        for dispelType in pairs(myDispelTypes) do
            summary[#summary + 1] = dispelType
        end
        print("|cff33ccff[cxUI DispelAlert]|r class:", classToken, "level:", UnitLevel("player"),
            "enabled:", IsEnabled() and "yes" or "no",
            "in allowed zone:", IsInMythicPlus() and "yes" or "no")
        print("|cff33ccff[cxUI DispelAlert]|r can currently cure:",
            (#summary > 0) and table.concat(summary, ", ") or "NOTHING (no known dispel spell yet)")

    else
        print("|cff33ccff[cxUI DispelAlert]|r usage: /cxdispel debug | /cxdispel status")
    end
end