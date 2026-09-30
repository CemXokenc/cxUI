local addonName, ns = ...

-- ===========================================================================
-- MODULES: registry + feature lifecycle (shared by every module)
--
-- Every module lives in modules/<Name>/ and consists of
--   <Name>.lua        registers the module and holds helpers shared by its features
--   <Feature>.lua     one file per feature
--
-- A feature declares its DB key, label and description, and implements
--   F:OnEnable()   install hooks / register events / start timers
--   F:OnDisable()  undo visible changes (events, timers, OnUpdate scripts and
--                  frames created through F:New*() are torn down automatically)
--
-- Lifecycle guarantee: a feature that is OFF has no events, no timers and no
-- OnUpdate scripts running. Blizzard hooks cannot be removed, so they are only
-- installed when the feature is first turned on, and (via F:Hook) return
-- immediately whenever the feature is off.
--
-- Features flagged `reload = true` are only activated at login; toggling them
-- mid-session just changes the DB flag (hooks still honour it).
-- ===========================================================================

ns.modules      = {}
ns.moduleByID   = {}
ns.featureList  = {}
ns.featureByKey = {}
ns.choiceList   = {}

local Module  = {}; Module.__index  = Module
local Feature = {}; Feature.__index = Feature

local seq = 0
local function nextSeq() seq = seq + 1; return seq end

local function report(where, err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(("cxUI %s: %s"):format(where, tostring(err))) end
end

-- ---------------------------------------------------------------------------
-- Modules
-- ---------------------------------------------------------------------------
function ns:NewModule(id, info)
    assert(not ns.moduleByID[id], "cxUI: duplicate module " .. tostring(id))
    local mod = setmetatable({
        id = id, name = info.name or id, desc = info.desc or "",
        order = info.order or 100, seq = nextSeq(), entries = {},
        groups = info.groups, -- optional submenus: { {id=, name=}, ... }; features join one via group/class
    }, Module)
    ns.modules[#ns.modules + 1] = mod
    ns.moduleByID[id] = mod
    return mod
end

function ns:GetModule(id)
    return ns.moduleByID[id] or error("cxUI: module '" .. tostring(id) .. "' is not registered (check load order in cxUI.toc)", 2)
end

function Module:AddEntry(entry, order)
    entry.seq = nextSeq()
    entry.order = order or entry.seq
    entry.module = self
    self.entries[#self.entries + 1] = entry
    return entry
end

-- Registers a feature (a checkbox in the module's options page).
-- info: key, name, desc, [info], [default=true], [reload], [class], [group],
--       [sound = {kind="file"|"kit", value=..., name=..., filesOnly=bool, premium=bool}]  (a configurable sound;
--        premium = true adds the "Premium" random-pool button to its sound picker, see the Premium section below)
function Module:NewFeature(info)
    assert(info.key and info.name, "cxUI: feature needs key and name")
    local f = setmetatable({
        kind = "feature", key = info.key, name = info.name, desc = info.desc or "",
        info = info.info, default = (info.default ~= false), reload = info.reload and true or false,
        class = info.class, group = info.group or info.class, active = false,
        sound = info.sound, -- default sound spec; the player's own choice lives in CXUI_DB.soundChoices
        _frames = {}, _timers = setmetatable({}, { __mode = "k" }), _hooked = {},
    }, Feature)
    self:AddEntry(f, info.order)
    ns.featureList[#ns.featureList + 1] = f
    ns.featureByKey[f.key] = f
    return f
end

-- Registers a mutually exclusive setting (radio group) that stores a string in the DB.
-- info: key, name, desc, default, choices = { {value, name, desc}, ... }, [onChange]
function Module:NewChoice(info)
    local c = { kind = "choice", key = info.key, name = info.name, desc = info.desc or "",
                default = info.default, choices = info.choices, onChange = info.onChange }
    self:AddEntry(c, info.order)
    ns.choiceList[#ns.choiceList + 1] = c
    return c
end

function Module:NewNote(text, order)
    return self:AddEntry({ kind = "note", text = text }, order)
end

-- group (optional): only entries belonging to that submenu
function Module:GetEntries(group)
    local list = {}
    for _, e in ipairs(self.entries) do
        if not group or e.group == group then list[#list + 1] = e end
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.seq < b.seq
    end)
    return list
end

-- ---------------------------------------------------------------------------
-- Feature helpers
-- ---------------------------------------------------------------------------

-- True while the feature is running AND its checkbox is on. Use in every callback.
function Feature:IsOn()
    return self.active and CXUI_DB ~= nil and CXUI_DB[self.key] == true
end

-- Frame that is silenced (events + OnUpdate cleared) when the feature turns off.
function Feature:NewFrame(frameType, name, parent, template)
    local fr = CreateFrame(frameType or "Frame", name, parent, template)
    self._frames[#self._frames + 1] = fr
    return fr
end

function Feature:NewEventFrame() return self:NewFrame("Frame") end

function Feature:NewTimer(delay, fn)
    local t
    t = C_Timer.NewTimer(delay, function()
        self._timers[t] = nil
        if self:IsOn() then fn() end
    end)
    self._timers[t] = true
    return t
end

function Feature:After(delay, fn) return self:NewTimer(delay, fn) end

function Feature:NewTicker(interval, fn, iterations)
    local t = C_Timer.NewTicker(interval, function() if self:IsOn() then fn() end end, iterations)
    self._timers[t] = true
    return t
end

-- Once-only hooksecurefunc whose body is skipped while the feature is off.
--   F:Hook("GlobalFunc", fn)   F:Hook(tbl, "Method", fn)
function Feature:Hook(target, method, fn)
    local key
    if type(target) == "string" then
        fn, method, key = method, nil, "_G." .. target
        if type(_G[target]) ~= "function" then return false end
    else
        if not target or type(target[method]) ~= "function" then return false end
        key = tostring(target) .. "." .. method
    end
    if self._hooked[key] then return true end
    self._hooked[key] = true
    local function wrapper(...) if self:IsOn() then fn(...) end end
    if method then hooksecurefunc(target, method, wrapper) else hooksecurefunc(key:sub(4), wrapper) end
    return true
end

function Feature:HookScript(frame, script, fn)
    if not frame or not frame.HookScript then return false end
    local key = tostring(frame) .. "#" .. script
    if self._hooked[key] then return true end
    self._hooked[key] = true
    frame:HookScript(script, function(...) if self:IsOn() then fn(...) end end)
    return true
end

-- The sound this feature plays: the player's choice, or the shipped default.
function Feature:GetSound()
    local choices = CXUI_DB and CXUI_DB.soundChoices
    return (choices and choices[self.key]) or self.sound
end

-- Every sound this feature may play right now. Normally just GetSound(). With Premium on and
-- `sound.premium` set, the sounds ticked for this feature in the Premium window join it.
function Feature:GetPool()
    local pool = { self:GetSound() }
    if not (self.sound and self.sound.premium and ns.Sounds.IsPremium()) then return pool end
    for _, file in ipairs(ns.Sounds.GetPremiumFiles()) do
        if ns.Sounds.IsPicked(self, file) then pool[#pool + 1] = ns.Sounds.PremiumSpec(file) end
    end
    return pool
end

-- Plays the feature's sound through the Master channel. Returns PlaySound(File)'s results.
-- With a pool of several sounds one is picked at random: never the same one twice in a row,
-- and a file that fails to play (missing) is skipped in favour of another.
function Feature:PlaySound()
    local pool = self:GetPool()
    if #pool == 1 then return ns.Sounds.Play(pool[1]) end

    local candidates = {}
    for _, spec in ipairs(pool) do
        if not ns.Sounds.Same(spec, self._lastSound) then candidates[#candidates + 1] = spec end
    end
    if #candidates == 0 then candidates = pool end

    while #candidates > 0 do
        local spec = table.remove(candidates, math.random(#candidates))
        local willPlay, handle = ns.Sounds.Play(spec)
        if willPlay ~= false then
            self._lastSound = spec
            return willPlay, handle
        end
    end
    return false
end

-- Hides everything that could keep running: timers, events, OnUpdate.
function Feature:Silence()
    for t in pairs(self._timers) do t:Cancel() end
    wipe(self._timers)
    for _, fr in ipairs(self._frames) do
        fr:UnregisterAllEvents()
        fr:SetScript("OnUpdate", nil)
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
local function call(f, method)
    if not f[method] then return end
    local ok, err = pcall(f[method], f)
    if not ok then report(method .. " [" .. f.key .. "]", err) end
end

local function Activate(f)
    if f.active then return end
    if f.class and f.class ~= ns.playerClass then return end
    f.active = true
    call(f, "OnEnable")
end

local function Deactivate(f)
    if not f.active then return end
    f.active = false
    f:Silence()
    call(f, "OnDisable")
end

-- Called once at PLAYER_LOGIN: start every feature whose option is on.
function ns:ActivateFeatures()
    ns.playerClass = select(2, UnitClass("player"))
    for _, f in ipairs(ns.featureList) do
        if CXUI_DB[f.key] == true then Activate(f) end
    end
end

-- Called by the options UI when a checkbox is clicked.
function ns:SetFeatureEnabled(key, value)
    CXUI_DB[key] = value and true or false
    local f = ns.featureByKey[key]
    if not f or f.reload then return end
    if CXUI_DB[key] then Activate(f) else Deactivate(f) end
end

function ns:SetChoice(key, value)
    CXUI_DB[key] = value
    for _, c in ipairs(ns.choiceList) do
        if c.key == key and c.onChange then
            local ok, err = pcall(c.onChange, value)
            if not ok then report("choice " .. key, err) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Sounds: playback + the list of sounds a player can pick from
-- spec = { kind = "file" (path or FileDataID) | "kit" (SoundKit ID), value = ..., name = ... }
-- ---------------------------------------------------------------------------
ns.Sounds = {}

function ns.Sounds.Play(spec)
    if not spec or spec.value == nil then return end
    if spec.kind == "kit" then
        return PlaySound(spec.value, "Master")
    end
    return PlaySoundFile(spec.value, "Master")
end

function ns.Sounds.Same(a, b)
    return a and b and a.kind == b.kind and a.value == b.value
end

-- Saves the player's choice for a feature (nil = back to the shipped default).
function ns.Sounds.SetChoice(feature, spec)
    CXUI_DB.soundChoices = CXUI_DB.soundChoices or {}
    if spec then
        CXUI_DB.soundChoices[feature.key] = { kind = spec.kind, value = spec.value, name = spec.name }
    else
        CXUI_DB.soundChoices[feature.key] = nil
    end
    if feature.OnSoundChanged then
        local ok, err = pcall(feature.OnSoundChanged, feature)
        if not ok then report("OnSoundChanged [" .. feature.key .. "]", err) end
    end
end

-- Every selectable sound, in display order: cxUI's own, SharedMedia, Blizzard.
-- Rebuilt on demand (other addons may register sounds late).
-- Entries: { name, source, kind, value }
function ns.Sounds.GetList(filesOnly)
    local list = {}

    -- 1. sounds shipped in media/ (each feature's default file)
    local mediaPrefix = ("Interface\\AddOns\\" .. ns.addonName .. "\\media\\"):lower()
    for _, f in ipairs(ns.featureList) do
        local d = f.sound
        if d and d.kind == "file" and type(d.value) == "string" and d.value:lower():find(mediaPrefix, 1, true) then
            list[#list + 1] = { name = f.name, source = "cxUI", kind = "file", value = d.value }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)

    -- 2. LibSharedMedia sounds (whatever the installed addons registered)
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local sm = {}
        for name, path in pairs(LSM:HashTable("sound")) do
            if name ~= "None" then sm[#sm + 1] = { name = name, source = "SharedMedia", kind = "file", value = path } end
        end
        table.sort(sm, function(a, b) return a.name:lower() < b.name:lower() end)
        for _, e in ipairs(sm) do list[#list + 1] = e end
    end

    -- 3. Blizzard sound kits (SOUNDKIT). Not usable where only files are allowed.
    if not filesOnly and _G.SOUNDKIT then
        local kits = {}
        for name, id in pairs(_G.SOUNDKIT) do
            if type(id) == "number" then kits[#kits + 1] = { name = name, source = "Blizzard", kind = "kit", value = id } end
        end
        table.sort(kits, function(a, b) return a.name < b.name end)
        for _, e in ipairs(kits) do list[#list + 1] = e end
    end

    return list
end

-- ---------------------------------------------------------------------------
-- Premium: per-feature random sound pools
-- /cx premium switches it on/off (CXUI_DB.premium). The sounds it can add live in
-- media/Premium/ and are registered by hand in modules/PremiumSounds.lua. Which of them
-- each feature uses is ticked in that feature's Premium window (sound picker) and stored
-- in CXUI_DB.premiumPicks[featureKey][fileName]. Turning Premium off keeps the ticks.
-- ---------------------------------------------------------------------------
local premiumSpecs = {} -- [fileName] = spec (cached)

function ns.Sounds.IsPremium()
    return CXUI_DB ~= nil and CXUI_DB.premium == true
end

function ns.Sounds.SetPremium(on)
    CXUI_DB.premium = on and true or false
    if ns.Sounds.onPremiumChanged then -- the options window hooks in here
        local ok, err = pcall(ns.Sounds.onPremiumChanged)
        if not ok then report("onPremiumChanged", err) end
    end
end

-- The registered file names (modules/PremiumSounds.lua), in order, without duplicates.
function ns.Sounds.GetPremiumFiles()
    local list, seen = {}, {}
    for _, file in ipairs(ns.Sounds.PremiumFiles or {}) do
        if type(file) == "string" and file ~= "" and not seen[file] then
            seen[file] = true
            list[#list + 1] = file
        end
    end
    return list
end

-- "Roar.ogg" -> "Roar"
function ns.Sounds.PremiumName(file)
    return (file:gsub("%.[oO][gG][gG]$", ""))
end

function ns.Sounds.PremiumSpec(file)
    local spec = premiumSpecs[file]
    if not spec then
        spec = { kind = "file", value = ns.Media("Premium", file), name = ns.Sounds.PremiumName(file) }
        premiumSpecs[file] = spec
    end
    return spec
end

function ns.Sounds.IsPicked(feature, file)
    local all = CXUI_DB and CXUI_DB.premiumPicks
    local picks = all and all[feature.key]
    return picks ~= nil and picks[file] == true
end

function ns.Sounds.SetPicked(feature, file, on)
    CXUI_DB.premiumPicks = CXUI_DB.premiumPicks or {}
    local picks = CXUI_DB.premiumPicks[feature.key]
    if not picks then
        picks = {}
        CXUI_DB.premiumPicks[feature.key] = picks
    end
    picks[file] = on and true or nil
end

SLASH_CXUI1 = "/cx"
SlashCmdList["CXUI"] = function(msg)
    local cmd = (msg or ""):match("^%s*(%S*)"):lower()
    if cmd ~= "premium" then
        ns.Print("Usage: /cx premium  (toggles the random Premium sounds)")
        return
    end

    local on = not ns.Sounds.IsPremium()
    ns.Sounds.SetPremium(on)
    if not on then
        ns.Print("Premium |cffff0000OFF|r")
        return
    end

    local files = ns.Sounds.GetPremiumFiles()
    ns.Print(("Premium |cff00ff00ON|r - registered files: %d"):format(#files))
    for _, file in ipairs(files) do
        print("   |cffffff00" .. ns.Sounds.PremiumName(file) .. "|r  (" .. file .. ")")
    end
    if #files == 0 then print("   none - add file names to modules/PremiumSounds.lua") end
end
