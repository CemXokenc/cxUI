local addonName, ns = ...

-- ===========================================================================
-- INTERFACE: HIDE EXTRA ACTION BUTTON DECOR
-- Removes the decorative ring texture around the Extra Action Button and Zone
-- Ability button. Blizzard re-applies it every time the button shows (new
-- quest objective, boss ability, covenant ability...), so the textures'
-- Show/SetAlpha are hooked instead of a one-off /run ...:Hide().
-- ===========================================================================

local I = ns:GetModule("Interface")

local F = I:NewFeature{
    key  = "hideExtraActionDecor",
    name = "Hide Extra Action Button Decor",
    desc = "Removes the decorative ring texture from ExtraActionButton1 and ZoneAbilityFrame.",
}

local suppressed = {} -- texture -> true

local function SuppressDecor(texture)
    if not texture then return end
    suppressed[texture] = true
    texture:SetAlpha(0)
    texture:Hide()
    F:Hook(texture, "Show", function(self) self:Hide() end)
    F:Hook(texture, "SetAlpha", function(self, a)
        if a and a > 0 then self:SetAlpha(0) end
    end)
end

local function ApplyExtraActionButton()
    if not F:IsOn() then return end
    if ExtraActionButton1 and ExtraActionButton1.style then SuppressDecor(ExtraActionButton1.style) end
end

local function ApplyZoneAbility()
    if not F:IsOn() then return end
    if ZoneAbilityFrame and ZoneAbilityFrame.Style then SuppressDecor(ZoneAbilityFrame.Style) end
end

-- The .style/.Style textures only exist once their frame has been created and
-- both buttons show on demand, so re-check on every relevant OnShow.
local function Apply()
    ApplyExtraActionButton()
    ApplyZoneAbility()
    F:HookScript(ExtraActionBarFrame,  "OnShow", ApplyExtraActionButton)
    F:HookScript(ExtraActionButton1,   "OnShow", ApplyExtraActionButton)
    F:HookScript(ZoneAbilityFrame,     "OnShow", ApplyZoneAbility)
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", Apply)
    Apply()
end

function F:OnDisable()
    -- Give the textures back (hooks are already inert: F:IsOn() is false).
    for texture in pairs(suppressed) do
        texture:SetAlpha(1)
        local owner = texture:GetParent()
        if owner and owner:IsShown() then texture:Show() end
    end
    wipe(suppressed)
end
