local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: DEATH & RESURRECTION
-- Ported from EnhanceQoL (autoAcceptResurrection / autoReleasePvP).
-- Each feature is fully inert unless its own checkbox is enabled.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Feature 1: Automatically accept resurrection (but not in combat)
-- ---------------------------------------------------------------------------

local function resolveResurrectOffererUnit(offerer)
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

local function shouldAutoAcceptResurrection(offerer)
    if not CXUI_DB.autoAcceptResurrection then return false end
    local unit = resolveResurrectOffererUnit(offerer)
    -- "but not in combat" — don't auto-accept while the resurrecting unit is in combat.
    if unit and UnitAffectingCombat(unit) then return false end
    return true
end

local resurrectFrame = CreateFrame("Frame")
resurrectFrame:RegisterEvent("RESURRECT_REQUEST")
resurrectFrame:SetScript("OnEvent", function(self, event, offerer)
    if not shouldAutoAcceptResurrection(offerer) then return end
    AcceptResurrect()
    StaticPopup_Hide("RESURRECT")
    StaticPopup_Hide("RESURRECT_NO_SICKNESS")
    StaticPopup_Hide("RESURRECT_NO_TIMER")
end)

-- ---------------------------------------------------------------------------
-- Feature 2: Auto-release in PvP
-- ---------------------------------------------------------------------------

local AUTO_RELEASE_PVP_WORLD_MAPS = {
    [123] = true, -- Wintergrasp
    [244] = true, -- Tol Barad (PvP)
    [588] = true, -- Ashran
    [622] = true, -- Stormshield
    [624] = true, -- Warspear
}

local function hasUsableSelfResurrection()
    local deathInfo = _G.C_DeathInfo
    local options = deathInfo and deathInfo.GetSelfResurrectOptions and deathInfo.GetSelfResurrectOptions()
    if not options then return false end
    for _, option in ipairs(options) do
        if option and option.canUse then return true end
    end
    return false
end

local function shouldAutoReleasePvP(mapID, inInstance, instanceType)
    if not CXUI_DB.autoReleasePvP then return false end
    if hasUsableSelfResurrection() then return false end
    if inInstance and instanceType == "pvp" then return true end
    if mapID and AUTO_RELEASE_PVP_WORLD_MAPS[mapID] then return true end
    return false
end

local function scheduleAutoReleasePvP(popup)
    if not popup or not popup.GetButton then return end
    if not CXUI_DB.autoReleasePvP then return end

    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local inInstance, instanceType = IsInInstance()
    if not shouldAutoReleasePvP(mapID, inInstance, instanceType) then return end

    local function tryRelease()
        if not popup:IsShown() or popup.which ~= "DEATH" then return end
        local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local inInstanceNow, instanceTypeNow = IsInInstance()
        if not shouldAutoReleasePvP(currentMapID, inInstanceNow, instanceTypeNow) then return end
        local button = popup:GetButton(1)
        if button then button:Click() end
    end

    RunNextFrame(tryRelease)
end

-- Hook all 4 default static popups — mirrors Blizzard's own indexing, since
-- the death popup isn't guaranteed to be StaticPopup1 if another popup queued first.
for i = 1, 4 do
    local popup = _G["StaticPopup" .. i]
    if popup then
        hooksecurefunc(popup, "Show", function(self)
            if not self then return end
            if not CXUI_DB.autoReleasePvP then return end
            local isDeathPopup = (self.which == "DEATH") and (self.numButtons or 0) > 0 and self.GetButton
            if isDeathPopup then scheduleAutoReleasePvP(self) end
        end)
    end
end
