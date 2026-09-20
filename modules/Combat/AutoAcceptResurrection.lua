local addonName, ns = ...

-- ===========================================================================
-- COMBAT: AUTO-ACCEPT RESURRECTION
-- Accepts resurrection requests, but not while the resurrecting unit is in
-- combat. Ported from EnhanceQoL (autoAcceptResurrection).
-- ===========================================================================

local M = ns:GetModule("Combat")

local F = M:NewFeature{
    key  = "autoAcceptResurrection",
    name = "Auto-Accept Resurrection",
    desc = "Automatically accepts resurrection requests, but not while the resurrecting unit is in combat.",
}

local function ResolveOffererUnit(offerer)
    if issecretvalue and issecretvalue(offerer) then return nil end
    if not offerer or offerer == "" then return nil end
    if UnitExists(offerer) then return offerer end

    local function matches(unit)
        local name, realm = UnitName(unit)
        if not name then return false end
        if realm and realm ~= "" and offerer == (name .. "-" .. realm) then return true end
        return offerer == name
    end

    if matches("player") then return "player" end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if matches(unit) then return unit end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if matches(unit) then return unit end
        end
    end
    return nil
end

function F:OnEnable()
    local ev = self:NewEventFrame()
    ev:RegisterEvent("RESURRECT_REQUEST")
    ev:SetScript("OnEvent", function(_, _, offerer)
        local unit = ResolveOffererUnit(offerer)
        if unit and UnitAffectingCombat(unit) then return end
        AcceptResurrect()
        StaticPopup_Hide("RESURRECT")
        StaticPopup_Hide("RESURRECT_NO_SICKNESS")
        StaticPopup_Hide("RESURRECT_NO_TIMER")
    end)
end
