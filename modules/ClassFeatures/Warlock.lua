local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: WARLOCK (classID 9)
-- Features:
--   · Burning Rush Reminder — pulsing on-screen alert while Burning Rush
--     is active. Controlled by CXUI_DB.burningRushReminder.
-- ===========================================================================

local CF = ns.CF
if not CF or CF.CLASS_ID ~= 9 then return end

-- ---------------------------------------------------------------------------
-- Constants — edit only this block
-- ---------------------------------------------------------------------------

local REMINDER_TEXT        = "BURNING RUSH ACTIVE!"
local REMINDER_FONT        = "Fonts\\FRIZQT__.TTF"
local REMINDER_FONT_SIZE   = 22
local REMINDER_R           = 1
local REMINDER_G           = 0.2
local REMINDER_B           = 0.2
local REMINDER_PULSE_SPEED = 1.5   -- pulses per second
local REMINDER_PULSE_MIN   = 0.15  -- minimum alpha at the bottom of each pulse (0–1)
local REMINDER_X           = 0     -- horizontal offset from screen center
local REMINDER_Y           = 200   -- vertical offset from screen center

local SPELL_BURNING_RUSH   = 111400

-- ---------------------------------------------------------------------------
-- Frame & label
-- ---------------------------------------------------------------------------

local reminderFrame = CreateFrame("Frame", "CXUI_WarlockReminderFrame", UIParent)
reminderFrame:SetSize(400, 60)
reminderFrame:SetPoint("CENTER", UIParent, "CENTER", REMINDER_X, REMINDER_Y)
reminderFrame:Hide()

local reminderLabel = reminderFrame:CreateFontString(nil, "OVERLAY")
reminderLabel:SetPoint("CENTER")
reminderLabel:SetFont(REMINDER_FONT, REMINDER_FONT_SIZE, "OUTLINE")
reminderLabel:SetText(REMINDER_TEXT)
reminderLabel:SetTextColor(REMINDER_R, REMINDER_G, REMINDER_B)

-- ---------------------------------------------------------------------------
-- Pulse animation — sine wave drives alpha between REMINDER_PULSE_MIN and 1
-- ---------------------------------------------------------------------------

local pulseTimer = 0

local pulseFrame = CreateFrame("Frame", nil, UIParent)
pulseFrame:Hide()
pulseFrame:SetScript("OnUpdate", function(_, elapsed)
    pulseTimer = pulseTimer + elapsed
    local sine = (math.sin(pulseTimer * REMINDER_PULSE_SPEED * math.pi * 2) + 1) / 2
    reminderLabel:SetAlpha(REMINDER_PULSE_MIN + sine * (1 - REMINDER_PULSE_MIN))
end)

-- ---------------------------------------------------------------------------
-- Show / hide helpers
-- ---------------------------------------------------------------------------

local function ShowReminder()
    if not CXUI_DB or not CXUI_DB.burningRushReminder then return end
    pulseTimer = 0
    reminderLabel:SetAlpha(1)
    reminderFrame:Show()
    pulseFrame:Show()
end

local function HideReminder()
    reminderFrame:Hide()
    pulseFrame:Hide()
    reminderLabel:SetAlpha(1)
end

-- ---------------------------------------------------------------------------
-- Aura tracking state
-- ---------------------------------------------------------------------------

local isActive   = false
local instanceID = nil
local expecting  = false  -- armed after the spellcast, cleared on UNIT_AURA

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local warlockFrame = CreateFrame("Frame")
warlockFrame:RegisterEvent("PLAYER_LOGIN")

warlockFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "PLAYER_LOGIN" then
        local _, _, cid = UnitClass("player")
        if cid ~= 9 then self:UnregisterAllEvents(); return end
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_DEAD")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterUnitEvent("UNIT_AURA", "player")

    -- Player just cast Burning Rush — arm the aura watcher
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg3 == SPELL_BURNING_RUSH then
            expecting = true
        end

    -- Aura update on the player
    elseif event == "UNIT_AURA" then
        local info = arg2
        if not info then return end

        -- Aura appeared and we were expecting it
        if expecting and info.addedAuras then
            local aura = info.addedAuras[1]
            if aura then
                instanceID = aura.auraInstanceID
                isActive   = true
                expecting  = false
            end
        end

        -- Aura was removed
        if info.removedAuraInstanceIDs and instanceID then
            for _, id in ipairs(info.removedAuraInstanceIDs) do
                if id == instanceID then
                    isActive   = false
                    instanceID = nil
                    break
                end
            end
        end

    -- Entered combat — catch the aura if it was already active before the pull
    elseif event == "PLAYER_REGEN_DISABLED" then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_BURNING_RUSH)
        if aura then
            isActive   = true
            instanceID = aura.auraInstanceID
        end

    -- Left combat or died — always reset
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_DEAD" then
        isActive   = false
        instanceID = nil
        expecting  = false
    end

    if isActive then ShowReminder() else HideReminder() end
end)

-- ---------------------------------------------------------------------------
-- Debug commands
-- ---------------------------------------------------------------------------

SLASH_CXWARLOCK1 = "/cxwarlock"
SlashCmdList["CXWARLOCK"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "show" then
        ShowReminder()
        print("|cff0070ddcxUI Warlock:|r reminder forced visible")
    elseif cmd == "hide" then
        HideReminder()
        print("|cff0070ddcxUI Warlock:|r reminder forced hidden")
    elseif cmd == "status" then
        print("|cff0070ddcxUI Warlock:|r active=" .. tostring(isActive)
            .. "  instanceID=" .. tostring(instanceID)
            .. "  expecting=" .. tostring(expecting))
    else
        print("|cff0070ddcxUI Warlock:|r /cxwarlock [show|hide|status]")
    end
end