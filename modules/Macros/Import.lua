local addonName, ns = ...
local M = ns.Macros

-- ===========================================================================
-- IMPORT
--   M.ImportMegaMacro()  copies Mega Macro's saved data into our database
--                        (needs Mega Macro enabled for one session; nothing is
--                        overwritten: records land in their old slot or the
--                        first free one, identical records are skipped)
--   M.AdoptNative()      takes native macros that have no "#NNN" tag and moves
--                        them into the database (General / Character), tagging
--                        the native macro in place so bar buttons stay valid
-- ===========================================================================

local function Dupe(bucket, rec)
    for _, other in pairs(bucket) do
        if other.name == rec.name and other.body == rec.body then return true end
    end
    return false
end

local function Convert(m, stats)
    local icon = m.StaticTexture
    if icon == M.DEFAULT_ICON or icon == 0 or icon == "" then icon = nil end
    local body = m.Code or ""
    if #body > M.BODY_MAX then
        body = body:sub(1, M.BODY_MAX)
        stats.truncated = stats.truncated + 1
    end
    -- Mega Macro silently put "#showtooltip" in front of every macro that had none (and fitted);
    -- keep that, otherwise the bar buttons of those macros would lose their dynamic icon / tooltip.
    if not body:lower():find("#show", 1, true) and #body <= M.BODY_MAX - 13 then
        body = "#showtooltip\n" .. body
    end
    local name = M.Utf8Sub(M.Trim(m.DisplayName or ""), M.NAME_MAX)
    if name == "" then name = "Macro" end
    return { name = name, icon = icon, body = body }
end

-- hint = the slot the macro had in Mega Macro (id - scope offset)
local function Place(scope, key, hint, rec, stats)
    local sc = M.scopeByKey[scope]
    local bucket = M.GetBucket(scope, key, true)
    if Dupe(bucket, rec) then
        stats.already = stats.already + 1
        return
    end
    local slot = hint
    if not slot or slot < 1 or slot > sc.count or bucket[slot] then
        slot = M.FirstFreeSlot(scope, key)
    end
    if not slot then
        stats.skipped = stats.skipped + 1
        return
    end
    bucket[slot] = rec
    stats.imported = stats.imported + 1
end

local function Hint(m, offset)
    return m.Id and (m.Id - offset) or nil
end

local function ImportList(list, scope, key, offset, stats)
    if type(list) ~= "table" then return end
    for _, m in ipairs(list) do
        Place(scope, key, Hint(m, offset), Convert(m, stats), stats)
    end
end

function M.ImportMegaMacro()
    local g = _G.MegaMacroGlobalData
    if type(g) ~= "table" then
        ns.Print("Mega Macro data not found. Enable Mega Macro, |cffffff00/reload|r, run |cffffff00/cxm import|r, " ..
            "then disable Mega Macro and reload again.")
        return
    end
    local stats = { imported = 0, already = 0, skipped = 0, truncated = 0, unknown = 0 }

    ImportList(g.Macros, "general", nil, 0, stats)
    ImportList(g.InactiveMacros, "archive", nil, 150, stats)

    -- class / spec names are saved localised: map them back to classFile / specID
    local classByName = {}
    for _, c in ipairs(M.GetClassList()) do classByName[c.name] = c end
    for className, data in pairs(g.Classes or {}) do
        local class = classByName[className]
        if not class then
            stats.unknown = stats.unknown + 1
        else
            ImportList(data.Macros, "class", class.file, 60, stats)
            local specByName = {}
            for _, s in ipairs(M.GetSpecList(class.id)) do specByName[s.name] = s end
            for specName, sdata in pairs(data.Specializations or {}) do
                local spec = specByName[specName]
                if spec then
                    ImportList(sdata.Macros, "spec", spec.id, 90, stats)
                else
                    stats.unknown = stats.unknown + 1
                end
            end
        end
    end

    local charData = _G.MegaMacroCharacterData
    local ctx = M.GetContext()
    if type(charData) == "table" and ctx.guid then
        M.RegisterCharacter(ctx)
        ImportList(charData.Macros, "char", ctx.guid, 120, stats)
    end

    ns.Print(("Mega Macro import: |cff00ff00%d|r imported, %d already present, %d skipped (no free slot), " ..
        "%d cut to %d characters, %d class/spec groups not recognised."):format(
        stats.imported, stats.already, stats.skipped, stats.truncated, M.BODY_MAX, stats.unknown))
    print("   Other characters: log in on each one with Mega Macro enabled and run |cffffff00/cxm import|r there.")
    print("   When done, disable Mega Macro and |cffffff00/reload|r.")
    if M.NotifyChanged then M.NotifyChanged() end
end

-- ---------------------------------------------------------------------------
-- Native macros without a tag
-- ---------------------------------------------------------------------------
function M.CountUntagged()
    local n = 0
    local total = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 30)
    for i = 1, total do
        local name, _, body = GetMacroInfo(i)
        if name and not M.TagId(body) then n = n + 1 end
    end
    return n
end

function M.AdoptNative()
    if InCombatLockdown() then
        ns.Print("Not in combat, please.")
        return
    end
    if M.IsAddOnLoaded("MegaMacro") then
        ns.Print("Disable Mega Macro first (it manages the same native slots).")
        return
    end
    local S = M.Slots
    local ctx = M.GetContext()
    S.Scan()
    local accountMax = MAX_ACCOUNT_MACROS or 120
    local adopted, skipped = 0, 0

    for i = 1, accountMax + (MAX_CHARACTER_MACROS or 30) do
        local name, icon, body = GetMacroInfo(i)
        if name and not M.TagId(body) then
            local perChar = i > accountMax
            local scope = perChar and "char" or "general"
            local key = perChar and ctx.guid or nil
            local sc = M.scopeByKey[scope]
            body = body or ""
            local slot
            if scope ~= "char" or key then
                slot = M.FirstFreeSlot(scope, key, function(s)
                    return not S.HasNative(sc.first + s)    -- never share a tag with a stale blank slot
                end)
            end
            if scope == "char" then M.RegisterCharacter(ctx) end
            if #body > M.BODY_MAX or not slot then
                skipped = skipped + 1
            else
                -- a #showtooltip macro has a dynamic icon: keep it dynamic, do not freeze what is shown now
                local dynamic = body:find("^%s*#show") ~= nil
                local rec = {
                    name = M.Utf8Sub(name, M.NAME_MAX),
                    icon = (not dynamic) and icon or nil,
                    body = body,
                }
                M.SetRecord(scope, key, slot, rec)
                local id = sc.first + slot
                local ok = pcall(EditMacro, i, name, dynamic and M.DEFAULT_ICON or icon, M.Tag(id) .. "\n" .. body)
                if ok then
                    adopted = adopted + 1
                else
                    M.SetRecord(scope, key, slot, nil)
                    skipped = skipped + 1
                end
            end
        end
    end
    S.Scan()
    ns.Print(("Adopted |cff00ff00%d|r native macro(s); %d skipped (too long or no free slot)."):format(adopted, skipped))
    if M.NotifyChanged then M.NotifyChanged() end
end
