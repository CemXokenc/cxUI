local addonName, ns = ...
-- ===========================================================================
-- SMALL TWEAKS: BLOCK SPACE WHILE CASTING
-- Overrides the SPACE key to do nothing while the player is casting a spell
-- or channeling one, to prevent accidental interrupts from muscle-memory
-- mashing the jump key.
-- ===========================================================================
-- Dummy secure button the SPACE key gets redirected to. Its attributes are
-- set once here at load time (not during combat), so this is safe under
-- combat lockdown — only SetOverrideBindingClick is called in combat.
local dummy = CreateFrame("Button", "CXUI_SpaceBlockDummy", UIParent, "SecureActionButtonTemplate")
dummy:SetAttribute("type", "macro")
dummy:SetAttribute("macrotext", "")

local frame = CreateFrame("Frame")

local function IsEnabled()
    return CXUI_DB and CXUI_DB.SpaceCastInterruptBlock
end

local function BlockSpace()
    SetOverrideBindingClick(frame, false, "SPACE", "CXUI_SpaceBlockDummy")
end

local function UnblockSpace()
    ClearOverrideBindings(frame)
end

frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

frame:SetScript("OnEvent", function(self, event, unit)
    if unit ~= "player" then return end

    if not IsEnabled() then
        UnblockSpace()
        return
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        BlockSpace()
    else
        -- STOP / FAILED / INTERRUPTED / CHANNEL_STOP
        UnblockSpace()
    end
end)