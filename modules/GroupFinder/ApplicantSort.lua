local addonName, ns = ...

-- ===========================================================================
-- GROUP FINDER: SORT APPLICANTS
-- Sorts the people applying to your group's Mythic+ listing (Dungeon Finder "Application
-- Viewer") by, in this order:
--   1. highest key level completed IN TIME on the dungeon of the listing
--      (when the client doesn't tell us the dungeon: the applicant's best run overall)
--   2. overall M+ rating
--   3. item level
-- For a group application only the leader (member 1) is used.
-- Only pending applications ("applied") are reordered, among themselves; invited /
-- declined / etc. rows keep the slot Blizzard gave them.
-- Off = Blizzard's own order (hooks stay installed but return immediately).
-- ===========================================================================

local GF = ns:GetModule("GroupFinder")

local F = GF:NewFeature{
    key  = "applicantSort",
    name = "Sort Applicants by M+ Rating",
    desc = "Sorts applicants to your Mythic+ listing by highest key timed on the listed dungeon, then overall rating, then item level (group = leader only).",
}

CXUI_ApplicantSortDebug = CXUI_ApplicantSortDebug or false

local function Debug(...)
    if CXUI_ApplicantSortDebug then
        print("|cff33ccff[cxUI ApplicantSort]|r", ...)
    end
end

local DUNGEON_CATEGORY = 2 -- same category id DungeonFilter uses

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------

-- Values can be "secret" while the client restricts addon data; those count as 0.
local function Num(v)
    if type(v) ~= "number" then return 0 end
    if issecretvalue and issecretvalue(v) then return 0 end
    return v
end

-- Listing the applicants belong to:
--   activityID  a dungeon listing (rating on that dungeon can be used)
--   false       the listing is known and is NOT a dungeon (raid etc.) -> do not sort
--   nil         listing info not available to us (e.g. you are a party member, not the
--               listing owner) -> still sort, but by overall rating + item level only
local function GetListingActivityID()
    if not (C_LFGList and C_LFGList.GetActiveEntryInfo) then return nil end
    local entry = C_LFGList.GetActiveEntryInfo()
    if type(entry) ~= "table" then return nil end

    local activityID = (entry.activityIDs and entry.activityIDs[1]) or entry.activityID
    if not activityID then return nil end

    local activity = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
    if not activity then return nil end
    if activity.categoryID ~= DUNGEON_CATEGORY then return false end
    return activityID
end

-- Best key level completed in time, overall score and item level of the applicant's leader.
-- A best run that was not finished in time counts as 0.
local function GetMetrics(applicantID, activityID)
    local ok, keyLevel, score, ilvl = pcall(function()
        local _, _, _, _, itemLevel, _, _, _, _, _, _, dungeonScore =
            C_LFGList.GetApplicantMemberInfo(applicantID, 1)

        local best
        if activityID and C_LFGList.GetApplicantDungeonScoreForListing then
            best = C_LFGList.GetApplicantDungeonScoreForListing(applicantID, 1, activityID)
        elseif C_LFGList.GetApplicantBestDungeonScore then
            best = C_LFGList.GetApplicantBestDungeonScore(applicantID, 1) -- dungeon unknown
        end

        local level = 0
        if type(best) == "table" and best.finishedSuccess == true then
            level = Num(best.bestRunLevel)
        end
        return level, Num(dungeonScore), Num(itemLevel)
    end)
    if not ok then return 0, 0, 0 end
    return keyLevel, score, ilvl
end

-- ---------------------------------------------------------------------------
-- Sorting (in place on Blizzard's applicant ID list). Returns true if it changed.
-- ---------------------------------------------------------------------------
local function SortApplicants(applicants)
    if type(applicants) ~= "table" or #applicants < 2 then return false end
    if GF.IsRestrictedContent() then return false end

    local activityID = GetListingActivityID()
    if activityID == false then
        Debug("listing is not a dungeon -> leaving Blizzard order")
        return false
    end
    if activityID == nil then
        Debug("listing info unavailable (not the owner?) -> using each applicant's best run overall")
    end

    -- Collect the pending applicants and the slots they occupy.
    local slots, items = {}, {}
    for index, applicantID in ipairs(applicants) do
        local info = C_LFGList.GetApplicantInfo(applicantID)
        if info and info.applicationStatus == "applied" and not info.pendingApplicationStatus then
            local keyLevel, score, ilvl = GetMetrics(applicantID, activityID)
            slots[#slots + 1] = index
            items[#items + 1] = { id = applicantID, order = #slots, key = keyLevel, score = score, ilvl = ilvl }
        end
    end
    if #items < 2 then return false end

    table.sort(items, function(a, b)
        if a.key   ~= b.key   then return a.key   > b.key   end
        if a.score ~= b.score then return a.score > b.score end
        if a.ilvl  ~= b.ilvl  then return a.ilvl  > b.ilvl  end
        return a.order < b.order -- table.sort is not stable: keep Blizzard order on ties
    end)

    local changed = false
    for n, item in ipairs(items) do
        local slot = slots[n]
        if applicants[slot] ~= item.id then
            applicants[slot] = item.id
            changed = true
        end
        Debug(("#%d  id=%s  timedKey=+%d  score=%d  ilvl=%d"):format(n, tostring(item.id), item.key, item.score, item.ilvl))
    end
    return changed
end

-- ---------------------------------------------------------------------------
-- Hooking
-- ---------------------------------------------------------------------------
local function GetViewer()
    return LFGListFrame and LFGListFrame.ApplicationViewer
end

-- Makes Blizzard rebuild the list (used when the option is switched on/off live).
local function Refresh()
    local viewer = GetViewer()
    if not viewer or not viewer:IsShown() then return end
    if GF.IsRestrictedContent() then return end
    if type(LFGListApplicationViewer_UpdateResultList) == "function" then
        LFGListApplicationViewer_UpdateResultList(viewer)
    end
end

local function Install()
    -- Preferred: after Blizzard has built + sorted viewer.applicants, reorder it and redraw.
    local hooked = F:Hook("LFGListApplicationViewer_UpdateResultList", function(viewer)
        if SortApplicants(viewer and viewer.applicants) and type(LFGListApplicationViewer_UpdateResults) == "function" then
            LFGListApplicationViewer_UpdateResults(viewer)
        end
    end)

    -- Fallback if that function was renamed: reorder right after Blizzard's own sort.
    if not hooked then
        hooked = F:Hook("LFGListUtil_SortApplicants", SortApplicants)
        Debug(hooked and "installed fallback hook on LFGListUtil_SortApplicants" or "NO applicant hook found")
    else
        Debug("installed hook on LFGListApplicationViewer_UpdateResultList")
    end

    Refresh()
end

function F:OnEnable()
    -- The LFG UI is load-on-demand; WatchLFG waits for it.
    GF.WatchLFG(self, Install)
end

function F:OnDisable()
    -- Hooks are skipped now (IsOn() is false); put Blizzard's order back.
    Refresh()
end

SLASH_CXAPPLICANTSORT1 = "/cxsort"
SlashCmdList["CXAPPLICANTSORT"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        CXUI_ApplicantSortDebug = not CXUI_ApplicantSortDebug
        print("|cff33ccff[cxUI ApplicantSort]|r debug", CXUI_ApplicantSortDebug and "ON" or "OFF")
    else
        print("|cff33ccff[cxUI ApplicantSort]|r enabled:", F:IsOn() and "yes" or "no", "| /cxsort debug")
    end
end