local addonName, ns = ...

-- ===========================================================================
-- COMBAT: AUTO-RELEASE IN PVP
-- Releases your spirit in battlegrounds and supported world PvP zones unless
-- you can self-resurrect. Ported from EnhanceQoL (autoReleasePvP).
-- ===========================================================================

local M = ns:GetModule("Combat")

local F = M:NewFeature{
    key  = "autoReleasePvP",
    name = "Auto-Release in PvP",
    desc = "Automatically releases your spirit in battlegrounds and supported world PvP zones, unless you can self-resurrect.",
}

local AUTO_RELEASE_PVP_WORLD_MAPS = {
    [123] = true, -- Wintergrasp
    [244] = true, -- Tol Barad (PvP)
    [588] = true, -- Ashran
    [622] = true, -- Stormshield
    [624] = true, -- Warspear
}

local function HasUsableSelfResurrection()
    local deathInfo = _G.C_DeathInfo
    local options = deathInfo and deathInfo.GetSelfResurrectOptions and deathInfo.GetSelfResurrectOptions()
    if not options then return false end
    for _, option in ipairs(options) do
        if option and option.canUse then return true end
    end
    return false
end

local function ShouldRelease(mapID, inInstance, instanceType)
    if not F:IsOn() then return false end
    if HasUsableSelfResurrection() then return false end
    if inInstance and instanceType == "pvp" then return true end
    if mapID and AUTO_RELEASE_PVP_WORLD_MAPS[mapID] then return true end
    return false
end

local function CurrentMapID()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

local function ScheduleRelease(popup)
    if not popup or not popup.GetButton then return end
    local inInstance, instanceType = IsInInstance()
    if not ShouldRelease(CurrentMapID(), inInstance, instanceType) then return end

    RunNextFrame(function()
        if not popup:IsShown() or popup.which ~= "DEATH" then return end
        local inInstanceNow, instanceTypeNow = IsInInstance()
        if not ShouldRelease(CurrentMapID(), inInstanceNow, instanceTypeNow) then return end
        local button = popup:GetButton(1)
        if button then button:Click() end
    end)
end

function F:OnEnable()
    -- Hook all 4 default static popups: the death popup isn't guaranteed to be
    -- StaticPopup1 if another popup queued first.
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup then
            self:Hook(popup, "Show", function(p)
                if p and p.which == "DEATH" and (p.numButtons or 0) > 0 and p.GetButton then
                    ScheduleRelease(p)
                end
            end)
        end
    end
end
