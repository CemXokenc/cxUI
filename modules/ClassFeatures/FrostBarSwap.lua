local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: FROST BAR SWAP (Frost Death Knight)
-- Swaps the Obliterate icon to Frostscythe on the CDM while action bar page 2
-- is active (single-target / AoE bar swap).
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmFrostBarSwap",
    name  = "Swap ST/AOE — Frost DK",
    desc  = "Swaps Obliterate/Frostscythe icons on the CDM when the action bar page changes.",
    class = "DEATHKNIGHT",
}

local SPELL_OBLITERATE  = 49020
local SPELL_FROSTSCYTHE = 207230

local oblFrames = {}
local settingTexture = {}

local function SwapWanted()
    return F:IsOn() and GetSpecialization() == 2 and GetActionBarPage() == 2
end

local function HookFrame(frame)
    F:Hook(frame.Icon, "SetTexture", function(self)
        if settingTexture[self] then return end
        if not SwapWanted() then return end
        local scyTex = C_Spell.GetSpellTexture(SPELL_FROSTSCYTHE)
        if scyTex then
            settingTexture[self] = true
            self:SetTexture(scyTex)
            settingTexture[self] = false
        end
    end)
end

local function UpdateSwap()
    local oblTex = C_Spell.GetSpellTexture(SPELL_OBLITERATE)
    local scyTex = C_Spell.GetSpellTexture(SPELL_FROSTSCYTHE)
    local swapOn = SwapWanted()
    for _, frame in ipairs(oblFrames) do
        if frame.Icon then
            settingTexture[frame.Icon] = true
            if swapOn and scyTex then
                frame.Icon:SetTexture(scyTex)
            elseif oblTex then
                frame.Icon:SetTexture(oblTex)
            end
            settingTexture[frame.Icon] = false
        end
    end
end

local function Rescan()
    if not F:IsOn() then return end
    local oblTex = C_Spell.GetSpellTexture(SPELL_OBLITERATE)
    if oblTex then
        for _, frame in ipairs(oblFrames) do
            if frame.Icon then frame.Icon:SetTexture(oblTex) end
        end
    end
    wipe(oblFrames)
    CF.ScanFramesBySpellID({ SPELL_OBLITERATE }, function(frame)
        if frame.Icon then
            table.insert(oblFrames, frame)
            HookFrame(frame)
        end
    end)
    UpdateSwap()
end

CF.RegisterStatus(function()
    if not F:IsOn() then return nil end
    return ("frostswap frames=%d"):format(#oblFrames)
end)

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    ev:SetScript("OnEvent", function() F:After(0.05, Rescan) end)
    CF.AddRescan("frostswap", Rescan)
end

function F:OnDisable()
    CF.RemoveRescan("frostswap")
    UpdateSwap() -- IsOn() is false now, so this restores the Obliterate icon
    wipe(oblFrames)
end
