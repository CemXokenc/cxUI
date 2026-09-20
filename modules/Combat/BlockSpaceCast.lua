local addonName, ns = ...

-- ===========================================================================
-- COMBAT: BLOCK SPACE WHILE CASTING
-- Overrides the SPACE key to do nothing while you cast or channel, so muscle
-- memory can't jump-cancel your spell.
--
-- SetOverrideBindingClick / ClearOverrideBindings are protected: they can't
-- run in combat. If the state must change mid-combat it is remembered and
-- applied when combat ends (that one-shot listener is only registered while
-- something is pending).
-- ===========================================================================

local M = ns:GetModule("Combat")

local F = M:NewFeature{
    key  = "SpaceCastInterruptBlock",
    name = "Block Space Bar During Cast",
    desc = "Disables the Space bar while casting to prevent accidental jumps.",
}

local dummy
local bindOwner = CreateFrame("Frame")
local pendingBlock = nil -- nil = nothing pending, true/false = desired state

local pendingWatcher = CreateFrame("Frame")

local function Apply(shouldBlock)
    if InCombatLockdown() then
        pendingBlock = shouldBlock
        pendingWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if shouldBlock and dummy then
        SetOverrideBindingClick(bindOwner, false, "SPACE", "CXUI_SpaceBlockDummy")
    else
        ClearOverrideBindings(bindOwner)
    end
    pendingBlock = nil
end

pendingWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingBlock ~= nil then Apply(pendingBlock and F:IsOn()) end
end)

function F:OnEnable()
    if not dummy then
        -- Secure button SPACE is redirected to; attributes are set once, out of combat.
        dummy = CreateFrame("Button", "CXUI_SpaceBlockDummy", UIParent, "SecureActionButtonTemplate")
        dummy:SetAttribute("type", "macro")
        dummy:SetAttribute("macrotext", "")
    end

    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    ev:SetScript("OnEvent", function(_, event)
        Apply(event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START")
    end)
end

function F:OnDisable()
    Apply(false) -- releases the SPACE override (deferred to combat end if needed)
end
