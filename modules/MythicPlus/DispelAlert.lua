local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MODULE: DUNGEON DISPELLABLE DEBUFF ALERT
--
-- Plays a sound (and, where possible, prints a text alert) the moment any
-- party member gets hit by a debuff that YOUR current spec can dispel.
--
-- HISTORY / WHY THIS FILE HAS TWO MECHANISMS
-- --------------------------------------------------------------------------
-- v1 of this module was a 1:1 port of Decursive's own detection logic
-- (Decursive.lua: the UnitDebuff() polyfill ~line 409, and the Type-
-- resolution block ~line 560-600):
--
--   1) Enumerate debuffs via C_UnitAuras.GetDebuffDataByIndex(unit, i,
--      "RAID_PLAYER_DISPELLABLE").
--   2) Read dispelName off the result and test canaccessvalue() on it.
--      When readable, match it exactly against the dispel types known
--      from the player's own spellbook.
--   3) When it's secret, fall back to the ColorCurve trick (D.Status.dsCurve
--      in Decursive): a curve mapping "types I can cure" to one color and
--      everything else to another, evaluated engine-side via
--      C_UnitAuras.GetAuraDispelTypeColor so the secret comparison never
--      touches our tainted code. Only the color TABLE's nil/non-nil is
--      tested, matching Decursive's `elseif s_color then` check. This tier
--      can't distinguish exact type -- same tradeoff Decursive accepts.
--
-- Checked against Decursive 2.9.0-RC1 (2026): this exact tier is STILL
-- there, unchanged. But Decursive's own comment in Decursive.lua now reads:
--
--     -- debuffs are unusable in midnight so always return false
--     if DC.MN then return false end
--
-- i.e. as of the "Midnight" client (toc >= 120000) their own live debuff
-- scan is a no-op -- they no longer rely on it for real detection. Instead
-- they ship a NEW file, Dcr_12_1_Sounds.lua, that sidesteps the secret-data
-- problem entirely:
--
--   Pre-register (unit, spellID, soundFile) triples with the officially
--   blessed C_UnitAuras.AddAuraSound(trigger, sound) API (added in patch
--   12.1.0, predicate AllowedWhenUntainted). Detection AND playback then
--   happen inside Blizzard's own client -- our Lua never reads the
--   protected aura, so there's nothing to taint and nothing that can be
--   made secret out from under us. It even keeps working mid-combat, since
--   only the *registration* step is blocked while InCombatLockdown().
--
--   The tradeoff: AddAuraSound needs an exact public spellID, not a dispel
--   TYPE, so Decursive now ships a hardcoded per-season list of dungeon/
--   raid debuff spellIDs (borrowed from the GPLv3 "DispelDB", Zhaohu's
--   Decursive fork) and only registers the ones matching a type the player
--   can actually cure.
--
--   The other tradeoff: Blizzard gives no Lua-side callback when the sound
--   actually fires (that would leak the same secret info the API exists to
--   protect), so this path is silent to *us* -- we can't chat-print "X got
--   hit" for a match caught this way. Only the sound plays.
--
-- So this file now runs BOTH mechanisms side by side:
--   * Tier B (new, 12.1+ only): C_UnitAuras.AddAuraSound registrations --
--     the reliable, combat-safe, Blizzard-native sound trigger.
--   * Tier A (original, always available): the UNIT_AURA + curve-trick
--     scan -- kept only for the chat print / heads-up text, and as the
--     FULL fallback (sound included) on clients where AddAuraSound doesn't
--     exist yet.
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

-- withSound=false is used by the Tier A path once Tier B is handling actual
-- playback for this client, so we don't double up sounds for exact matches.
local function AnnounceDispellableDebuff(unit, withSound)
    local unitName = (UnitName and UnitName(unit)) or unit
    print(("|cffff8000[cxUI]|r Dispellable debuff on %s!"):format(unitName))

    if not IsEnabled() then
        Debug("Alert suppressed: mythicPlusDispelAlert is off in CXUI_DB")
        return
    end

    if withSound == false then
        Debug("Text-only announce (Tier B owns the sound on this client)")
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
    -- Healer-spec dispels (full Magic dispel, most also gain more via a talent)
    [88423]  = { Magic = true },                  -- Nature's Cure (Druid, Restoration)
    [360823] = { Magic = true },                  -- Naturalize (Evoker, Preservation)
    [115450] = { Magic = true },                  -- Detox (Monk, Mistweaver)
    [4987]   = { Magic = true },                  -- Cleanse (Paladin, Holy)
    [527]    = { Magic = true },                  -- Purify (Priest, Discipline/Holy)
    [77130]  = { Magic = true },                  -- Purify Spirit (Shaman, Restoration)

    -- Non-healer-spec dispels (partial types, no Magic)
    [2782]   = { Curse = true, Poison = true },   -- Remove Corruption (Druid, Balance/Feral/Guardian)
    [218164] = { Poison = true, Disease = true }, -- Detox (Monk, Brewmaster/Windwalker)
    [374251] = { Curse = true, Poison = true, Disease = true }, -- Cauterizing Flame (Evoker, Devastation/Augmentation)
    [365585] = { Poison = true },                 -- Expunge (Evoker, Devastation/Augmentation)
    [213644] = { Poison = true, Disease = true }, -- Cleanse Toxins (Paladin, Protection/Retribution)
    [213634] = { Disease = true },                -- Purify Disease (Priest, Shadow)
    [51886]  = { Curse = true },                  -- Cleanse Spirit (Shaman, Elemental/Enhancement)
    [475]    = { Curse = true },                  -- Remove Curse (Mage, any spec)
    [89808]  = { Magic = true },                  -- Singe Magic (Warlock, via Imp)
}

local DISPEL_TALENT_ADDITIONS = {
    [392378] = { baseSpell = 88423,  add = { Curse = true, Poison = true } },   -- Improved Nature's Cure
    [388874] = { baseSpell = 115450, add = { Poison = true, Disease = true } }, -- Improved Detox (Mistweaver)
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

-- ---------------------------------------------------------------------------
-- Tier B data: exact spellIDs per dispel type for the current dungeon/raid
-- season, so AddAuraSound (which needs a real spellID, not a type) knows
-- what to listen for. Sourced from Decursive 2.9.0-RC1's Dcr_12_1_Sounds.lua
-- (GPLv3 "DispelDB", Zhaohu's Decursive fork, Copyright (C) 2026 Randy
-- Lorfing). This list is season-specific and WILL need refreshing whenever
-- the M+/raid rotation changes -- re-pull it from an updated Decursive
-- whenever this stops catching things.
-- ---------------------------------------------------------------------------
local SPELLS_BY_TYPE = {
    Magic = {
        1294569, 1217633, 1228198, 1201554, 1235549, 1239860, 1259365,
        1238084, 1249238, 276031, 1294815, 372682, 373589, 1305234,
        381515, 392641, 392924, 268008, 268013, 1296052, 1286922,
        270920, 270499,
    },
    Poison = {
        1294845, 1305368, 1307571, 474515, 1216590, 1234846, 1250937,
        1226031, 1289258, 1263971, 267273, 271564, 1298104, 1306763,
        263957, 272699, 273563, 1308100, 1308148, 267027, 1303486,
        1308546, 1301800, 1306906,
    },
    Disease = {
        1296069, 1302867, 1245456, 267763, 269686,
    },
    Curse = {
        1309980, 1310017, 1238255, 1217973, 1238801, 1252095, 269972,
        270492,
    },
}

local MATCH_COLOR    = CreateColor(1, 1, 1, 1)
local NO_MATCH_COLOR = CreateColor(0, 0, 0, 0)

local myDispelTypes = {}

-- ---------------------------------------------------------------------------
-- Tier A: curve trick, same as Decursive's D.Status.dsCurve. Only used to
-- drive the chat print (and, on clients without AddAuraSound, the sound).
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Tier B: AddAuraSound registration management.
-- ---------------------------------------------------------------------------
local HAS_AURA_SOUND_API = C_UnitAuras and type(C_UnitAuras.AddAuraSound) == "function"

local auraSoundHandles = {}      -- [key] = auraSoundID
local auraSoundRefreshPending = false
local auraSoundRefreshScheduled = false

local function AuraSoundRegistrationBlocked()
    return InCombatLockdown and InCombatLockdown()
end

local function GetUnitTokensForAuraSound()
    local units = { "player" }

    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            units[#units + 1] = "raid" .. i
        end
    else
        -- Pre-arm stable party tokens even while solo, same reasoning as
        -- Decursive: a dungeon can turn on aura restrictions before a
        -- later roster update is allowed to add registrations.
        for i = 1, 4 do
            units[#units + 1] = "party" .. i
        end
    end

    return units
end

local function BuildDesiredAuraSoundRegistrations()
    local desired = {}

    -- Only register while this alert is actually allowed to fire: enabled,
    -- and in a dungeon/scenario/open-world zone (not raid, not PvP) --
    -- same restriction the original module enforced.
    if not IsEnabled() or not IsInMythicPlus() or not next(myDispelTypes) then
        return desired
    end

    for _, unit in ipairs(GetUnitTokensForAuraSound()) do
        for debuffType, spellIDs in pairs(SPELLS_BY_TYPE) do
            if myDispelTypes[debuffType] then
                for _, spellID in ipairs(spellIDs) do
                    local key = unit .. ":" .. spellID
                    desired[key] = {
                        unitToken      = unit,
                        spellID        = spellID,
                        soundFileName  = DISPEL_ALERT_SOUND_FILE,
                        outputChannel  = "Master",
                    }
                end
            end
        end
    end

    return desired
end

local function RefreshAuraSoundRegistrations()
    if not HAS_AURA_SOUND_API then return end

    if AuraSoundRegistrationBlocked() then
        auraSoundRefreshPending = true
        Debug("Refresh deferred: in combat")
        return
    end

    auraSoundRefreshPending = false
    local desired = BuildDesiredAuraSoundRegistrations()
    local trigger = Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added or 0

    -- Add replacements before removing stale ones, so a failed refresh
    -- never leaves us with zero working registrations.
    for key, soundInfo in pairs(desired) do
        if not auraSoundHandles[key] then
            local ok, handle = pcall(C_UnitAuras.AddAuraSound, trigger, soundInfo)
            if ok and handle then
                auraSoundHandles[key] = handle
            else
                Debug("AddAuraSound failed for", key, tostring(handle))
            end
        end
    end

    for key, handle in pairs(auraSoundHandles) do
        if not desired[key] then
            local ok = pcall(C_UnitAuras.RemoveAuraSound, handle)
            if ok then
                auraSoundHandles[key] = nil
            end
        end
    end

    local count = 0
    for _ in pairs(auraSoundHandles) do count = count + 1 end
    Debug("Tier B (AddAuraSound) registrations active:", count)
end

local function ScheduleAuraSoundRefresh(delay)
    if not HAS_AURA_SOUND_API then return end

    if auraSoundRefreshScheduled then
        auraSoundRefreshPending = true
        return
    end

    auraSoundRefreshScheduled = true
    C_Timer.After(delay or 0, function()
        auraSoundRefreshScheduled = false
        RefreshAuraSoundRegistrations()
        if auraSoundRefreshPending then
            ScheduleAuraSoundRefresh(1)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Shared: figure out what I can cure from my own known spells (never
-- secret). Feeds both Tier A's curve and Tier B's registration set.
-- ---------------------------------------------------------------------------
local function RecomputeDispelTypes()
    wipe(myDispelTypes)

    local _, classToken = UnitClass("player")
    if CLASSES_WITH_NO_DISPEL[classToken] then
        Debug("Recompute: class", classToken, "has no single-target dispel, skipping")
        RebuildCurve()
        ScheduleAuraSoundRefresh(0)
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
    ScheduleAuraSoundRefresh(0)

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
-- Tier A: Decursive's own UnitDebuff() polyfill for the modern client,
-- copied 1:1. Kept as the chat-print source, and as the full sound
-- fallback on clients that don't have AddAuraSound yet.
-- ---------------------------------------------------------------------------
local DISPEL_FILTER = "RAID_PLAYER_DISPELLABLE"

local function GetUnitDebuff(unitToken, i)
    local ok, auraData = pcall(C_UnitAuras.GetDebuffDataByIndex, unitToken, i, DISPEL_FILTER)
    if not ok or not auraData then
        return nil
    end
    return auraData.name, auraData.dispelName, auraData.spellId, auraData.auraInstanceID
end

-- Aura tracking -- alert once per NEW application, not on every refresh tick.
local alertedInstance = {} -- [unit] = auraInstanceID we already alerted for

local function CheckUnitForDispellableDebuff(unit)
    if not IsEnabled() then return end
    if not IsInMythicPlus() then return end
    if not next(myDispelTypes) then return end
    if not C_UnitAuras then return end

    if InCombatLockdown and InCombatLockdown() then
        Debug("Skip: in combat, aura data may be secret/tainted")
        return
    end

    local matchedInstanceID = nil
    for i = 1, 40 do
        local name, typeName, spellID, auraInstanceID = GetUnitDebuff(unit, i)
        if not name then break end

        local secretMode = canaccessvalue and (not canaccessvalue(typeName))

        if not secretMode then
            if typeName and typeName ~= "" and myDispelTypes[typeName] then
                Debug("Precise match on", unit, "type:", typeName)
                matchedInstanceID = auraInstanceID
                break
            end

        elseif dispelCurve and auraInstanceID then
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
            -- If Tier B is live on this client, it already owns the sound
            -- (and works through combat, unlike this scan); Tier A just
            -- supplies the text.
            AnnounceDispellableDebuff(unit, not HAS_AURA_SOUND_API)
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
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" then
        if unit and (unit == "player" or unit:match("^party%d$") or unit:match("^raid%d+$")) then
            CheckUnitForDispellableDebuff(unit)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        RecomputeDispelTypes()
        wipe(alertedInstance)
        ScheduleAuraSoundRefresh(1)

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED" then
        RecomputeDispelTypes()

    elseif event == "GROUP_ROSTER_UPDATE" then
        wipe(alertedInstance)
        ScheduleAuraSoundRefresh(0)

    elseif event == "PLAYER_REGEN_ENABLED" then
        if auraSoundRefreshPending then
            ScheduleAuraSoundRefresh(0)
        end
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
        local handleCount = 0
        for _ in pairs(auraSoundHandles) do handleCount = handleCount + 1 end

        print("|cff33ccff[cxUI DispelAlert]|r class:", classToken, "level:", UnitLevel("player"),
            "enabled:", IsEnabled() and "yes" or "no",
            "in allowed zone:", IsInMythicPlus() and "yes" or "no")
        print("|cff33ccff[cxUI DispelAlert]|r can currently cure:",
            (#summary > 0) and table.concat(summary, ", ") or "NOTHING (no known dispel spell yet)")
        print("|cff33ccff[cxUI DispelAlert]|r Tier B (AddAuraSound) available:",
            HAS_AURA_SOUND_API and "yes" or "no", "-- active registrations:", handleCount)

    else
        print("|cff33ccff[cxUI DispelAlert]|r usage: /cxdispel debug | /cxdispel status")
    end
end