local addonName, ns = ...

-- ===========================================================================
-- CORE: namespace helpers, SavedVariables defaults, startup driver.
-- Registry / lifecycle: modules/Modules.lua.  Settings window: options.lua.
-- ===========================================================================

ns.addonName = addonName

-- Placeholder until WoW replaces it with the SavedVariables table
-- (that happens after the files run, right before ADDON_LOADED).
CXUI_DB = CXUI_DB or {}

local ADDON_PATH = "Interface\\AddOns\\" .. addonName .. "\\"

-- Path helper: ns.Media("CDMGlow", "glow-dash-h.tga")
function ns.Media(folder, file)
    return ADDON_PATH .. "media\\" .. folder .. "\\" .. file
end

function ns.Print(...)
    print("|cff0070ddcx|cffffff00UI|r:", ...)
end

-- Every default lives next to the feature/choice that owns the key.
function ns:InitDB()
    CXUI_DB = CXUI_DB or {}
    for _, f in ipairs(ns.featureList) do
        if CXUI_DB[f.key] == nil then CXUI_DB[f.key] = f.default end
    end
    for _, c in ipairs(ns.choiceList) do
        if CXUI_DB[c.key] == nil then CXUI_DB[c.key] = c.default end
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        ns:InitDB()
    else
        self:UnregisterEvent("PLAYER_LOGIN")
        ns:InitDB() -- safety net
        ns:ActivateFeatures()
    end
end)
