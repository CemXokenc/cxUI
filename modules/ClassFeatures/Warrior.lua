local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: WARRIOR — Execute Alert
-- ---------------------------------------------------------------------------
-- Plays a sound and flashes "EXECUTE!" on screen the moment Execute becomes
-- usable on the current target due to it entering execute range.
--
-- Detection: C_Spell.IsSpellUsable(executeSpellID) flips false -> true.
-- This is a plain boolean UI-level state (not a Secret Value), unlike
-- UnitHealth() on an enemy target which is unreadable in this client.
--
-- "In range" = usable OR insufficientPower, so a rage-starved Execute that's
-- already in range but can't afford its cost still counts, and doesn't need
-- rage regen to be the thing that "discovers" the target is low.
--
-- Sudden Death false-positive fix: Sudden Death makes Execute castable on
-- ANY target regardless of health, which also flips IsSpellUsable() to true.
-- Confirmed live: when Sudden Death procs, a fixed set of 4 spellIDs glow
-- together on the action bar -- 5308 (Execute/Fury), 163201 (Execute/Arms),
-- 281000 (the live action-bar override id for Execute), and 330334
-- (unconfirmed name, but it appears/disappears in lockstep with the other
-- three every time) -- and they all clear together the moment the proc
-- window ends. A genuine health-threshold entry glows none of these. So: if
-- any of that set is glowing (tracked ourselves from the SHOW/HIDE events,
-- not by polling IsSpellOverlayed -- that was confirmed unreliable), treat
-- it as a proc and skip evaluation entirely. When the whole set clears,
-- C_Spell.IsSpellUsable can still read stale for that same frame, so the
-- re-check is delayed slightly to let it settle before trusting it.
--
-- Toggle (Options > Module 4: Class Features > "Execute Alert — Warrior"):
--   CXUI_DB.warriorExecuteAlert
-- ===========================================================================

local _, playerClass = UnitClass("player")
if playerClass ~= "WARRIOR" then return end

-- Only one of these will ever be known on a given character.
local EXECUTE_SPELL_IDS = {
    [163201] = true, -- Execute (Arms)
    [5308]   = true, -- Execute (Fury)
}

-- The full set of spellIDs observed glowing together during a Sudden Death
-- proc window (see comment block above).
local SUDDEN_DEATH_GLOW_IDS = {
    [163201] = true, -- Execute (Arms)
    [5308]   = true, -- Execute (Fury)
    [281000] = true, -- live action-bar override id for Execute
    [330334] = true, -- unconfirmed name; glows/clears in lockstep with the above
}

local EXECUTE_SOUND_FILE = "Interface\\AddOns\\cxUI\\Media\\execute.mp3"

local executeSpellID
local lastInRange = nil -- nil = unknown/no target yet, true/false once evaluated
local glowingSpells = {} -- [spellID] = true while its overlay glow is showing

local function CacheExecuteSpell()
    executeSpellID = nil
    for spellID in pairs(EXECUTE_SPELL_IDS) do
        if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
            executeSpellID = spellID
            break
        end
    end
end

-- True if any spellID in the known Sudden-Death-proc glow set is currently
-- glowing, per our own event bookkeeping.
local function IsExecuteGlowing()
    for spellID in pairs(SUDDEN_DEATH_GLOW_IDS) do
        if glowingSpells[spellID] then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- On-screen "EXECUTE!" flash
-- ---------------------------------------------------------------------------

local alertText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
do
    local fontName = alertText:GetFont()
    alertText:SetFont(fontName, 32, "OUTLINE")
end
alertText:SetTextColor(1, 0.15, 0.15, 1)
alertText:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
alertText:SetText("EXECUTE!")
alertText:SetAlpha(0)
alertText:Hide()

local alertFadeGen = 0

local function FlashExecuteText()
    alertFadeGen = alertFadeGen + 1
    local myGen = alertFadeGen
    alertText:Show()
    UIFrameFadeIn(alertText, 0.1, alertText:GetAlpha(), 1)
    C_Timer.After(1.0, function()
        if alertFadeGen ~= myGen then return end -- superseded by a newer flash
        UIFrameFadeOut(alertText, 0.6, alertText:GetAlpha(), 0)
        C_Timer.After(0.6, function()
            if alertFadeGen == myGen then alertText:Hide() end
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Trigger
-- ---------------------------------------------------------------------------

local function FireExecuteAlert()
    if not (CXUI_DB and CXUI_DB.warriorExecuteAlert) then return end
    PlaySoundFile(EXECUTE_SOUND_FILE, "Master")
    FlashExecuteText()
end

local function CheckRange()
    if not executeSpellID then return end
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        lastInRange = nil
        return
    end
    if not (C_Spell and C_Spell.IsSpellUsable) then return end

    if IsExecuteGlowing() then
        -- Sudden Death proc window -- don't touch lastInRange, just wait
        -- for the glow to clear and re-check for real.
        return
    end

    local ok, usable, insufficientPower = pcall(C_Spell.IsSpellUsable, executeSpellID)
    if not ok or usable == nil then return end

    local inRange = usable or insufficientPower

    if inRange ~= lastInRange then
        local wasFalse = (lastInRange ~= true) -- nil (just reset) counts same as false
        lastInRange = inRange
        if inRange and wasFalse then
            FireExecuteAlert()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local f = CreateFrame("Frame", "CXUI_WarriorExecuteFrame")

-- Guards against a renamed/removed event name throwing during RegisterEvent
-- and taking every event below it down with it. Does NOT protect against a
-- PROTECTED registration (ADDON_ACTION_FORBIDDEN) -- that bypasses pcall
-- entirely, so anything like that must never be registered here at all.
local function SafeRegisterEvent(eventName)
    pcall(function() f:RegisterEvent(eventName) end)
end

SafeRegisterEvent("PLAYER_LOGIN")
SafeRegisterEvent("PLAYER_ENTERING_WORLD")
SafeRegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
SafeRegisterEvent("PLAYER_TALENT_UPDATE")
SafeRegisterEvent("PLAYER_TARGET_CHANGED")
SafeRegisterEvent("SPELL_UPDATE_USABLE")
SafeRegisterEvent("ACTIONBAR_UPDATE_USABLE")
SafeRegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
SafeRegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CacheExecuteSpell()
        lastInRange = nil
        wipe(glowingSpells)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        C_Timer.After(0.5, function()
            CacheExecuteSpell()
            lastInRange = nil
        end)
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        lastInRange = nil
        CheckRange()
        return
    end

    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = ...
        local isShowing = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        if isShowing then
            glowingSpells[spellID] = true
        else
            glowingSpells[spellID] = nil
        end

        if (not isShowing) and (not IsExecuteGlowing()) then
            -- The whole proc-glow set just fully cleared. IsSpellUsable can
            -- still read stale for the same frame the glow hides, so give
            -- it a beat to settle before trusting it.
            C_Timer.After(0.15, CheckRange)
        else
            CheckRange()
        end
        return
    end

    if event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_USABLE" then
        CheckRange()
        return
    end
end)