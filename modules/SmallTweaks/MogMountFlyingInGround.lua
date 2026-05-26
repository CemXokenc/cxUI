local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: MOGMOUNT — FLYING IN GROUND SLOT
-- MogMount.getSortedGroundMounts() читає MogMountSaved.ShowFlyingInGround
-- напряму при кожному виклику, тому достатньо просто синхронізувати це
-- поле з нашим CXUI_DB.mogMountFlyingInGround — без патчу функцій.
-- ===========================================================================

local function Sync()
    if MogMountSaved then
        MogMountSaved.ShowFlyingInGround =
            CXUI_DB and CXUI_DB.mogMountFlyingInGround or false
    end
end

-- Синхронізуємо коли налаштування cxUI закриваються (зміна чекбоксу
-- вступить в силу при наступному відкритті панелі MogMount).
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
            -- MogMountSaved вже заповнена в цей момент
            Sync()
        end
        if addon == addonName then
            -- core.lua вже виконався, CXUI_OptionsPanel існує
            HookOptionsPanel()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Sync()
        HookOptionsPanel()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)