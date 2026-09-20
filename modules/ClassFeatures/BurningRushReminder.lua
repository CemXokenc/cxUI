local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: BURNING RUSH REMINDER (Warlock)
-- Pulsing on-screen alert while Burning Rush is active (in combat).
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "burningRushReminder",
    name  = "Burning Rush Reminder — Warlock",
    desc  = "Pulsing on-screen alert while Burning Rush is active.",
    class = "WARLOCK",
}

-- Constants - edit only this block
local REMINDER_TEXT        = "BURNING RUSH ACTIVE!"
local REMINDER_FONT        = "Fonts\\FRIZQT__.TTF"
local REMINDER_FONT_SIZE   = 22
local REMINDER_R, REMINDER_G, REMINDER_B = 1, 0.2, 0.2
local REMINDER_PULSE_SPEED = 1.5   -- pulses per second
local REMINDER_PULSE_MIN   = 0.15  -- minimum alpha at the bottom of each pulse
local REMINDER_X, REMINDER_Y = 0, 200

local SPELL_BURNING_RUSH = 111400

local reminderFrame, reminderLabel, pulseFrame
local pulseTimer = 0

local isActive   = false
local instanceID = nil
local expecting  = false -- armed after the spellcast, cleared on UNIT_AURA

local function OnPulse(_, elapsed)
    pulseTimer = pulseTimer + elapsed
    local sine = (math.sin(pulseTimer * REMINDER_PULSE_SPEED * math.pi * 2) + 1) / 2
    reminderLabel:SetAlpha(REMINDER_PULSE_MIN + sine * (1 - REMINDER_PULSE_MIN))
end

local function ShowReminder()
    pulseTimer = 0
    reminderLabel:SetAlpha(1)
    reminderFrame:Show()
    pulseFrame:SetScript("OnUpdate", OnPulse)
    pulseFrame:Show()
end

local function HideReminder()
    if not reminderFrame then return end
    reminderFrame:Hide()
    pulseFrame:SetScript("OnUpdate", nil)
    pulseFrame:Hide()
    reminderLabel:SetAlpha(1)
end

local function Refresh()
    if isActive then ShowReminder() else HideReminder() end
end

local function OnEvent(_, event, arg1, arg2, arg3)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg3 == SPELL_BURNING_RUSH then expecting = true end

    elseif event == "UNIT_AURA" then
        local info = arg2
        if not info then return end
        if expecting and info.addedAuras then
            local aura = info.addedAuras[1]
            if aura then
                instanceID = aura.auraInstanceID
                isActive   = true
                expecting  = false
            end
        end
        if info.removedAuraInstanceIDs and instanceID then
            for _, id in ipairs(info.removedAuraInstanceIDs) do
                if id == instanceID then
                    isActive   = false
                    instanceID = nil
                    break
                end
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat: catch the aura if it was already active before the pull
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_BURNING_RUSH)
        if aura then
            isActive   = true
            instanceID = aura.auraInstanceID
        end

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_DEAD" then
        isActive, instanceID, expecting = false, nil, false
    end

    Refresh()
end

function F:OnEnable()
    if not reminderFrame then
        reminderFrame = CreateFrame("Frame", "CXUI_WarlockReminderFrame", UIParent)
        reminderFrame:SetSize(400, 60)
        reminderFrame:SetPoint("CENTER", UIParent, "CENTER", REMINDER_X, REMINDER_Y)
        reminderFrame:Hide()

        reminderLabel = reminderFrame:CreateFontString(nil, "OVERLAY")
        reminderLabel:SetPoint("CENTER")
        reminderLabel:SetFont(REMINDER_FONT, REMINDER_FONT_SIZE, "OUTLINE")
        reminderLabel:SetText(REMINDER_TEXT)
        reminderLabel:SetTextColor(REMINDER_R, REMINDER_G, REMINDER_B)
    end
    -- Pulse driver: its OnUpdate is only set while the reminder is visible.
    pulseFrame = pulseFrame or self:NewFrame("Frame", nil, UIParent)
    pulseFrame:Hide()

    local ev = self:NewEventFrame()
    ev:SetScript("OnEvent", OnEvent)
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_DEAD")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterUnitEvent("UNIT_AURA", "player")

    -- Enabled while already rushing in combat
    if InCombatLockdown() then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_BURNING_RUSH)
        if aura then isActive, instanceID = true, aura.auraInstanceID end
        Refresh()
    end
end

function F:OnDisable()
    isActive, instanceID, expecting = false, nil, false
    HideReminder()
end

-- Debug: /cxwarlock show | hide | status
SLASH_CXWARLOCK1 = "/cxwarlock"
SlashCmdList["CXWARLOCK"] = function(msg)
    local cmd = (msg or ""):lower()
    if not F:IsOn() then ns.Print("Warlock: Burning Rush Reminder is off"); return end
    if cmd == "show" then
        ShowReminder()
        ns.Print("Warlock: reminder forced visible")
    elseif cmd == "hide" then
        HideReminder()
        ns.Print("Warlock: reminder forced hidden")
    elseif cmd == "status" then
        ns.Print("Warlock: active=" .. tostring(isActive)
            .. "  instanceID=" .. tostring(instanceID)
            .. "  expecting=" .. tostring(expecting))
    else
        ns.Print("Warlock: /cxwarlock [show|hide|status]")
    end
end
