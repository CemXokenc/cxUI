local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: WARRIOR — Execute Alert
-- ---------------------------------------------------------------------------
-- Speaks "Execute" via TTS and flashes on-screen text the moment Execute
-- becomes usable on the current target due to it entering execute range.
--
-- Detection: C_Spell.IsSpellUsable(executeSpellID) flips false -> true.
-- This is a plain boolean UI-level state (not a Secret Value), unlike
-- UnitHealth() on an enemy target which is unreadable in this client.
--
-- "In range" = usable OR insufficientPower, so a rage-starved Execute that's
-- already in range but can't afford its cost still counts, and doesn't need
-- rage regen to be the thing that "discovers" the target is low.
--
-- False-positive fix, take 3: Sudden Death makes Execute castable on ANY
-- target regardless of health, which also flips IsSpellUsable() to true.
--   Take 1 (name-based aura check) failed silently: GetAuraDataBySpellName
--   matches on the LOCALIZED name string, so on a non-enUS client "Sudden
--   Death" never matches.
--   Take 2 (poll IsSpellOverlayed(spellID) reactively) also failed, and not
--   for a locale reason this time: confirmed live that IsSpellOverlayed()
--   can report false immediately after the corresponding
--   SPELL_ACTIVATION_OVERLAY_GLOW_SHOW event already fired for that exact
--   spellID. Polling it is not trustworthy.
--   Take 3 (this one): stop polling, track glow state ourselves purely from
--   the SHOW/HIDE events. Confirmed live: when Sudden Death procs, FOUR
--   spellIDs glow together as a block -- 5308 (Execute/Fury), 163201
--   (Execute/Arms), 281000 (the live action-bar override id for Execute),
--   and 330334 (unconfirmed name, but it appears/disappears in lockstep with
--   the other three every time) -- and they all clear together the moment
--   the proc window ends. A genuine health-threshold entry glows none of
--   these (verified: a real execute-range kill produced zero glow events
--   for any Execute-related spellID). So: if ANY of that set is currently
--   glowing per our own SHOW/HIDE bookkeeping, treat it as a proc and skip
--   evaluation entirely.
--
-- Also removed: reading player auras (UNIT_AURA payload / AuraUtil) to try
-- to identify Sudden Death directly. Confirmed live and dead end: in combat,
-- UNIT_AURA's updateInfo.isFullUpdate is itself a secret value ("attempt to
-- perform boolean test on ... secret boolean value, while execution tainted
-- by 'cxUI'"), and AuraUtil.ForEachAura's underlying GetAuraSlots() throws
-- "Auras cannot be accessed when secret while tainted". Aura reading is
-- fully blocked for addons in combat on this client, full stop.
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
-- proc window (see comment block above). executeSpellID variants are also
-- in EXECUTE_SPELL_IDS above; kept separate here so this list can be edited
-- independently if Blizzard changes the override/companion IDs later.
local SUDDEN_DEATH_GLOW_IDS = {
    [163201] = true, -- Execute (Arms)
    [5308]   = true, -- Execute (Fury)
    [281000] = true, -- live action-bar override id for Execute
    [330334] = true, -- unconfirmed name; glows/clears in lockstep with the above
}

local executeSpellID
local lastInRange = nil -- nil = unknown/no target yet, true/false once evaluated
local glowingSpells = {} -- [spellID] = true while its overlay glow is showing

-- ===========================================================================
-- TEMP: EXTENSIVE DEBUG
-- ---------------------------------------------------------------------------
-- Flip to false (or delete this whole block + its call sites) once the
-- glow-set-based filter above is confirmed solid over a real play session.
-- ===========================================================================
local DEBUG_EXECUTE = true
local debugSeq = 0

local function DLog(fmt, ...)
    if not DEBUG_EXECUTE then return end
    debugSeq = debugSeq + 1
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = "<format error: " .. tostring(fmt) .. ">" end
    print(string.format("|cff33ff99[CXUI ExecDBG #%d @%.2f]|r %s", debugSeq, GetTime(), msg))
end

local function DSafe(label, fn, ...)
    local results = { pcall(fn, ...) }
    local ok = table.remove(results, 1)
    if not ok then
        DLog("%s -> ERROR: %s", label, tostring(results[1]))
        return nil
    end
    return unpack(results)
end

local function CacheExecuteSpell()
    executeSpellID = nil
    for spellID in pairs(EXECUTE_SPELL_IDS) do
        if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
            executeSpellID = spellID
            break
        end
    end
    DLog("CacheExecuteSpell -> executeSpellID=%s", tostring(executeSpellID))
end

-- True if any spellID in the known Sudden-Death-proc glow set is currently
-- glowing, per our own event bookkeeping (NOT via IsSpellOverlayed polling
-- -- that was confirmed unreliable, see comment block up top).
local function IsExecuteGlowing()
    for spellID in pairs(SUDDEN_DEATH_GLOW_IDS) do
        if glowingSpells[spellID] then
            return true, spellID
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- TTS ("Execute" spoken alert)
-- ---------------------------------------------------------------------------

local ttsVoiceID

local function EnsureTtsVoice()
    if ttsVoiceID then return ttsVoiceID end

    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum.TtsVoiceType then
        local ok, voiceID = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
        if ok and voiceID and voiceID > 0 then
            ttsVoiceID = voiceID
            return ttsVoiceID
        end
    end

    -- Fallback: first voice the client actually has installed locally.
    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
        if ok and voices and voices[1] then
            ttsVoiceID = voices[1].voiceID
        end
    end

    return ttsVoiceID
end

local function SpeakExecute()
    local voiceID = EnsureTtsVoice()
    if not voiceID then return end -- no TTS voice installed on this client
    -- overlap=true so it isn't silently dropped/queued behind other TTS
    -- (chat readout, quest text, etc) -- this is meant to be an urgent cue.
    pcall(C_VoiceChat.SpeakText, voiceID, "Execute", 0, 100, true)
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
    SpeakExecute()
    FlashExecuteText()
end

local function CheckRange(reason)
    reason = reason or "?"

    if not executeSpellID then
        DLog("CheckRange(%s): no executeSpellID known, bailing", reason)
        return
    end
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        lastInRange = nil
        DLog("CheckRange(%s): no valid target, lastInRange reset to nil", reason)
        return
    end
    if not (C_Spell and C_Spell.IsSpellUsable) then
        DLog("CheckRange(%s): C_Spell.IsSpellUsable missing on this client!", reason)
        return
    end

    local targetName = DSafe("UnitName(target)", UnitName, "target")
    local glowing, glowSpellID = IsExecuteGlowing()
    local usableRaw, insufficientPowerRaw = DSafe("C_Spell.IsSpellUsable", C_Spell.IsSpellUsable, executeSpellID)

    DLog("CheckRange(%s): target=%s glowing=%s(%s) usable=%s insufficientPower=%s lastInRange=%s",
        reason, tostring(targetName), tostring(glowing), tostring(glowSpellID), tostring(usableRaw), tostring(insufficientPowerRaw), tostring(lastInRange))

    if glowing then
        -- Sudden Death proc window (see glow-set comment up top) -- don't
        -- touch lastInRange, just wait for the glow to clear and re-check
        -- for real (the glow events below cover that).
        return
    end

    local usable, insufficientPower = usableRaw, insufficientPowerRaw
    if usable == nil then return end

    local inRange = usable or insufficientPower

    if inRange ~= lastInRange then
        local wasFalse = (lastInRange ~= true) -- nil (just reset) counts same as false
        DLog("CheckRange(%s): inRange CHANGED %s -> %s (wasFalse=%s)", reason, tostring(lastInRange), tostring(inRange), tostring(wasFalse))
        lastInRange = inRange
        if inRange and wasFalse then
            DLog("CheckRange(%s): >>> FIRING ALERT <<<", reason)
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
SafeRegisterEvent("VOICE_CHAT_TTS_VOICES_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    DLog("EVENT: %s", event)

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

    if event == "VOICE_CHAT_TTS_VOICES_UPDATE" then
        ttsVoiceID = nil -- re-resolve next time we actually need to speak
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        lastInRange = nil
        CheckRange("PLAYER_TARGET_CHANGED")
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
        DLog("%s: spellID=%s tracked=%s (executeSpellID=%s)",
            event, tostring(spellID), tostring(SUDDEN_DEATH_GLOW_IDS[spellID] and true or false), tostring(executeSpellID))

        if (not isShowing) and (not (IsExecuteGlowing())) then
            -- The whole proc-glow set just fully cleared. C_Spell.IsSpellUsable
            -- can still read stale (true) for the same frame the glow hides
            -- (confirmed by test: evaluating synchronously right here produced
            -- a false alert), so don't trust an immediate read on this exact
            -- event -- give it a beat to catch up, then confirm for real.
            C_Timer.After(0.15, function() CheckRange(event .. "/settled") end)
        else
            CheckRange(event)
        end
        return
    end

    if event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_USABLE" then
        CheckRange(event)
        return
    end
end)