local addonName, ns = ...

-- ===========================================================================
-- INTERFACE: HIDE DURABILITY & MOUNT SEATS
-- Hides two Blizzard indicators near the minimap / objective tracker:
--   * DurabilityFrame       the little armor "man" with yellow/red pieces
--   * VehicleSeatIndicator  the seat icon on mounts/vehicles with passengers
-- Blizzard re-shows both whenever durability changes or you mount, so the
-- frames' Show/OnShow are hooked (only while the option is on).
-- ===========================================================================

local I = ns:GetModule("Interface")

local F = I:NewFeature{
    key  = "disableDurabilityMount",
    name = "Hide Durability & Mount Seats",
    desc = "Hides the durability figure and the seat indicator shown on mounts that can carry passengers.",
    info = "Hides Blizzard's durability frame (the armor figure with yellow/red pieces) and the seat indicator shown on mounts that can carry passengers.",
}

local FRAME_NAMES = { "DurabilityFrame", "VehicleSeatIndicator" }

local function HideFrame(frame)
    if frame and frame:IsShown() then frame:Hide() end
end

local function Apply()
    if not F:IsOn() then return end
    for _, name in ipairs(FRAME_NAMES) do
        local frame = _G[name]
        if frame then
            F:Hook(frame, "Show", HideFrame)   -- Show() calls from Blizzard code
            F:HookScript(frame, "OnShow", HideFrame) -- SetShown(true) and friends
            HideFrame(frame)
        end
    end
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    ev:RegisterEvent("UNIT_ENTERED_VEHICLE")
    ev:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_ENTERED_VEHICLE" and unit ~= "player" then return end
        Apply()
        if event ~= "PLAYER_ENTERING_WORLD" then
            -- Blizzard may show the frames right after this event: re-check next frame
            F:After(0, Apply)
        end
    end)
    Apply()
end

function F:OnDisable()
    -- Ask Blizzard to re-evaluate the durability frame so it comes back without
    -- a reload (the seat indicator returns the next time you mount).
    if DurabilityFrame_SetAlerts then
        DurabilityFrame_SetAlerts()
    elseif DurabilityFrame and DurabilityFrame.SetAlerts then
        DurabilityFrame:SetAlerts()
    end
end
