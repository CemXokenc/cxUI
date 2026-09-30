local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: EXECUTE ALERT (Warrior)
-- Plays a sound and flashes "EXECUTE!" the moment Execute becomes usable on
-- the current target because it entered execute range.
--
-- Detection: C_Spell.IsSpellUsable(executeSpellID) flips false -> true. That is
-- a plain boolean (not a Secret Value), unlike UnitHealth() on enemy targets.
-- "In range" = usable OR insufficientPower, so a rage-starved Execute that is
-- already in range still counts.
--
-- Sudden Death false-positive fix: a Sudden Death proc makes Execute castable
-- on ANY target and glows a fixed set of 4 spellIDs together. If any of them
-- is glowing (tracked from SHOW/HIDE events, not by polling IsSpellOverlayed)
-- we treat it as a proc and skip evaluation. When the whole set clears,
-- IsSpellUsable can still read stale for that frame, so the re-check is
-- delayed slightly.
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "warriorExecuteAlert",
    name  = "Execute Alert — Warrior",
    desc  = "Sound + on-screen 'EXECUTE!' when your target enters execute range.",
    info = "Plays 'Execute' and flashes 'EXECUTE!' on screen the moment Execute becomes usable on your target (target entered execute range). Ignores Sudden Death procs so it only fires for a real health-threshold entry. Warrior only.",
    class = "WARRIOR",
    sound = { kind = "file", value = ns.Media("ExecuteAlert", "ExecuteAlert.ogg"), name = "Execute Alert", premium = true },
}

-- Only one of these will ever be known on a given character.
local EXECUTE_SPELL_IDS = {
    [163201] = true, -- Execute (Arms)
    [5308]   = true, -- Execute (Fury)
}

-- Spell IDs observed glowing together during a Sudden Death proc window.
local SUDDEN_DEATH_GLOW_IDS = {
    [163201] = true, [5308] = true,
    [281000] = true, -- live action-bar override id for Execute
    [330334] = true, -- glows/clears in lockstep with the above
}

local EXECUTE_SOUND_COOLDOWN = 5
local lastSoundTime = 0

local executeSpellID
local lastInRange = nil -- nil = unknown/no target yet
local glowingSpells = {}

local alertText
local alertFadeGen = 0

local function CacheExecuteSpell()
    executeSpellID = nil
    for spellID in pairs(EXECUTE_SPELL_IDS) do
        if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
            executeSpellID = spellID
            break
        end
    end
end

local function IsExecuteGlowing()
    for spellID in pairs(SUDDEN_DEATH_GLOW_IDS) do
        if glowingSpells[spellID] then return true end
    end
    return false
end

local function FlashExecuteText()
    alertFadeGen = alertFadeGen + 1
    local myGen = alertFadeGen
    alertText:Show()
    UIFrameFadeIn(alertText, 0.1, alertText:GetAlpha(), 1)
    F:After(1.0, function()
        if alertFadeGen ~= myGen then return end -- superseded by a newer flash
        UIFrameFadeOut(alertText, 0.6, alertText:GetAlpha(), 0)
        F:After(0.6, function()
            if alertFadeGen == myGen then alertText:Hide() end
        end)
    end)
end

local function FireExecuteAlert()
    local now = GetTime()
    if now - lastSoundTime >= EXECUTE_SOUND_COOLDOWN then
        lastSoundTime = now
        F:PlaySound()
    end
    FlashExecuteText()
end

local function CheckRange()
    if not executeSpellID then return end
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        lastInRange = nil
        return
    end
    if not (C_Spell and C_Spell.IsSpellUsable) then return end
    if IsExecuteGlowing() then return end -- Sudden Death proc window

    local ok, usable, insufficientPower = pcall(C_Spell.IsSpellUsable, executeSpellID)
    if not ok or usable == nil then return end

    local inRange = usable or insufficientPower
    if inRange ~= lastInRange then
        local wasFalse = (lastInRange ~= true) -- nil (just reset) counts same as false
        lastInRange = inRange
        if inRange and wasFalse then FireExecuteAlert() end
    end
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        CacheExecuteSpell()
        lastInRange = nil
        wipe(glowingSpells)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        F:After(0.5, function()
            CacheExecuteSpell()
            lastInRange = nil
        end)

    elseif event == "PLAYER_TARGET_CHANGED" then
        lastInRange = nil
        CheckRange()

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = ...
        local isShowing = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        glowingSpells[spellID] = isShowing or nil
        if (not isShowing) and (not IsExecuteGlowing()) then
            F:After(0.15, CheckRange) -- let IsSpellUsable settle
        else
            CheckRange()
        end

    else -- SPELL_UPDATE_USABLE / ACTIONBAR_UPDATE_USABLE
        CheckRange()
    end
end

function F:OnEnable()
    if not alertText then
        alertText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        alertText:SetFont((alertText:GetFont()), 32, "OUTLINE")
        alertText:SetTextColor(1, 0.15, 0.15, 1)
        alertText:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
        alertText:SetText("EXECUTE!")
        alertText:SetAlpha(0)
        alertText:Hide()
    end

    CacheExecuteSpell()
    lastInRange = nil
    wipe(glowingSpells)

    local ev = self:NewEventFrame()
    ev:SetScript("OnEvent", OnEvent)
    -- A renamed/removed event must not take the others down with it.
    for _, e in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE",
        "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE",
        "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    }) do
        pcall(ev.RegisterEvent, ev, e)
    end
end

function F:OnDisable()
    alertFadeGen = alertFadeGen + 1
    lastInRange = nil
    wipe(glowingSpells)
    if alertText then alertText:SetAlpha(0); alertText:Hide() end
end
