local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: BLIGHTFALL SWAP (Unholy Death Knight)
-- SWAP_DELAY seconds after Dark Transformation is cast, the Dark
-- Transformation CDM icon switches to the Blightfall icon and gets a
-- standard-color proc glow. Both stay up until Blightfall is actually cast
-- (or combat ends / spec changes), there is no timeout-based revert.
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmBlightfallSwap",
    name  = "Blightfall Swap — Unholy DK",
    desc  = "Swaps the Dark Transformation CDM icon to Blightfall + glow, starting 13s after Dark Transformation is cast, until you cast Blightfall.",
    class = "DEATHKNIGHT",
}

local SPELL_DARK_TRANSFORMATION = 1233448
local SPELL_BLIGHTFALL          = 1271967 -- the ability itself; casting it consumes the proc
local SWAP_DELAY                = 12
local SWAP_DURATION 			= 5

local dtFrames       = {}
local overlays        = {}
local settingTexture  = {}
local swapActive      = false
local delayTimer      = nil

local function SwapWanted()
    return F:IsOn() and swapActive
end

-- Forces the Blightfall texture back onto the icon whenever CDM (or anything
-- else) tries to set its own texture while the swap window is active.
local function HookFrame(frame)
    if not frame.Icon then return end
    F:Hook(frame.Icon, "SetTexture", function(self)
        if settingTexture[self] then return end
        if not SwapWanted() then return end
        local blTex = C_Spell.GetSpellTexture(SPELL_BLIGHTFALL)
        if blTex then
            settingTexture[self] = true
            self:SetTexture(blTex)
            settingTexture[self] = false
        end
    end)
end

local function UpdateIcons()
    local dtTex = C_Spell.GetSpellTexture(SPELL_DARK_TRANSFORMATION)
    local blTex = C_Spell.GetSpellTexture(SPELL_BLIGHTFALL)
    for _, frame in ipairs(dtFrames) do
        if frame.Icon then
            settingTexture[frame.Icon] = true
            if swapActive and blTex then
                frame.Icon:SetTexture(blTex)
            elseif dtTex then
                frame.Icon:SetTexture(dtTex)
            end
            settingTexture[frame.Icon] = false
        end
    end
end

local function StopGlowAll()
    for _, ov in pairs(overlays) do CF.StopGlow(ov) end
end

local function StartGlowAll()
    for _, ov in pairs(overlays) do CF.StartGlow(ov) end
end

local function Stop()
    swapActive = false

    if delayTimer then
        delayTimer:Cancel()
        delayTimer = nil
    end

    StopGlowAll()
end

local function Show()
    swapActive = true
    UpdateIcons()
    StartGlowAll()

    delayTimer = F:NewTimer(SWAP_DURATION, function()
        delayTimer = nil
        Stop()
    end)
end

local function OnDarkTransformation()
    Stop()
    delayTimer = F:NewTimer(SWAP_DELAY, function()
        delayTimer = nil
        Show()
    end)
end

-- Rebuilds the frame/overlay lists (CDM icons get recreated / moved).
-- Rebuilding is bookkeeping, not a reason to hide anything: the visual
-- state is restored afterward.
local function Rescan()
    if not F:IsOn() then return end
    local wasActive = swapActive

    local dtTex = C_Spell.GetSpellTexture(SPELL_DARK_TRANSFORMATION)
    if dtTex then
        for _, frame in ipairs(dtFrames) do
            if frame.Icon then
                settingTexture[frame.Icon] = true
                frame.Icon:SetTexture(dtTex)
                settingTexture[frame.Icon] = false
            end
        end
    end
    for _, ov in pairs(overlays) do CF.StopGlow(ov); ov:Hide() end
    wipe(dtFrames); wipe(overlays); swapActive = false

    CF.ScanFramesBySpellID({ SPELL_DARK_TRANSFORMATION }, function(frame)
        table.insert(dtFrames, frame)
        HookFrame(frame)
        if not overlays[frame] then overlays[frame] = CF.CreateOverlay(frame) end
    end)

    UpdateIcons()
    if wasActive then
        swapActive = true
        StartGlowAll()
    end
end

CF.RegisterStatus(function()
    if not F:IsOn() then return nil end
    local n = 0
    for _ in pairs(overlays) do n = n + 1 end
    return ("blightfallswap=%s  frames=%d"):format(tostring(swapActive), n)
end)

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if spellID == SPELL_DARK_TRANSFORMATION then
                OnDarkTransformation()
            elseif spellID == SPELL_BLIGHTFALL then
                Stop() -- proc consumed: revert right away
            end
        else
            Stop() -- combat ended / spec changed
        end
    end)
    CF.AddRescan("blightfallswap", Rescan)
end

function F:OnDisable()
    CF.RemoveRescan("blightfallswap")
    delayTimer = nil -- cancelled by F:Silence()
    swapActive = false
    UpdateIcons() -- IsOn() is false now, so this restores the Dark Transformation icon
    for _, ov in pairs(overlays) do CF.StopGlow(ov) end
    wipe(dtFrames); wipe(overlays); wipe(settingTexture)
end