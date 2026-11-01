local addonName, ns = ...
local M = ns.Macros

-- ===========================================================================
-- HIGHLIGHT: colours a macro body. Purely visual: the result is drawn by a
-- FontString placed under a transparent EditBox, so the caret / selection /
-- undo behaviour of the real EditBox is untouched.
-- ===========================================================================

local COLOR = {
    hash    = "66cc66",  -- #showtooltip / #show
    cmd     = "33aaff",  -- /cast /use ...
    bracket = "8a8a99",  -- [ ] ; ,
    cond    = "ff9900",  -- combat, mod, harm ...
    arg     = "ffee99",  -- the value after ':' (shift, 2, ...)
    unit    = "ffff00",  -- @target, @focus, ! ?
    num     = "ff9900",
    spell   = "ffffff",
    chat    = "eedd82",  -- text of /say /emote ...
    lua     = "b8b8c8",  -- /run /script
}

-- Commands whose argument is plain chat text, and ones whose argument is Lua code.
local CHAT = {}
for w in ([[say s yell y party p raid ra guild g officer o instance i raidwarning rw
    whisper w tell t reply r emote e me em chatlist cwhisper]]):gmatch("%S+") do CHAT[w] = true end
local LUA = {}
for w in ("run script dump print console macro"):gmatch("%S+") do LUA[w] = true end

local function esc(s) return (s:gsub("|", "||")) end

local function paint(color, s)
    if s == "" then return "" end
    return "|cff" .. color .. esc(s) .. "|r"
end

-- Inside [ ... ]
local function ParseCond(s)
    local out, i, n, argMode = {}, 1, #s, false
    while i <= n do
        local a, b = s:find("^@[%w_%-]*", i)
        if not a then a, b = s:find("^target=[%w_%-]*", i) end
        if a then
            out[#out + 1] = paint(COLOR.unit, s:sub(a, b))
            i = b + 1
        else
            a, b = s:find("^%a[%w_]*", i)
            if a then
                out[#out + 1] = paint(argMode and COLOR.arg or COLOR.cond, s:sub(a, b))
                i = b + 1
            else
                a, b = s:find("^%d+", i)
                if a then
                    out[#out + 1] = paint(COLOR.num, s:sub(a, b))
                    i = b + 1
                else
                    local ch = s:sub(i, i)
                    if ch == ":" then argMode = true
                    elseif ch == "," then argMode = false end
                    out[#out + 1] = paint(COLOR.bracket, ch)
                    i = i + 1
                end
            end
        end
    end
    return table.concat(out)
end

-- One piece of text between conditions / semicolons: a spell, item, number ...
local function PaintSpellPiece(piece)
    local lead, rest = piece:match("^(%s*)(.*)$")
    local pre, name = rest:match("^([!?]*)(.*)$")
    local body, trail = name:match("^(.-)(%s*)$")
    local out = { esc(lead) }
    if pre ~= "" then out[#out + 1] = paint(COLOR.unit, pre) end
    if body:find("^%d+$") then
        out[#out + 1] = paint(COLOR.num, body)
    elseif body:find("^reset=") then
        local reset, after = body:match("^(reset=%S*)%s*(.*)$")
        out[#out + 1] = paint(COLOR.cond, reset)
        if after ~= "" then out[#out + 1] = " " .. paint(COLOR.spell, after) end
    else
        out[#out + 1] = paint(COLOR.spell, body)
    end
    out[#out + 1] = esc(trail)
    return table.concat(out)
end

local function ParseSpells(s)
    local out, pos = {}, 1
    while true do
        local comma = s:find(",", pos, true)
        out[#out + 1] = PaintSpellPiece(s:sub(pos, (comma or #s + 1) - 1))
        if not comma then break end
        out[#out + 1] = paint(COLOR.bracket, ",")
        pos = comma + 1
    end
    return table.concat(out)
end

-- Everything after the command: [conditions] spells; [conditions] spells
local function ParseArgs(rest)
    local out, i, n = {}, 1, #rest
    while i <= n do
        local ch = rest:sub(i, i)
        if ch == "[" then
            local close = rest:find("]", i, true)
            out[#out + 1] = paint(COLOR.bracket, "[")
            out[#out + 1] = ParseCond(rest:sub(i + 1, (close or n + 1) - 1))
            if close then
                out[#out + 1] = paint(COLOR.bracket, "]")
                i = close + 1
            else
                i = n + 1
            end
        elseif ch == ";" then
            out[#out + 1] = paint(COLOR.bracket, ";")
            i = i + 1
        else
            local stop = rest:find("[%[;]", i) or (n + 1)
            out[#out + 1] = ParseSpells(rest:sub(i, stop - 1))
            i = stop
        end
    end
    return table.concat(out)
end

local function HighlightLine(line)
    local lead, rest = line:match("^(%s*)(.*)$")
    local first = rest:sub(1, 1)
    if first == "#" then
        local word, tail = rest:match("^(#%S*)(.*)$")
        return esc(lead) .. paint(COLOR.hash, word) .. ParseArgs(tail)
    elseif first == "/" then
        local cmd, tail = rest:match("^(/%S*)(.*)$")
        local name = cmd:sub(2):lower()
        if CHAT[name] then return esc(lead) .. paint(COLOR.cmd, cmd) .. paint(COLOR.chat, tail) end
        if LUA[name]  then return esc(lead) .. paint(COLOR.cmd, cmd) .. paint(COLOR.lua, tail) end
        return esc(lead) .. paint(COLOR.cmd, cmd) .. ParseArgs(tail)
    end
    return esc(line)
end

function M.Highlight(text)
    if not text or text == "" then return "" end
    local out, pos = {}, 1
    while true do
        local nl = text:find("\n", pos, true)
        out[#out + 1] = HighlightLine(text:sub(pos, (nl or #text + 1) - 1))
        if not nl then break end
        pos = nl + 1
    end
    return table.concat(out, "\n")
end
