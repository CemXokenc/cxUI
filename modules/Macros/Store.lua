local addonName, ns = ...
local M = ns.Macros

-- ===========================================================================
-- STORE: CXUI_MacroDB
--   general[slot]            = rec
--   archive[slot]            = rec
--   class[classFile][slot]   = rec
--   spec[specID][slot]       = rec
--   char[guid]               = { name, class, macros = { [slot] = rec } }
--   rec = { name = "", icon = fileID | nil (nil = "?" dynamic), body = "" }
-- Keys are non-localised (classFile / specID), so a client language change
-- does not lose anything.
-- ===========================================================================

CXUI_MacroDB = CXUI_MacroDB or {}

local function DB()
    local db = CXUI_MacroDB
    if type(db) ~= "table" then db = {}; CXUI_MacroDB = db end
    db.version = db.version or 1
    db.general = db.general or {}
    db.archive = db.archive or {}
    db.class   = db.class   or {}
    db.spec    = db.spec    or {}
    db.char    = db.char    or {}
    db.ui      = db.ui      or {}
    return db
end
M.DB = DB

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------
function M.Tag(id) return ("#%03d"):format(id) end

function M.TagId(body)
    local n = body and body:match("^#(%d%d%d)")
    return n and tonumber(n) or nil
end

-- Cut a string to n characters without splitting a UTF-8 sequence.
function M.Utf8Sub(s, n)
    local len, pos, size = 0, 1, #s
    while pos <= size do
        if len == n then return s:sub(1, pos - 1) end
        local c = s:byte(pos)
        pos = pos + (c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or 4)
        len = len + 1
    end
    return s
end

function M.Trim(s) return (s or ""):match("^%s*(.-)%s*$") end

function M.IsAddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f and f(name) and true or false
end

-- ---------------------------------------------------------------------------
-- Class / spec information (defensive: these APIs moved into C_SpecializationInfo)
-- ---------------------------------------------------------------------------
local function SpecAPI(name, ...)
    local ns_ = C_SpecializationInfo
    local fn = (ns_ and ns_[name]) or _G[name]
    if type(fn) == "function" then return fn(...) end
end

function M.GetCurrentSpecID()
    local idx = SpecAPI("GetSpecialization")
    if not idx or idx == 0 then return nil end
    return (SpecAPI("GetSpecializationInfo", idx))
end

function M.GetContext()
    local _, classFile, classID = UnitClass("player")
    return {
        classFile = classFile,
        classID   = classID,
        specID    = M.GetCurrentSpecID(),
        guid      = UnitGUID("player"),
    }
end

local classList
function M.GetClassList()
    if classList then return classList end
    local list = {}
    if GetNumClasses and GetClassInfo then
        for i = 1, GetNumClasses() do
            local name, file, id = GetClassInfo(i)
            if file then list[#list + 1] = { name = name, file = file, id = id } end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    if #list > 0 then classList = list end
    return list
end

function M.GetSpecList(classID)
    local list = {}
    local n = SpecAPI("GetNumSpecializationsForClassID", classID) or 0
    for i = 1, n do
        local id, name, _, icon = SpecAPI("GetSpecializationInfoForClassID", classID, i)
        if id then list[#list + 1] = { id = id, name = name, icon = icon } end
    end
    return list
end

function M.ClassColor(classFile)
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- ---------------------------------------------------------------------------
-- Buckets and records
-- ---------------------------------------------------------------------------
-- The key for a scope inside a context (general / archive have none).
function M.ScopeKey(scope, ctx)
    if scope == "class" then return ctx.classFile
    elseif scope == "spec" then return ctx.specID
    elseif scope == "char" then return ctx.guid end
    return nil
end

-- Returns the slot -> rec table, or nil when it does not exist (create = true makes it).
function M.GetBucket(scope, key, create)
    local db = DB()
    if scope == "general" or scope == "archive" then return db[scope] end
    if key == nil then return nil end
    local parent = db[scope]
    local entry = parent[key]
    if scope == "char" then
        if not entry then
            if not create then return nil end
            entry = { macros = {} }
            parent[key] = entry
        end
        entry.macros = entry.macros or {}
        return entry.macros
    end
    if not entry and create then
        entry = {}
        parent[key] = entry
    end
    return entry
end

function M.GetRecord(scope, key, slot)
    local bucket = M.GetBucket(scope, key, false)
    return bucket and bucket[slot] or nil
end

function M.SetRecord(scope, key, slot, rec)
    local bucket = M.GetBucket(scope, key, rec ~= nil)
    if not bucket then return end
    bucket[slot] = rec
end

-- First empty slot of a bucket; `accept(slot)` can veto slots.
function M.FirstFreeSlot(scope, key, accept)
    local sc = M.scopeByKey[scope]
    local bucket = M.GetBucket(scope, key, false) or {}
    for slot = 1, sc.count do
        if not bucket[slot] and (not accept or accept(slot)) then return slot end
    end
end

function M.CopyRecord(rec)
    return { name = rec.name, icon = rec.icon, body = rec.body }
end

-- Remember who this character is, so its macros can be browsed from other characters.
function M.RegisterCharacter(ctx)
    if not ctx.guid then return end
    local bucket = M.GetBucket("char", ctx.guid, true)
    local entry = DB().char[ctx.guid]
    local name, realm = UnitFullName("player")
    entry.name  = name and (realm and realm ~= "" and (name .. "-" .. realm) or name) or entry.name
    entry.class = ctx.classFile or entry.class
    return bucket
end

function M.GetCharacterList()
    local list = {}
    for guid, entry in pairs(DB().char) do
        list[#list + 1] = { guid = guid, name = entry.name or guid, class = entry.class }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function M.CountRecords()
    local n = 0
    local db = DB()
    local function count(t) for _ in pairs(t) do n = n + 1 end end
    count(db.general); count(db.archive)
    for _, t in pairs(db.class) do count(t) end
    for _, t in pairs(db.spec) do count(t) end
    for _, e in pairs(db.char) do if e.macros then count(e.macros) end end
    return n
end
