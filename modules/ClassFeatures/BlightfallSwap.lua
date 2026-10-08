local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: BLIGHTFALL SWAP (Unholy Death Knight)
-- Goal: press Blightfall in the last moment while every buff is still up:
--   * Dark Transformation (+ trinket): DT cast + DT_DURATION
--   * Soul Reaper buff:               Soul Reaper cast + REAPER_BUFF_DURATION
-- Deadline = earliest of those. LEAD seconds before the deadline the Dark
-- Transformation CDM icon switches to the Blightfall icon + glow, and stays
-- until Blightfall is cast or the deadline passes (or combat ends / spec or
-- talents change).
-- If Soul Reaper is never cast, the deadline is simply DT cast + DT_DURATION.
-- Requires the Blightfall talent (TALENT_BLIGHTFALL) to be learned.
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmBlightfallSwap",
    name  = "Blightfall Swap — Unholy DK",
    desc  = "Swaps the Dark Transformation CDM icon to Blightfall + glow shortly before the earliest of DT / Soul Reaper buff ends, until you cast Blightfall.",
    class = "DEATHKNIGHT",
}

local SPELL_DARK_TRANSFORMATION = 1233448
local SPELL_SOUL_REAPER         = 343294
local SPELL_BLIGHTFALL          = 1271967 -- the ability itself; casting it consumes the proc
local TALENT_BLIGHTFALL         = 1271974 -- talent required for the swap

local DT_DURATION          = 15 -- DT / trinket minimum duration
local REAPER_BUFF_DURATION = 8  -- Soul Reaper buff duration
local LEAD                 = 3  -- how long before the deadline the swap shows
local EPSILON              = 0.05

local dtFrames       = {}
local overlays       = {}
local settingTexture = {}
local swapActive     = false
local showTimer      = nil
local hideTimer      = nil
local dtEnd          = nil -- GetTime() when DT/trinket end
local reaperEnd      = nil -- GetTime() when the Reaper buff ends

local function HasTalent()
    return IsPlayerSpell(TALENT_BLIGHTFALL)
end

local function SwapWanted()
    return F:IsOn() and swapActive and HasTalent()
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

local function CancelTimers()
    if showTimer then showTimer:Cancel(); showTimer = nil end
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
end

-- Full reset: cancels timers, forgets the sequence, restores the DT icon.
local function Stop()
    swapActive = false
    dtEnd, reaperEnd = nil, nil
    CancelTimers()
    StopGlowAll()
    UpdateIcons()
end

-- Shows the swap now and schedules its end after `remaining` seconds.
local function Show(remaining)
    -- Safety net: the talent could have been removed in the meantime.
    if not HasTalent() then
        Stop()
        return
    end

    if not swapActive then
        swapActive = true
        UpdateIcons()
        StartGlowAll()
    end

    if hideTimer then hideTimer:Cancel() end
    hideTimer = F:NewTimer(remaining, function()
        hideTimer = nil
        Stop()
    end)
end

-- Recomputes the deadline and (re)schedules the show/hide timers. Called after
-- Dark Transformation and after every Soul Reaper cast.
local function Schedule()
    CancelTimers()
    if not dtEnd then return end

    local now      = GetTime()
    local deadline = dtEnd
    if reaperEnd and reaperEnd < deadline then deadline = reaperEnd end
    local showAt   = deadline - LEAD

    if now >= deadline - EPSILON then
        Stop() -- window already over
    elseif now >= showAt - EPSILON then
        Show(deadline - now)
    else
        showTimer = F:NewTimer(showAt - now, function()
            showTimer = nil
            Schedule() -- now inside the window -> Show()
        end)
    end
end

local function OnDarkTransformation()
    Stop()
    if not HasTalent() then return end
    dtEnd = GetTime() + DT_DURATION
    Schedule()
end

local function OnSoulReaper()
    if not dtEnd or GetTime() >= dtEnd then return end -- only inside a DT window
    reaperEnd = GetTime() + REAPER_BUFF_DURATION
    Schedule()
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
    if wasActive and HasTalent() then
        swapActive = true
        UpdateIcons()
        StartGlowAll()
    end
end

CF.RegisterStatus(function()
    if not F:IsOn() then return nil end
    local n = 0
    for _ in pairs(overlays) do n = n + 1 end
    local now = GetTime()
    local dtLeft     = dtEnd     and ("%.1f"):format(dtEnd - now)     or "-"
    local reaperLeft = reaperEnd and ("%.1f"):format(reaperEnd - now) or "-"
    return ("blightfallswap=%s  talent=%s  dtLeft=%s  reaperLeft=%s  frames=%d"):format(
        tostring(swapActive), tostring(HasTalent() and true or false), dtLeft, reaperLeft, n)
end)

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if spellID == SPELL_DARK_TRANSFORMATION then
                OnDarkTransformation()
            elseif spellID == SPELL_SOUL_REAPER then
                OnSoulReaper()
            elseif spellID == SPELL_BLIGHTFALL then
                Stop() -- proc consumed: revert right away
            end
        elseif event == "TRAIT_CONFIG_UPDATED" then
            if not HasTalent() then Stop() end -- talent removed mid-window
        else
            Stop() -- combat ended / spec changed
        end
    end)
    CF.AddRescan("blightfallswap", Rescan)
end

function F:OnDisable()
    CF.RemoveRescan("blightfallswap")
    showTimer, hideTimer = nil, nil -- cancelled by F:Silence()
    dtEnd, reaperEnd = nil, nil
    swapActive = false
    UpdateIcons() -- IsOn() is false now, so this restores the Dark Transformation icon
    for _, ov in pairs(overlays) do CF.StopGlow(ov) end
    wipe(dtFrames); wipe(overlays); wipe(settingTexture)
end