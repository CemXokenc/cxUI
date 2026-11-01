local addonName, ns = ...
local M = ns.Macros

-- ===========================================================================
-- SLOTS: the native macro slot engine.
-- Every macro id (1..150) owns at most one native macro, recognised by a
-- "#NNN" tag on its first line. Slots are never deleted when a macro goes
-- away (they are blanked), so action-bar buttons keep their position.
-- Everything that creates / edits macros is blocked in combat, so it is
-- queued and replayed on PLAYER_REGEN_ENABLED.
-- ===========================================================================

local S = {}
M.Slots = S

local nativeIndex = {}   -- [id] = native macro index
local pending = false

local function MaxAccount() return MAX_ACCOUNT_MACROS or 120 end
local function MaxChar()    return MAX_CHARACTER_MACROS or 30 end

function S.Scan()
    wipe(nativeIndex)
    local accountMax = MaxAccount()
    for i = 1, accountMax + MaxChar() do
        local name, _, body = GetMacroInfo(i)
        if name then
            local id = M.TagId(body)
            -- a tagged macro in the wrong space (account vs character) is ignored
            if id and not nativeIndex[id] and ((id <= M.ACCOUNT_IDS) == (i <= accountMax)) then
                nativeIndex[id] = i
            end
        end
    end
end

-- Native macro of an id, verified (re-scans when the index moved). Returns idx, name, icon, body.
local function Native(id)
    local idx = nativeIndex[id]
    if idx then
        local name, icon, body = GetMacroInfo(idx)
        if name and M.TagId(body) == id then return idx, name, icon, body end
        S.Scan()
        idx = nativeIndex[id]
        if idx then
            name, icon, body = GetMacroInfo(idx)
            return idx, name, icon, body
        end
    end
end

function S.GetNativeIndex(id)
    local idx = Native(id)
    return idx
end

function S.HasNative(id) return nativeIndex[id] ~= nil end

-- ---------------------------------------------------------------------------
-- Writing one id
-- ---------------------------------------------------------------------------
local function Desired(id, rec)
    local name = M.Trim(rec.name)
    if name == "" then name = "Macro" end
    name = M.Utf8Sub(name, M.NATIVE_NAME_MAX)
    local body = M.Tag(id) .. "\n" .. (rec.body or "")
    if #body > M.NATIVE_MAX then body = body:sub(1, M.NATIVE_MAX) end
    return name, rec.icon or M.DEFAULT_ICON, body
end

-- rec == nil blanks the slot (if there is one). Returns true when something was written.
local function Apply(id, rec, force)
    local idx, curName, curIcon, curBody = Native(id)

    if rec then
        local name, icon, body = Desired(id, rec)
        if not idx then
            local ok, new = pcall(CreateMacro, name, icon, body, id > M.ACCOUNT_IDS)
            if ok and new then
                nativeIndex[id] = new
                return true
            end
            S.failed = (S.failed or 0) + 1
            return false
        end
        local iconDiffers = rec.icon and rec.icon ~= curIcon
        if force or curName ~= name or curBody ~= body or iconDiffers then
            local ok, new = pcall(EditMacro, idx, name, icon, body)
            if ok then
                if new and new ~= idx then nativeIndex[id] = new end
                return true
            end
            S.failed = (S.failed or 0) + 1
        end
        return false
    end

    if idx and curBody ~= M.Tag(id) then
        local ok, new = pcall(EditMacro, idx, " ", M.DEFAULT_ICON, M.Tag(id))
        if ok then
            if new and new ~= idx then nativeIndex[id] = new end
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Context
-- ---------------------------------------------------------------------------
-- Does this scope + key belong to the character that is playing right now?
function S.IsActive(scope, key, ctx)
    ctx = ctx or M.GetContext()
    if scope == "general" then return true end
    if scope == "class" then return key ~= nil and key == ctx.classFile end
    if scope == "spec"  then return key ~= nil and key == ctx.specID end
    if scope == "char"  then return key ~= nil and key == ctx.guid end
    return false
end

-- Write one slot after the window changed it. Returns "applied", "queued" or "inactive".
function S.ApplySlot(scope, key, slot)
    local sc = M.scopeByKey[scope]
    if not sc.bound or not S.IsActive(scope, key) then return "inactive" end
    if not (M.IsManaging and M.IsManaging()) then return "inactive" end
    if InCombatLockdown() then
        pending = true
        return "queued"
    end
    S.Scan()
    S.failed = 0
    Apply(sc.first + slot, M.GetRecord(scope, key, slot), true)
    S.ReportFailures()
    return "applied"
end

function S.ReportFailures()
    if (S.failed or 0) > 0 then
        ns.Print(("%d macro(s) could not be written - the native macro slots are probably full. " ..
            "Delete unused native macros or run |cffffff00/cxm adopt|r."):format(S.failed))
        S.failed = 0
    end
end

-- ---------------------------------------------------------------------------
-- Full synchronisation for the current character / class / spec
-- ---------------------------------------------------------------------------
function S.Sync(force)
    if not (M.IsManaging and M.IsManaging()) then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false

    local ctx = M.GetContext()
    if not ctx.classFile or not ctx.guid then return end
    M.RegisterCharacter(ctx)

    S.Scan()
    S.failed = 0
    for _, sc in ipairs(M.scopes) do
        if sc.bound then
            local key = M.ScopeKey(sc.key, ctx)
            if sc.key == "general" or key ~= nil then
                local bucket = M.GetBucket(sc.key, key, false)
                for slot = 1, sc.count do
                    Apply(sc.first + slot, bucket and bucket[slot], force)
                end
            end
        end
    end
    S.ReportFailures()
    if M.NotifyChanged then M.NotifyChanged() end
end

function S.HasPending() return pending end

-- Blank every slot of the current character that this addon manages (used by "release").
function S.Release()
    if InCombatLockdown() then return false end
    S.Scan()
    local n = 0
    for id, idx in pairs(nativeIndex) do
        local name, icon, body = GetMacroInfo(idx)
        if name then
            -- strip the tag only; the macro itself stays where it is
            local rest = body:gsub("^#%d%d%d\n?", "")
            pcall(EditMacro, idx, name, icon, rest)
            n = n + 1
        end
    end
    S.Scan()
    return n
end
