local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MYTHIC+: BOSS PB PREVIEW
--
-- EllesmereUIMythicTimer only shows how much faster/slower you killed a
-- boss AFTER the fact, compared to your best split. This module injects
-- that target time directly into EllesmereUIMythicTimer's OWN on-screen
-- frame, BEFORE each boss dies -- without editing a single line of
-- EllesmereUI's files.
--
-- If you've never done the current key level before, it walks down one
-- level at a time (level-1, level-2, ...) until it finds a level you HAVE
-- completed, and shows that instead, tagged with the level it came from.
--
-- HOW IT HOOKS IN
-- EllesmereUIMythicTimer exposes three globals at the bottom of its file:
--   _G._EMT_StandaloneRefresh  - its own redraw function
--   _G._EMT_GetStandaloneFrame - its live frame
--   _G._EMT_AceDB               - its live profile db
-- We hooksecurefunc the redraw function and, right after each redraw,
-- overwrite the time text of any not-yet-completed boss row with our own
-- prediction. We only read its best-split history and overwrite FontString
-- *display text* (regenerated on the next redraw). The one thing we DO change
-- is two of its profile options (see TryHook) - and only while this feature is
-- on: the previous values are put back when it is turned off.
--
-- CAVEAT: EllesmereUIMythicTimer doesn't expose the boss row FontStrings
-- by name, so we find them by elimination (every other FontString on its
-- frame is a known, named field -- see EMT_KNOWN_FS_FIELDS). We sanity
-- check the count before touching anything; if a future EllesmereUI
-- update changes that frame's layout, this module just stops updating
-- the preview instead of risking writing the wrong number on the wrong
-- boss.
-- ---------------------------------------------------------------------------

local EMT_PREVIEW_MIN_LEVEL = 2 -- don't cascade below this key level

local EMT_KNOWN_FS_FIELDS = {
    "_titleFS", "_affixFS", "_timerFS", "_keyLevelFS", "_timerDetailFS",
    "_threshFS", "_threshFS2", "_threshRemFS", "_deathFS", "_enemyFS",
    "_previewFS", "_enemyBarText", "_barTimerFS",
}

local MP = ns:GetModule("MythicPlus")

local F = MP:NewFeature{
    key  = "bossPBPreview",
    name = "Boss PB Preview (EllesmereUI M+ Timer)",
    desc = "Shows your best split for each upcoming boss in EllesmereUIMythicTimer. Needs EllesmereUI.",
    info = "Shows your best split for each upcoming boss directly in EllesmereUIMythicTimer's own frame, before you kill it. Falls back to the closest lower key level you've completed if you have no data for the current level yet. Requires EllesmereUI + EllesmereUIMythicTimer.",
}

local hooked = false
local warnedOnce = false
local changed -- { showUpcoming = old, compareMode = old } while we own the profile settings

local function GetEMTProfile()
    return _G._EMT_AceDB and _G._EMT_AceDB.profile
end

local function GetPredictedSplit(mapID, level, criteriaIndex)
    local p = GetEMTProfile()
    local store = p and p.bestObjectiveSplits
    if not store or not mapID or not level then return nil end
    for lvl = level, EMT_PREVIEW_MIN_LEVEL, -1 do
        local scope = store[tostring(mapID) .. ":" .. lvl]
        if scope and scope[criteriaIndex] then
            return scope[criteriaIndex], lvl
        end
    end
    return nil
end

local function FormatTime(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function GetCurrentObjectives()
    local numCriteria = select(3, C_Scenario.GetStepInfo())
    if not numCriteria or numCriteria == 0 then return nil end
    local list = {}
    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            list[#list + 1] = { criteriaIndex = i, completed = info.completed }
        end
    end
    return list
end

local function GetBossRowFontStrings(frame, expectedCount)
    local known = {}
    for _, field in ipairs(EMT_KNOWN_FS_FIELDS) do
        local fs = frame[field]
        if fs then known[fs] = true end
    end

    local leftover = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" and not known[region] then
            leftover[#leftover + 1] = region
        end
    end

    -- Rows are created as (name, time) pairs, in objective order.
    if #leftover ~= expectedCount * 2 then
        return nil -- layout doesn't match what we expect -- bail out safely
    end

    local rows = {}
    for i = 1, expectedCount do
        rows[i] = { name = leftover[i * 2 - 1], time = leftover[i * 2] }
    end
    return rows
end

local function OnEMTRefresh()

    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return end
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if not level then return end

    local objectives = GetCurrentObjectives()
    if not objectives or #objectives == 0 then return end

    local frame = _G._EMT_GetStandaloneFrame and _G._EMT_GetStandaloneFrame()
    if not frame or not frame:IsShown() then return end

    local rows = GetBossRowFontStrings(frame, #objectives)
    if not rows then
        if not warnedOnce then
            warnedOnce = true
            print("|cff0070ddcx|cffffff00UI|r: couldn't match boss rows on EllesmereUIMythicTimer's "
                .. "frame (it may have changed layout). Boss PB Preview disabled until cxUI is updated.")
        end
        return
    end

    for idx, obj in ipairs(objectives) do
        if not obj.completed then
            local split, foundLevel = GetPredictedSplit(mapID, level, obj.criteriaIndex)
            if split then
                local timeFS = rows[idx].time
                if foundLevel == level then
                    timeFS:SetText("|cff888888" .. FormatTime(split) .. "|r")
                else
                    timeFS:SetText("|cff888888" .. FormatTime(split) .. " (+" .. foundLevel .. ")|r")
                end
            end
            -- No PB data at all down to the floor level -> leave whatever
            -- EllesmereUIMythicTimer itself already put there.
        end
    end
end

local function TryHook()
    if not (_G._EMT_StandaloneRefresh and _G._EMT_GetStandaloneFrame and _G._EMT_AceDB) then
        return false
    end

    -- Turn on EllesmereUIMythicTimer's own (UI-hidden) "show upcoming split
    -- target" option so it actually builds a row for uncompleted bosses for
    -- us to then overwrite. Only set the compare mode if the user hasn't
    -- already picked one themselves. Old values are remembered for OnDisable.
    local p = GetEMTProfile()
    if p and not changed then
        changed = { showUpcoming = p.showUpcomingSplitTargets, compareMode = p.objectiveCompareMode }
        p.showUpcomingSplitTargets = true
        if not p.objectiveCompareMode or p.objectiveCompareMode == "NONE" then
            p.objectiveCompareMode = "LEVEL"
        end
    end

    hooked = F:Hook("_EMT_StandaloneRefresh", OnEMTRefresh)
    return hooked
end

function F:OnEnable()
    warnedOnce = false
    if TryHook() then return end

    -- EllesmereUIMythicTimer hasn't finished loading its globals yet
    -- (unusual load order / addon disabled at the time). Poll briefly.
    local tries = 0
    local ticker
    ticker = self:NewTicker(1, function()
        tries = tries + 1
        if TryHook() or tries >= 15 then ticker:Cancel() end
    end)
end

function F:OnDisable()
    -- Hand EllesmereUIMythicTimer's settings back exactly as we found them.
    local p = GetEMTProfile()
    if p and changed then
        p.showUpcomingSplitTargets = changed.showUpcoming
        p.objectiveCompareMode = changed.compareMode
    end
    changed = nil
end
