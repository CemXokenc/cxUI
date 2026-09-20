local addonName, ns = ...

-- ===========================================================================
-- GROUP FINDER: DUNGEON FINDER ADVANCED FILTERS
-- Adds party-fit, Bloodlust / Battle Res and same-spec filters to the Dungeon
-- Finder search list. Ported from EnhanceQoL (mythicPlusEnableDungeonFilter).
-- Requires a reload: Blizzard's Menu.ModifyMenu / hooks can't be removed. The
-- callbacks below all return immediately while the option is off.
-- ===========================================================================

local GF = ns:GetModule("GroupFinder")

local F = GF:NewFeature{
    key    = "dungeonFilter",
    name   = "Dungeon Finder: Advanced Filters",
    desc   = "Adds party-fit, Bloodlust/Battle Res and same-spec filters to the Dungeon Finder search list.",
    reload = true,
}

local isRestrictedContent = GF.IsRestrictedContent

-- ---------------------------------------------------------------------------
-- Track player class/spec/role - needed by the filter logic
-- ---------------------------------------------------------------------------

local LUST_CLASSES = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
local BR_CLASSES = { DRUID = true, WARLOCK = true, DEATHKNIGHT = true, PALADIN = true }

local playerClass = select(2, UnitClass("player"))
local playerIsLust = playerClass and LUST_CLASSES[playerClass] or false
local playerIsBR = playerClass and BR_CLASSES[playerClass] or false
local playerSpecName, playerRole

local function RefreshPlayerSpec()
    local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization()
    if specIndex then
        local _, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
        playerSpecName = specName
        playerRole = GetSpecializationRole(specIndex)
    end
end

-- ---------------------------------------------------------------------------
-- Feature 1: Add advanced filters to the Dungeon Finder
-- ---------------------------------------------------------------------------

local pDb -- per-character filter state, CXUI_DB.dungeonFilterData[guid]

local function ensureDungeonFilterDB()
    CXUI_DB.dungeonFilterData = CXUI_DB.dungeonFilterData or {}
    local guid = UnitGUID("player")
    if guid then
        if CXUI_DB.dungeonFilterData[guid] == nil then CXUI_DB.dungeonFilterData[guid] = {} end
        pDb = CXUI_DB.dungeonFilterData[guid]
    end
end

local RefreshVisibleEntries

local function AnyFilterActive()
    if not pDb then return false end
    if pDb["partyFit"] then return true end
    if pDb["NoSameSpec"] and playerRole == "DAMAGER" then return true end
    if (not playerIsLust and pDb["bloodlustAvailable"]) or (playerIsLust and pDb["NoBloodlust"]) then return true end
    if not playerIsBR and pDb["battleResAvailable"] then return true end
    return false
end

local function EQOL_AddLFGEntries(owner, root, ctx)
    if not F:IsOn() then return end
    if not pDb then return end
    local panel = LFGListFrame.SearchPanel
    if panel.categoryID ~= 2 then return end

    root:CreateTitle("")
    root:CreateTitle("cxUI")
    root:CreateCheckbox("Party fits", function() return pDb["partyFit"] end, function()
        pDb["partyFit"] = not pDb["partyFit"]
        RefreshVisibleEntries()
    end)
    if not playerIsLust then
        root:CreateCheckbox("Bloodlust available", function() return pDb["bloodlustAvailable"] end, function()
            pDb["bloodlustAvailable"] = not pDb["bloodlustAvailable"]
            RefreshVisibleEntries()
        end)
    end
    if playerIsLust then
        root:CreateCheckbox("No Bloodlust in Group", function() return pDb["NoBloodlust"] end, function()
            pDb["NoBloodlust"] = not pDb["NoBloodlust"]
            RefreshVisibleEntries()
        end)
    end
    if not playerIsBR then
        root:CreateCheckbox("Battle Res available", function() return pDb["battleResAvailable"] end, function()
            pDb["battleResAvailable"] = not pDb["battleResAvailable"]
            RefreshVisibleEntries()
        end)
    end
    if playerRole == "DAMAGER" then
        root:CreateCheckbox(("No %s in Group"):format((playerSpecName or "") .. " " .. (playerClass or "")), function() return pDb["NoSameSpec"] end, function()
            pDb["NoSameSpec"] = not pDb["NoSameSpec"]
            RefreshVisibleEntries()
        end)
    end
end

local function EntryPassesFilter(info)
    if info.numMembers == 5 then return false end

    local partyHasLust, partyHasBR = false, false
    for i = 1, GetNumGroupMembers() do
        local unit = (i == 1) and "player" or ("party" .. (i - 1))
        local _, class = UnitClass(unit)
        if class and LUST_CLASSES[class] then partyHasLust = true end
        if class and BR_CLASSES[class] then partyHasBR = true end
    end

    local NEED_SAMESPEC = (playerRole == "DAMAGER") and pDb["NoSameSpec"] or false
    local NEED_LUST = (pDb["bloodlustAvailable"] and not partyHasLust) or pDb["NoBloodlust"]
    local NEED_BR = pDb["battleResAvailable"] and not partyHasBR
    local NEED_ROLES = pDb["partyFit"]

    local groupTankCount, groupHealerCount, groupDPSCount = 0, 0, 0
    local hasLust, hasBR, hasSameSpec = false, false, false
    if NEED_SAMESPEC or NEED_LUST or NEED_BR or NEED_ROLES then
        for i = 1, info.numMembers do
            local m = C_LFGList.GetSearchResultPlayerInfo(info.searchResultID, i)
            if m then
                if NEED_ROLES and m.assignedRole then
                    if m.assignedRole == "TANK" then
                        groupTankCount = groupTankCount + 1
                    elseif m.assignedRole == "HEALER" then
                        groupHealerCount = groupHealerCount + 1
                    elseif m.assignedRole == "DAMAGER" then
                        groupDPSCount = groupDPSCount + 1
                    end
                end
                if (NEED_LUST or NEED_BR) and m.classFilename then
                    if NEED_LUST and LUST_CLASSES[m.classFilename] then hasLust = true end
                    if NEED_BR and BR_CLASSES[m.classFilename] then hasBR = true end
                end
                if NEED_SAMESPEC and m.classFilename == playerClass and m.specName == playerSpecName then hasSameSpec = true end
            end
        end
    end

    if NEED_SAMESPEC and hasSameSpec then return false end
    if pDb["NoBloodlust"] and hasLust then return false end

    if NEED_ROLES then
        local needTanks, needHealers, needDPS = 0, 0, 0
        local partySize = GetNumGroupMembers()
        if partySize > 1 then
            for i = 1, partySize do
                local unit = (i == 1) and "player" or ("party" .. (i - 1))
                local role = UnitGroupRolesAssigned(unit)
                if role == "TANK" then
                    needTanks = needTanks + 1
                elseif role == "HEALER" then
                    needHealers = needHealers + 1
                elseif role == "DAMAGER" then
                    needDPS = needDPS + 1
                end
            end
        else
            if playerRole == "TANK" then
                needTanks = needTanks + 1
            elseif playerRole == "HEALER" then
                needHealers = needHealers + 1
            elseif playerRole == "DAMAGER" then
                needDPS = needDPS + 1
            end
        end

        if needTanks > 1 or needHealers > 1 or needDPS > 3 then return false end
        if (1 - groupTankCount) < needTanks then return false end
        if (1 - groupHealerCount) < needHealers then return false end
        if (3 - groupDPSCount) < needDPS then return false end
        local freeSlots = 5 - info.numMembers
        if freeSlots < GetNumGroupMembers() then return false end
    end

    local missingProviders = 0
    if pDb["bloodlustAvailable"] then
        if not hasLust and not partyHasLust then
            if groupTankCount == 0 then missingProviders = missingProviders + 1 end
            missingProviders = missingProviders + 1
        end
    end
    if pDb["battleResAvailable"] then
        if not hasBR and not partyHasBR then missingProviders = missingProviders + 1 end
    end

    local slotsAfterJoin = 5 - info.numMembers - 1
    if slotsAfterJoin < missingProviders then return false end
    return true
end

local function EQOL_SetTextGrey(widget, grey)
    if not widget or not widget.SetTextColor then return end
    if not widget._cxuiOrigColor then
        local r, g, b, a = 1, 1, 1, 1
        if widget.GetTextColor then r, g, b, a = widget:GetTextColor() end
        widget._cxuiOrigColor = { r, g, b, a }
    end
    if grey then
        widget:SetTextColor(0.6, 0.6, 0.6, 1)
    else
        local c = widget._cxuiOrigColor
        if c then widget:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
    end
end

local function EQOL_RestoreEntryVisuals(entry)
    if entry._cxuiOrigAlpha then entry:SetAlpha(entry._cxuiOrigAlpha) end
    local labels = { "Name", "ActivityName", "Members", "Comment", "VoiceChat", "LeaderName", "ListingName" }
    for _, k in ipairs(labels) do
        local w = entry[k]
        if w and w._cxuiOrigColor then EQOL_SetTextGrey(w, false) end
    end
end

local function EQOL_ApplyEntryVisuals(entry, dim)
    if not entry._cxuiOrigAlpha then entry._cxuiOrigAlpha = entry:GetAlpha() or 1 end
    entry:SetAlpha(dim and 0.45 or entry._cxuiOrigAlpha)
    local labels = { "Name", "ActivityName", "Members", "Comment", "VoiceChat", "LeaderName", "ListingName" }
    for _, k in ipairs(labels) do
        EQOL_SetTextGrey(entry[k], dim)
    end
end

local function EQOL_HighlightSearchEntry(entry)
    if not F:IsOn() then return end
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel or panel.categoryID ~= 2 then return end

    local resultID = entry and (entry.resultID or entry.id or entry.searchResultID)
    if not resultID then
        EQOL_RestoreEntryVisuals(entry)
        return
    end

    local info = C_LFGList.GetSearchResultInfo(resultID)

    if not AnyFilterActive() then
        EQOL_RestoreEntryVisuals(entry)
        return
    end

    local selectedID = (type(LFGListSearchPanel_GetSelectedResult) == "function" and LFGListSearchPanel_GetSelectedResult(panel)) or panel.selectedResultID or panel.selectedResult
    if selectedID and selectedID == resultID then
        EQOL_RestoreEntryVisuals(entry)
        return
    end

    local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
    if (appStatus and appStatus ~= "none") or pendingStatus then
        EQOL_RestoreEntryVisuals(entry)
        return
    end

    local pass = info and EntryPassesFilter(info)
    EQOL_ApplyEntryVisuals(entry, pass == false)
end

local function FilterResults(panel)
    if not F:IsOn() then return end
    if not panel or panel.categoryID ~= 2 then return end
    if not pDb then return end

    local baseResults = panel.results or select(2, C_LFGList.GetSearchResults())
    if not baseResults or #baseResults == 0 then return end
    if not AnyFilterActive() then return end

    local selectedID = (type(LFGListSearchPanel_GetSelectedResult) == "function" and LFGListSearchPanel_GetSelectedResult(panel)) or panel.selectedResultID or panel.selectedResult

    local filtered = {}
    for _, resultID in ipairs(baseResults) do
        local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
        local isApplied = (appStatus and appStatus ~= "none") or pendingStatus

        if (selectedID and resultID == selectedID) or isApplied then
            table.insert(filtered, resultID)
        else
            local info = C_LFGList.GetSearchResultInfo(resultID)
            if info and EntryPassesFilter(info) then table.insert(filtered, resultID) end
        end
    end

    panel.results = filtered
    panel.totalResults = #filtered

    LFGListSearchPanel_UpdateResults(panel)
end

RefreshVisibleEntries = function()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if panel and type(LFGListSearchPanel_UpdateResultList) == "function" then LFGListSearchPanel_UpdateResultList(panel) end
end

local menuModified = false
local hooksInstalled  = false
local initialized     = false

local function InitDungeonFilter()
    if initialized then return end
    if not F:IsOn() then return end
    if not (LFGListFrame and LFGListFrame.SearchPanel) then return end
    initialized = true

    ensureDungeonFilterDB()
    RefreshPlayerSpec()

    if not menuModified and Menu and Menu.ModifyMenu then
        menuModified = true
        Menu.ModifyMenu("MENU_LFG_FRAME_SEARCH_FILTER", EQOL_AddLFGEntries)
    end

    if not hooksInstalled then
        hooksInstalled = true
        F:Hook("LFGListSearchPanel_UpdateResultList", FilterResults)
        F:Hook("LFGListSearchEntry_Update", EQOL_HighlightSearchEntry)
    end

    -- Clear the extended filters whenever Blizzard's own Reset Filter button is used.
    local resetButton = GF.GetResetButton()
    if resetButton then
        F:HookScript(resetButton, "OnClick", function()
            if not pDb then return end
            pDb["bloodlustAvailable"] = false
            pDb["NoBloodlust"] = false
            pDb["battleResAvailable"] = false
            pDb["partyFit"] = false
            pDb["NoSameSpec"] = false
            RefreshVisibleEntries()
        end)
    end

    if isRestrictedContent() then return end
    RefreshVisibleEntries()
end

function F:OnEnable()
    RefreshPlayerSpec()

    local ev = self:NewEventFrame()
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:SetScript("OnEvent", RefreshPlayerSpec)

    GF.WatchLFG(self, InitDungeonFilter)
end
