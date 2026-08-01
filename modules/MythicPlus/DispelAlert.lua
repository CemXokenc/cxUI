local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MODULE: DUNGEON DISPELLABLE DEBUFF ALERT
--
-- Plays a sound (and prints a text alert) the moment any party member gets
-- hit by a debuff that YOUR current spec can dispel.
--
-- Uses C_UnitAuras.GetDebuffDataByIndex(unit, i, "RAID_PLAYER_DISPELLABLE"),
-- a filter Blizzard added specifically so addons can ask "which debuffs on
-- this unit can the ACTIVE PLAYER dispel" without ever touching the
-- underlying secret dispel-type data directly (see Decursive's own
-- Decursive.lua, the UnitDebuff() polyfill around line 409, which uses this
-- exact same filter). This is precise (only YOUR dispellable types), simple,
-- and doesn't need any hardcoded spellID list.
--
-- Note (per Decursive's own comment): Blizzard has said this filter is
-- planned to stop working in patch 12.1 ("forbidden in 12.1"). If/when that
-- happens, this module will simply stop alerting (no error) until an
-- update finds whatever replaces it.
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
    -- Text alert always fires alongside the sound, so you have a visible
    -- fallback even if sound is muted/misconfigured/missing.
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
-- Where this is allowed to run: dungeons (any difficulty, incl. Mythic+),
-- Delves, scenarios, and open world. NOT raids, and NOT PvP (arenas/BGs).
-- ---------------------------------------------------------------------------
local ALLOWED_INSTANCE_TYPES = {
    party    = true, -- normal/heroic/mythic dungeons, Mythic+
    scenario = true, -- Delves and other scenarios
    none     = true, -- open world
}

local function IsInMythicPlus()
    local _, instanceType = IsInInstance()
    return ALLOWED_INSTANCE_TYPES[instanceType] or false
end

-- ---------------------------------------------------------------------------
-- Aura tracking -- alert once per NEW application, not on every refresh tick.
-- ---------------------------------------------------------------------------
local alertedInstance = {} -- [unit] = auraInstanceID we already alerted for

local canQuery = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.IsAuraFilteredOutByInstanceID

local function CheckUnitForDispellableDebuff(unit)
    if not IsEnabled() then return end
    if not IsInMythicPlus() then return end

    if not canQuery then
        Debug("Required C_UnitAuras functions missing on this client -- can't check")
        return
    end

    local matchedInstanceID = nil

    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
        if not aura then break end

        -- auraInstanceID is a plain number, never secret -- safe to use.
        local auraInstanceID = aura.auraInstanceID

        -- Per-instance membership check: returns a plain boolean telling us
        -- whether THIS specific aura passes the "player can dispel it"
        -- filter, without ever exposing the aura's actual (secret) type to
        -- us. This is the same pattern real addons like Plater use via
        -- IsAuraFilteredOutByInstanceID(unit, id, "RAID_PLAYER_DISPELLABLE").
        local filteredOut = auraInstanceID and C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "RAID_PLAYER_DISPELLABLE")

        if filteredOut == false then
            matchedInstanceID = auraInstanceID
            break
        end
    end

    if matchedInstanceID then
        if alertedInstance[unit] ~= matchedInstanceID then
            alertedInstance[unit] = matchedInstanceID
            Debug("Match on", unit, "auraInstanceID", matchedInstanceID)
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
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" then
        if unit and (unit == "player" or unit:match("^party%d$") or unit:match("^raid%d+$")) then
            CheckUnitForDispellableDebuff(unit)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(alertedInstance)

    elseif event == "GROUP_ROSTER_UPDATE" then
        wipe(alertedInstance)
    end
end)

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
        print("|cff33ccff[cxUI DispelAlert]|r enabled:", IsEnabled() and "yes" or "no",
            "in allowed zone:", IsInMythicPlus() and "yes" or "no",
            "API available:", canQuery and "yes" or "no")

    else
        print("|cff33ccff[cxUI DispelAlert]|r usage: /cxdispel debug | /cxdispel status")
    end
end