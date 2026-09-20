local addonName, ns = ...

-- ===========================================================================
-- CDM: SUPPRESS BLIZZARD GLOW
-- Hides Blizzard's own proc glow (SpellActivationAlert) on Cooldown Manager
-- icons, so only cxUI's glow shows. Action bars are unaffected.
-- ===========================================================================

local CDM = ns:GetModule("CDM")

local F = CDM:NewFeature{
    key     = "cdmGlowSuppressUntracked",
    name    = "Suppress Blizzard Glow on CDM",
    desc    = "Hides all Blizzard proc glows on CDM frames. Action bars unaffected.",
    default = false,
}

local IsSafeFrame      = CDM.IsSafeFrame
local GetButtonSpellID = CDM.GetButtonSpellID

-- Classes whose native Blizzard overlay always shows.
local SUPPRESS_EXEMPT_CLASSES = { MAGE = true }

local function IsInCDMViewer(frame)
    local f = frame
    for _ = 1, 10 do
        if not IsSafeFrame(f) then break end

        local ok, name = pcall(function() return f.GetName and f:GetName() end)
        if ok and name then
            for _, vname in ipairs(CDM.VIEWER_NAMES) do
                if name == vname then return true end
            end
        end

        local ok2, parent = pcall(function() return f:GetParent() end)
        if not ok2 or not parent then break end
        f = parent
    end
    return false
end

local function OnShowAlert(_, frame)
    if SUPPRESS_EXEMPT_CLASSES[ns.playerClass] then return end
    if not IsSafeFrame(frame) then return end

    local alert = frame.SpellActivationAlert
    if alert then alert:SetAlpha(0); alert:Hide() end

    local cdm = _G["Ayije_CDM"]
    if cdm and cdm.Glow and GetButtonSpellID(frame) and IsInCDMViewer(frame) then
        pcall(function() cdm.Glow:StopGlow(frame) end)
    end
end

local function TryHook()
    local mgr = _G.ActionButtonSpellAlertManager
    return mgr and mgr.ShowAlert and F:Hook(mgr, "ShowAlert", OnShowAlert)
end

function F:OnEnable()
    if TryHook() then return end
    -- Manager not available yet: retry on PLAYER_ENTERING_WORLD until it is.
    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(self2)
        if TryHook() then self2:UnregisterAllEvents() end
    end)
end
