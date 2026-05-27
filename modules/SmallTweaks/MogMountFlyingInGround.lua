local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: MOGMOUNT — FLYING IN GROUND SLOT
-- MogMount.getSortedGroundMounts() reads MogMountSaved.ShowFlyingInGround
-- directly on every call, so syncing that field from CXUI_DB is enough —
-- no function patching needed.
-- ===========================================================================

local function Sync()
    if MogMountSaved then
        MogMountSaved.ShowFlyingInGround =
            CXUI_DB and CXUI_DB.mogMountFlyingInGround or false
    end
end

-- Sync when the cxUI options panel closes so any checkbox change takes effect
-- the next time the MogMount ground-slot panel is opened.
local function HookOptionsPanel()
    if CXUI_OptionsPanel then
        CXUI_OptionsPanel:HookScript("OnHide", Sync)
        return true
    end
    return false
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "MogMount" then
            -- MogMountSaved is already populated at this point
            Sync()
        end
        if addon == addonName then
            -- core.lua has already run, CXUI_OptionsPanel exists
            HookOptionsPanel()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Sync()
        HookOptionsPanel()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)