local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: MAGE (classID 8)
-- Features:
--   · Flurry Cross — red × on Flurry CDM when both procs are active.
-- ===========================================================================

local CF = ns.CF
if not CF or CF.CLASS_ID ~= 8 then return end

local ScanFramesByTexture = CF.ScanFramesByTexture
local CreateOverlay       = CF.CreateOverlay
local AttachXCross        = CF.AttachXCross
local ShowXCross          = CF.ShowXCross
local HideXCross          = CF.HideXCross

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local SPELL_FLURRY    = 44614
local SPELL_ICE_LANCE = 30455
local CROSS_DURATION  = 6

local DB_FLURRY = "cdmFlurryCross"

-- ---------------------------------------------------------------------------
-- FLURRY CROSS (cdmFlurryCross)
-- Red × on Flurry CDM when both procs (190446 & 1247729) are active.
-- Auto-hides after CROSS_DURATION seconds or when Ice Lance is cast.
-- ---------------------------------------------------------------------------

local flurryTexStr = nil
local function GetFlurryTexStr()
    if flurryTexStr then return flurryTexStr end
    local t = C_Spell.GetSpellTexture(SPELL_FLURRY)
    if t then flurryTexStr = tostring(t) end
    return flurryTexStr
end

local cdmFlurryOverlays = {}
local flurryCrossActive = false
local flurryTimer       = nil

local function CreateFlurryCDMOverlays()
    for _, ov in pairs(cdmFlurryOverlays) do ov:Hide() end
    wipe(cdmFlurryOverlays)
    flurryCrossActive = false
    local texStr = GetFlurryTexStr()
    if not texStr then return end
    ScanFramesByTexture({texStr}, function(frame)
        if not cdmFlurryOverlays[frame] then
            local ov = CreateOverlay(frame)
            AttachXCross(ov)
            cdmFlurryOverlays[frame] = ov
        end
    end)
end

local function HideFlurryCross()
    if flurryTimer then flurryTimer:Cancel(); flurryTimer = nil end
    flurryCrossActive = false
    for _, ov in pairs(cdmFlurryOverlays) do HideXCross(ov) end
end

local function ShowFlurryCross()
    if not CXUI_DB[DB_FLURRY] then return end
    if flurryTimer then flurryTimer:Cancel() end
    flurryCrossActive = true
    for _, ov in pairs(cdmFlurryOverlays) do ShowXCross(ov) end
    flurryTimer = C_Timer.NewTimer(CROSS_DURATION, function()
        flurryTimer = nil; HideFlurryCross()
    end)
end

local function StartMageRetryLoop()
    for _, delay in ipairs({3, 6, 10, 15}) do
        C_Timer.After(delay, function() CreateFlurryCDMOverlays() end)
    end
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local mageFrame = CreateFrame("Frame")
mageFrame:RegisterEvent("PLAYER_LOGIN")

mageFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, _, cid = UnitClass("player")
        if cid ~= 8 then self:UnregisterAllEvents(); return end
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        C_Timer.After(1, function() CreateFlurryCDMOverlays() end)
        StartMageRetryLoop()

    elseif event == "PLAYER_REGEN_ENABLED" then
        HideFlurryCross()

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() CreateFlurryCDMOverlays() end)
        StartMageRetryLoop()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        HideFlurryCross()
        C_Timer.After(2, function() CreateFlurryCDMOverlays() end)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == SPELL_FLURRY then
            ShowFlurryCross()
        elseif spellID == SPELL_ICE_LANCE then
            HideFlurryCross()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Debug commands
-- ---------------------------------------------------------------------------

SLASH_CXMAGEDEBUG1 = "/cxmage"
SlashCmdList["CXMAGEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" then
        CreateFlurryCDMOverlays()
        local n = 0; for _ in pairs(cdmFlurryOverlays) do n = n + 1 end
        print("|cff0070ddcxUI Mage:|r flurry_frames=" .. n
            .. "  active=" .. tostring(flurryCrossActive))
    elseif cmd == "force" then
        ShowFlurryCross()
        local n = 0; for _ in pairs(cdmFlurryOverlays) do n = n + 1 end
        print("|cff0070ddcxUI Mage:|r forced cross on " .. n .. " overlay(s)")
    else
        print("|cff0070ddcxUI Mage:|r /cxmage [scan|force]")
    end
end