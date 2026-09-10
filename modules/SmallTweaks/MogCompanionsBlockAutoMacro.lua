local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: MOGCOMPANIONS — BLOCK AUTO-MACRO CREATION
--
-- MogCompanions can (re)generate its own "MogComp Mount" / "MogComp Hearth"
-- macros (Settings -> "Create Mount/Hearthstone Macro", or automatically if
-- it doesn't find a macro with that exact name). MegaMacro scans and adopts
-- every native macro it finds, which can make MogCompanions think its macro
-- is "missing" and spawn a new one -> duplicates pile up over time.
--
-- MogCompanions' own auto macro isn't needed: the #showtooltip line it
-- builds (conditions like [flyable,nomod:ctrl]...) is purely cosmetic - it
-- only controls the tooltip/icon on the action button. The real logic runs
-- when the slash command fires:
--   /mcomp mount            -> MogCompanionsSummon() reads live modifier
--                              keys, IsSwimming(), IsFlyableArea(), etc.
--                              directly - never the macro's conditional text.
--   /click MCHearthButton   -> routes through MCHearthButton's own PreClick
--                              handler, also unrelated to macro text.
-- Two plain, hand-made macros ("/mcomp mount" and "/click MCHearthButton")
-- are a fully sufficient replacement, so we just stop MogCompanions from
-- ever (re)creating its managed macros.
--
-- Toggleable via CXUI_DB.mogCompanionsBlockAutoMacro so it can be turned
-- off if a future MogCompanions update changes this behavior.
-- ===========================================================================

local originalCreateMountMacro, originalCreateHearthstoneMacro
local hooked = false

local function CaptureOriginals()
    if hooked or not MogCompanions then
        return
    end
    originalCreateMountMacro = MogCompanions.CreateMountMacro
    originalCreateHearthstoneMacro = MogCompanions.CreateHearthstoneMacro
    hooked = true
end

local function Sync()
    if not hooked then
        return
    end

    local blockEnabled = CXUI_DB and CXUI_DB.mogCompanionsBlockAutoMacro

    if blockEnabled then
        MogCompanions.CreateMountMacro = function() end
        MogCompanions.CreateHearthstoneMacro = function() end
    else
        MogCompanions.CreateMountMacro = originalCreateMountMacro
        MogCompanions.CreateHearthstoneMacro = originalCreateHearthstoneMacro
    end
end

-- Sync when the cxUI options panel closes so a checkbox change takes effect
-- immediately, without needing a reload.
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
        if addon == "MogCompanions" then
            CaptureOriginals()
            Sync()
        end
        if addon == addonName then
            HookOptionsPanel()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Covers cxUI loading before MogCompanions, or either loading before
        -- CXUI_DB defaults are populated.
        CaptureOriginals()
        Sync()
        HookOptionsPanel()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
