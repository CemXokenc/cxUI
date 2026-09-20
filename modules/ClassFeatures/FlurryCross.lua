local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: FLURRY CROSS (Frost Mage)
-- Red X on the Flurry CDM icon after Flurry is cast. Hidden after
-- CROSS_DURATION seconds, when Ice Lance is cast, or when combat ends.
-- ===========================================================================

local CF = ns:GetModule("ClassFeatures")

local F = CF:NewFeature{
    key   = "cdmFlurryCross",
    name  = "Flurry Cross — Frost Mage",
    desc  = "Red x on Flurry CDM after Flurry is cast, until Ice Lance or 6s pass.",
    class = "MAGE",
}

local SPELL_FLURRY    = 44614
local SPELL_ICE_LANCE = 30455
local CROSS_DURATION  = 6

local overlays    = {}
local crossActive = false
local timer       = nil

local function Hide()
    if timer then timer:Cancel(); timer = nil end
    crossActive = false
    for _, ov in pairs(overlays) do CF.HideXCross(ov) end
end

local function Show()
    if timer then timer:Cancel() end
    crossActive = true
    for _, ov in pairs(overlays) do CF.ShowXCross(ov) end
    timer = F:NewTimer(CROSS_DURATION, function()
        timer = nil; Hide()
    end)
end

local function Rescan()
    if not F:IsOn() then return end
    for _, ov in pairs(overlays) do ov:Hide() end
    wipe(overlays)
    crossActive = false
    CF.ScanFramesBySpellID({ SPELL_FLURRY }, function(frame)
        if not overlays[frame] then
            local ov = CF.CreateOverlay(frame)
            CF.AttachXCross(ov)
            overlays[frame] = ov
        end
    end)
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if spellID == SPELL_FLURRY then Show()
            elseif spellID == SPELL_ICE_LANCE then Hide() end
        else
            Hide()
        end
    end)
    CF.AddRescan("flurry", Rescan)
end

function F:OnDisable()
    CF.RemoveRescan("flurry")
    timer = nil -- cancelled by F:Silence()
    crossActive = false
    for _, ov in pairs(overlays) do CF.HideXCross(ov) end
    wipe(overlays)
end

-- Debug: /cxmage scan | force
SLASH_CXMAGEDEBUG1 = "/cxmage"
SlashCmdList["CXMAGEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if not F:IsOn() then ns.Print("Mage: Flurry Cross is off"); return end
    if cmd == "scan" then
        Rescan()
        local n = 0; for _ in pairs(overlays) do n = n + 1 end
        ns.Print("Mage: flurry_frames=" .. n .. "  active=" .. tostring(crossActive))
    elseif cmd == "force" then
        Show()
        local n = 0; for _ in pairs(overlays) do n = n + 1 end
        ns.Print("Mage: forced cross on " .. n .. " overlay(s)")
    else
        ns.Print("Mage: /cxmage [scan|force]")
    end
end
