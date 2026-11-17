local addonName, ns = ...
local M = ns.Macros
local mod = ns:GetModule("Macros")

-- ===========================================================================
-- FEATURE: MACRO MANAGER
-- Keeps the native macro slots in sync with the macros stored in CXUI_MacroDB
-- (see Slots.lua). Browsing / editing works even when the feature is off, but
-- nothing is written to the game's macro slots then.
-- ===========================================================================

local F = mod:NewFeature{
    key  = "macroManager",
    name = "Macro Manager",
    desc = "General / class / spec / character macros, swapped into your macro slots when you change spec.",
    info = "Open the window with /cxm. Needs Mega Macro to be disabled (use /cxm import once to copy its macros).",
}

-- Why macros are not being applied right now (nil = all good).
function M.ManagingReason()
    if not F:IsOn() then
        return "Macro Manager is OFF - macros are not written to your macro slots"
    end
    if M.IsAddOnLoaded("MegaMacro") then
        return "Mega Macro is loaded - disable it so cxUI can manage macros"
    end
    return nil
end

function M.IsManaging() return M.ManagingReason() == nil end

local hinted = false
local function Hint()
    if hinted then return end
    hinted = true
    if M.IsAddOnLoaded("MegaMacro") then
        ns.Print("Macros: Mega Macro is still loaded, so cxUI is idle. |cffffff00/cxm import|r copies its macros; " ..
            "then disable Mega Macro and reload.")
    elseif M.CountRecords() == 0 and M.CountUntagged() > 0 then
        ns.Print("Macros: found native macros that cxUI does not manage yet. " ..
            "Open |cffffff00/cxm|r and press |cffffff00Adopt native|r.")
    end
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            self:After(1, function() M.Slots.Sync(false); Hint() end)
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            if unit == "player" then self:After(0.3, function() M.Slots.Sync(true) end) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if M.Slots.HasPending() then self:After(0.5, function() M.Slots.Sync(true) end) end
        end
    end)
    -- turned on in the middle of a session
    if IsLoggedIn() then self:After(0.5, function() M.Slots.Sync(false) end) end
end

function F:OnDisable()
    M.NotifyChanged()
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_CXUIMACROS1 = "/cxm"
SLASH_CXUIMACROS2 = "/m"
SlashCmdList["CXUIMACROS"] = function(msg)
    local cmd = (msg or ""):match("^%s*(%S*)"):lower()
    if cmd == "" then
        M.Window.Toggle()
    elseif cmd == "import" then
        M.ImportMegaMacro()
    elseif cmd == "adopt" then
        M.AdoptNative()
    elseif cmd == "plain" then
        local plain = M.Window.TogglePlain()
        ns.Print("Macro editor: " .. (plain and "plain text (no colouring)" or "coloured") .. ".")
    elseif cmd == "sync" then
        if M.IsManaging() then M.Slots.Sync(true); ns.Print("Macros synced.")
        else ns.Print(M.ManagingReason()) end
    elseif cmd == "release" then
        local n = M.Slots.Release()
        ns.Print(n and ("Removed the cxUI tag from %d native macro(s). Turn Macro Manager off before reloading."):format(n)
                   or "Not in combat, please.")
    else
        ns.Print("/cxm  open the window  |  import  copy Mega Macro data  |  adopt  take over native macros  |  " ..
            "sync  rewrite slots  |  release  strip cxUI tags  |  plain  toggle the plain-text editor")
    end
end
