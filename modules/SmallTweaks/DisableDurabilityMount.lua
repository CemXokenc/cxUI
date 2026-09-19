local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: DISABLE DURABILITY / MOUNT SEATS FRAME
-- Hides two Blizzard indicators that sit near the minimap / objective tracker:
--   * DurabilityFrame       -- the little armor "man" with yellow/red pieces
--   * VehicleSeatIndicator  -- the seat icon shown on mounts/vehicles that
--                              can carry passengers
--
-- Blizzard re-shows both frames whenever durability changes or you mount,
-- so a one-off :Hide() is not enough. We hook Show/OnShow and hide them
-- again each time, but only while the option is enabled.
--
-- Toggle (Options > Module 3: Small Tweaks > "Hide Durability & Mount Seats"):
--   CXUI_DB.disableDurabilityMount
-- ===========================================================================

local function IsEnabled()
    return CXUI_DB and CXUI_DB.disableDurabilityMount
end

local FRAME_NAMES = { "DurabilityFrame", "VehicleSeatIndicator" }

local hooked = {} -- [frameName] = true once we've hooked that frame

local function HideFrame(frame)
    if IsEnabled() and frame and frame:IsShown() then
        frame:Hide()
    end
end

local function HookFrame(name)
    local frame = _G[name]
    if not frame or hooked[name] then return end
    hooked[name] = true

    -- Method calls like frame:Show() from Blizzard code.
    hooksecurefunc(frame, "Show", function(self)
        HideFrame(self)
    end)
    -- Covers SetShown(true) and anything else that ends up showing it.
    frame:HookScript("OnShow", function(self)
        HideFrame(self)
    end)
end

local function Apply()
    for _, name in ipairs(FRAME_NAMES) do
        HookFrame(name)
        HideFrame(_G[name])
    end
end

-- Called from the options checkbox. Turning the option ON hides right away;
-- turning it OFF asks Blizzard to re-evaluate the durability frame so it
-- comes back without a reload (the seat indicator returns the next time you
-- mount a multi-seat mount).
function ns.CXUI_DisableDurabilityMount_Refresh()
    if IsEnabled() then
        Apply()
        return
    end

    if DurabilityFrame_SetAlerts then
        DurabilityFrame_SetAlerts()
    elseif DurabilityFrame and DurabilityFrame.SetAlerts then
        DurabilityFrame:SetAlerts()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
f:RegisterEvent("UNIT_ENTERED_VEHICLE")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_ENTERED_VEHICLE" and unit ~= "player" then return end
    if event == "PLAYER_ENTERING_WORLD" then
        Apply()
        return
    end
    -- Frames may be shown by Blizzard's own handler right after this event,
    -- so re-check on the next frame as well.
    if IsEnabled() then
        Apply()
        C_Timer.After(0, Apply)
    end
end)
