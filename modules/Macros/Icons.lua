local addonName, ns = ...
local M = ns.Macros

-- ===========================================================================
-- ICONS: icon lists for the picker + a spell-name index for searching.
--   default list = icons of your spellbook, then Blizzard's macro icon lists
--   search       = typed text is matched against every spell name in the game
--                  (indexed in the background, only after the picker is opened
--                  for the first time); a number is tried as spell ID / file ID
-- ===========================================================================

local I = {}
M.Icons = I

local MAX_SPELL_ID   = 2000000   -- upper bound of the scan (missing ids are skipped quickly)
local FRAME_BUDGET   = 3         -- ms of scanning per frame
local GEAR_ICON      = 136243    -- placeholder icon of unnamed / test spells
local MAX_RESULTS    = 400

local byIcon = {}                -- [iconID] = "name1|name2" (lower case)
local state, nextId = "idle", 0  -- idle | scanning | done
I.onProgress = nil               -- fn(fraction, done)

function I.GetState() return state, nextId / MAX_SPELL_ID end

-- ---------------------------------------------------------------------------
-- Background index of spell names
-- ---------------------------------------------------------------------------
local driver

local function Step()
    local start = debugprofilestop()
    local GetName, GetTexture = C_Spell.GetSpellName, C_Spell.GetSpellTexture
    local id = nextId
    while id < MAX_SPELL_ID do
        id = id + 1
        local name = GetName(id)
        if name and name ~= "" then
            local icon = GetTexture(id)
            if icon and icon ~= GEAR_ICON and icon ~= M.DEFAULT_ICON then
                name = name:lower()
                local cur = byIcon[icon]
                if not cur then
                    byIcon[icon] = name
                elseif #cur < 300 and not cur:find(name, 1, true) then
                    byIcon[icon] = cur .. "|" .. name
                end
            end
        end
        -- check the clock every 256 ids: cheap, and keeps frames short
        if id % 256 == 0 and (debugprofilestop() - start) > FRAME_BUDGET then break end
    end
    nextId = id
    if id >= MAX_SPELL_ID then
        state = "done"
        driver:SetScript("OnUpdate", nil)
    end
    if I.onProgress then I.onProgress(nextId / MAX_SPELL_ID, state == "done") end
end

function I.StartIndexing()
    if state ~= "idle" then return end
    if not (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellTexture) then
        state = "done"
        return
    end
    state = "scanning"
    driver = driver or CreateFrame("Frame")
    driver:SetScript("OnUpdate", Step)
end

-- ---------------------------------------------------------------------------
-- Default list
-- ---------------------------------------------------------------------------
local looseCache

local function Loose()
    if looseCache then return looseCache end
    local raw = {}
    for _, fn in ipairs({ "GetLooseMacroIcons", "GetLooseMacroItemIcons", "GetMacroIcons", "GetMacroItemIcons" }) do
        local f = _G[fn]
        if type(f) == "function" then pcall(f, raw) end
    end
    local list, seen = {}, {}
    for _, v in ipairs(raw) do
        if type(v) == "string" then v = "INTERFACE\\ICONS\\" .. v end
        if not seen[v] then seen[v] = true; list[#list + 1] = v end
    end
    looseCache = list
    return list
end

local function Spellbook()
    local list, seen = {}, {}
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return list end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                local icon = item and item.iconID
                local future = Enum and Enum.SpellBookItemType and item and item.itemType == Enum.SpellBookItemType.FutureSpell
                if icon and not future and not seen[icon] then
                    seen[icon] = true
                    list[#list + 1] = icon
                end
            end
        end
    end
    return list
end

function I.GetDefaultList()
    local out, seen = {}, {}
    for _, icon in ipairs(Spellbook()) do seen[icon] = true; out[#out + 1] = icon end
    for _, icon in ipairs(Loose()) do
        if not seen[icon] then seen[icon] = true; out[#out + 1] = icon end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------
function I.Search(text)
    text = M.Trim(text):lower()
    if #text < 2 then return nil end

    local results, seen = {}, {}
    local n = tonumber(text)
    if n then
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(n)
        if tex then results[#results + 1] = tex; seen[tex] = true end
        if not seen[n] then results[#results + 1] = n; seen[n] = true end
    end

    local prefix, other = {}, {}
    for icon, names in pairs(byIcon) do
        local pos = names:find(text, 1, true)
        if pos and not seen[icon] then
            if pos == 1 or names:sub(pos - 1, pos - 1) == "|" then
                prefix[#prefix + 1] = icon
            else
                other[#other + 1] = icon
            end
        end
    end
    local function byName(a, b)
        local na, nb = byIcon[a], byIcon[b]
        if na ~= nb then return na < nb end
        return a < b
    end
    table.sort(prefix, byName)
    table.sort(other, byName)
    for _, list in ipairs({ prefix, other }) do
        for _, icon in ipairs(list) do
            if #results >= MAX_RESULTS then return results end
            results[#results + 1] = icon
        end
    end
    return results
end

-- Lower-case spell names that use this icon ("a|b"), once indexed.
function I.GetNames(icon) return byIcon[icon] end
