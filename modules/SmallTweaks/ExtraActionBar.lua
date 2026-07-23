local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- EXTRA ACTION BUTTON / ZONE ABILITY: remove decorative ring texture
--
-- Turns these one-off commands into something permanent (Blizzard re-applies
-- the decorative texture every time the button shows -- e.g. each new quest
-- objective, boss encounter, or covenant/garrison ability -- so a single
-- /run only lasts until the next one):
--   /run ExtraActionButton1.style:SetAlpha(0)
--   /run ExtraActionButton1.style:Hide()
--   /run ZoneAbilityFrame.Style:SetAlpha(0)
--   /run ZoneAbilityFrame.Style:Hide()
-- ---------------------------------------------------------------------------

local function IsEnabled()
    return CXUI_DB and CXUI_DB.hideExtraActionDecor
end

-- Hides a decorative texture now, and hooks Show/SetAlpha so Blizzard's own
-- code can't bring it back the next time the button re-shows.
local function SuppressDecor(texture)
    if not texture or texture.cxuiSuppressed then return end
    texture.cxuiSuppressed = true

    texture:SetAlpha(0)
    texture:Hide()

    hooksecurefunc(texture, "Show", function(self)
        if IsEnabled() then self:Hide() end
    end)
    hooksecurefunc(texture, "SetAlpha", function(self, a)
        if IsEnabled() and a and a > 0 then self:SetAlpha(0) end
    end)
end

local function ApplyExtraActionButton()
    if not IsEnabled() then return end
    if ExtraActionButton1 and ExtraActionButton1.style then
        SuppressDecor(ExtraActionButton1.style)
    end
end

local function ApplyZoneAbility()
    if not IsEnabled() then return end
    if ZoneAbilityFrame and ZoneAbilityFrame.Style then
        SuppressDecor(ZoneAbilityFrame.Style)
    end
end

-- The .style/.Style texture only exists once its owning frame has been
-- created, and both buttons only ever show on demand (quest objective,
-- boss ability, covenant/garrison ability), so re-check on every relevant
-- OnShow rather than assuming they exist at login.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    ApplyExtraActionButton()
    ApplyZoneAbility()

    if ExtraActionBarFrame and not f.hookedExtraBar then
        f.hookedExtraBar = true
        ExtraActionBarFrame:HookScript("OnShow", ApplyExtraActionButton)
    end
    if ExtraActionButton1 and not f.hookedExtraButton then
        f.hookedExtraButton = true
        ExtraActionButton1:HookScript("OnShow", ApplyExtraActionButton)
    end
    if ZoneAbilityFrame and not f.hookedZoneAbility then
        f.hookedZoneAbility = true
        ZoneAbilityFrame:HookScript("OnShow", ApplyZoneAbility)
    end
end)
