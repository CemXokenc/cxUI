local addonName, ns = ...

-- ===========================================================================
-- MODULE: EllesmereUI SKINS
-- Gives other addons the EllesmereUI look, using only the official skinning
-- API (EllesmereUI.RegisterSkin -> S.Shell / S.Button / S.ScrollBar ...,
-- see SKINNING_API.md in the EllesmereUI folder), and fixes known bugs of
-- those addons so their windows open at all.
--
--   EllesmereSkins.lua   this file: the module, shared helpers (ns.ESkin)
--   Compat.lua           named fixes (removed API functions, addon bugs)
--   FixAddonIssues.lua   the master checkbox that applies every fix
--   Skins/<Addon>.lua    one file per addon = one checkbox
--
-- A skin checkbox does two things for its addon: registers the skin with
-- EllesmereUI and applies the fixes that addon needs (so the window it is
-- skinning actually works). Everything is a no-op when the addon, EllesmereUI
-- or EllesmereUI Blizzard Skin+ is missing.
--
-- Skins can't be unregistered, so every checkbox here needs a reload.
-- EllesmereUI keeps the FIRST skin registered under a name: remove the old
-- skin packs (EUIAddonSkins, EllesmereUI_AddonSkins, EllesmereSkin_WIM,
-- Rematch_EllesmereUI_Skin) or they win over this module.
-- ===========================================================================

local ES = ns:NewModule("EllesmereSkins", {
    name  = "EllesmereUI Skins",
    desc  = "EllesmereUI styling for other addons, plus fixes for their bugs",
    order = 11,
    groups = {
        { id = "fixes", name = "Fixes" },
        { id = "skins", name = "Skins" },
    },
})

local Sk = {}
ns.ESkin = Sk
Sk.module = ES

local geterrorhandler, xpcall = geterrorhandler, xpcall

-- ---------------------------------------------------------------------------
-- Safety wrappers: an error in a skin is reported, never raised into the
-- addon being skinned.
-- ---------------------------------------------------------------------------
function Sk.Safe(fn)
    return function(...)
        -- the arguments go in through a closure: xpcall's own extra-argument
        -- form is not part of standard Lua 5.1
        local count, args = select("#", ...), { ... }
        xpcall(function() fn(unpack(args, 1, count)) end, geterrorhandler())
    end
end

function Sk.SafeHook(tbl, method, hook)
    if type(tbl) ~= "table" or type(tbl[method]) ~= "function" then return false end
    hooksecurefunc(tbl, method, Sk.Safe(hook))
    return true
end

-- ---------------------------------------------------------------------------
-- WhenLoaded: run fn once the addon is loaded (now, or on its ADDON_LOADED).
-- Does nothing for an addon that isn't installed.
-- ---------------------------------------------------------------------------
local waiting = {}   -- [addon] = { fn, ... }
local loader

local function IsLoaded(name)
    return C_AddOns and C_AddOns.IsAddOnLoaded(name) and true or false
end

local function Run(fn)
    xpcall(fn, geterrorhandler())
end

function Sk.WhenLoaded(name, fn)
    if IsLoaded(name) then Run(fn); return end
    if C_AddOns and C_AddOns.DoesAddOnExist and not C_AddOns.DoesAddOnExist(name) then return end
    waiting[name] = waiting[name] or {}
    table.insert(waiting[name], fn)
    if not loader then
        loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(_, _, loadedName)
            local list = waiting[loadedName]
            if not list then return end
            waiting[loadedName] = nil
            for _, fn2 in ipairs(list) do Run(fn2) end
        end)
    end
end

-- Hands `apply(S)` to EllesmereUI under the addon's own folder name, once that
-- addon is loaded (its frames must exist when the callback runs).
function Sk.Register(name, apply)
    if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end
    Sk.WhenLoaded(name, function() EllesmereUI.RegisterSkin(name, apply) end)
end

-- ---------------------------------------------------------------------------
-- Fixes: Sk.DefineFix(id, text, fn) in Compat.lua; Sk.ApplyFix(id) runs one
-- once. Every fix is idempotent and steps aside when it isn't needed.
-- ---------------------------------------------------------------------------
Sk.fixes, Sk.fixOrder, Sk.fixApplied = {}, {}, {}

function Sk.DefineFix(id, text, fn)
    Sk.fixes[id] = { text = text, fn = fn }
    Sk.fixOrder[#Sk.fixOrder + 1] = id
end

function Sk.ApplyFix(id)
    local fix = Sk.fixes[id]
    if not fix or Sk.fixApplied[id] then return end
    Sk.fixApplied[id] = true
    Run(fix.fn)
end

-- ---------------------------------------------------------------------------
-- NewSkin: one checkbox per addon.
--   addon  folder name (also the name EllesmereUI lists it under)
--   name   label (defaults to addon)
--   fixes  { "MouseIsOver", ... } fixes this addon needs
--   apply  function(S): the skin, called by EllesmereUI
--   run    function(): for a skin that doesn't go through EllesmereUI.RegisterSkin
--          (WIM's own skin system); called once the addon is loaded. May be
--          combined with apply.
--   key    feature key (defaults to "skin_<addon>")
-- ---------------------------------------------------------------------------
function Sk.NewSkin(info)
    local label = info.name or info.addon
    local F = ES:NewFeature{
        key    = info.key or ("skin_" .. info.addon),
        name   = label,
        desc   = info.desc or ("EllesmereUI style for " .. label),
        info   = info.info,
        reload = true,
        group  = "skins",
    }
    function F:OnEnable()
        for _, id in ipairs(info.fixes or {}) do Sk.ApplyFix(id) end
        -- run: a skin that hooks the addon's own skin system instead of EllesmereUI's
        if info.run then Sk.WhenLoaded(info.addon, info.run) end
        if info.apply then Sk.Register(info.addon, info.apply) end
    end
    return F
end

-- Vendored skins (WIM, Rematch) are other authors' files, unchanged apart from
-- being wrapped in a function so they can run once their addon has loaded.
-- Each wrapper file appends its function here; Sk.RunChunks calls them in
-- order with (name, sharedNamespace), the way the TOC loader would have.
Sk.chunks = {}
function Sk.RunChunks(group, addonLabel, shared)
    for _, chunk in ipairs(Sk.chunks[group] or {}) do
        xpcall(function() chunk(addonLabel, shared) end, geterrorhandler())
    end
end

-- ---------------------------------------------------------------------------
-- Shared skin helpers (built only from S primitives and plain WoW API)
-- ---------------------------------------------------------------------------
local function FadeTree(S, frame, keep)
    if keep[frame] then return end
    S.FadeRegions(frame)
    for _, child in ipairs({ frame:GetChildren() }) do FadeTree(S, child, keep) end
end

-- S.ScrollBar plus the art it misses on WowTrimScrollBar (trough and stepper
-- caps sit on child frames). The thumb is kept: it carries the house strip.
function Sk.SkinScrollBar(S, scrollBar)
    if not scrollBar then return end
    S.ScrollBar(scrollBar)
    local keep = {}
    local thumb = (scrollBar.Track and scrollBar.Track.Thumb) or (scrollBar.GetThumb and scrollBar:GetThumb())
    if thumb then keep[thumb] = true end
    FadeTree(S, scrollBar, keep)
end

-- One physical pixel in the region's own coordinate space.
function Sk.OnePixel(region)
    local _, height = GetPhysicalScreenSize()
    local scale = region:GetEffectiveScale()
    if not height or height <= 0 or not scale or scale < 0.1 or scale > 10 then return 1 end
    return 768 / height / scale
end

-- Lays a skinned tab out like EUI's own tab rows: 2px shorter (once), chained
-- to the previous tab's right edge with a 1px seam.
local laidOutTabs = setmetatable({}, { __mode = "k" })
function Sk.LayoutTab(tab, previous)
    if laidOutTabs[tab] then return end
    laidOutTabs[tab] = true
    local height = tab:GetHeight()
    if height and height > 2 then tab:SetHeight(height - 2) end
    if previous then
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", previous, "RIGHT", Sk.OnePixel(tab), 0)
    end
end

-- Gives a skinned tab room for its label (EUI's font is wider than Blizzard's).
-- Widens to the widest label plus padding on each side, now and on every OnShow.
local widenedTabs = setmetatable({}, { __mode = "k" })
local function FitTab(tab, padding)
    local widest = 0
    for _, region in ipairs({ tab:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local width = region.GetUnboundedStringWidth and region:GetUnboundedStringWidth() or region:GetStringWidth()
            if width and width > widest then widest = width end
        end
    end
    if widest > 0 and tab:GetWidth() < widest + 2 * padding then tab:SetWidth(widest + 2 * padding) end
end

function Sk.WidenTab(tab, padding)
    padding = padding or 16
    if not widenedTabs[tab] then
        widenedTabs[tab] = true
        tab:HookScript("OnShow", Sk.Safe(function(self) FitTab(self, padding) end))
    end
    FitTab(tab, padding)
end

-- A left-to-right row of tabs: S.Tab each, laid out as one strip.
function Sk.SkinTabRow(S, tabs)
    local previous
    for _, tab in ipairs(tabs) do
        S.Tab(tab)
        Sk.LayoutTab(tab, previous)
        previous = tab
    end
end

-- ---------------------------------------------------------------------------
-- WhenFrameCreated: run fn once the named global frame exists. For windows an
-- addon builds lazily inside a local function we can't hook. One shared
-- CreateFrame post-hook (installed on first use, a table lookup per call);
-- fn runs one frame after creation, when the builder has finished adding the
-- window's children.
-- ---------------------------------------------------------------------------
local wantedFrames = {}   -- [frameName] = { fn, ... }
local createHooked, pollTicker = false, nil

local function Fire(name)
    local list = wantedFrames[name]
    if not list then return end
    wantedFrames[name] = nil
    C_Timer.After(0, function()
        for _, fn in ipairs(list) do Run(fn) end
    end)
end

-- An addon that did `local CreateFrame = CreateFrame` before this module loaded keeps
-- the original function, and the hook below never sees its frames (WIM does this).
-- A once-a-second look at the names still wanted catches those; it stops by itself
-- when nothing is wanted any more.
local function Poll()
    for name in pairs(wantedFrames) do
        if _G[name] then Fire(name) end
    end
    if next(wantedFrames) == nil and pollTicker then
        pollTicker:Cancel()
        pollTicker = nil
    end
end

function Sk.WhenFrameCreated(name, fn)
    if _G[name] then Run(fn); return end
    wantedFrames[name] = wantedFrames[name] or {}
    table.insert(wantedFrames[name], fn)
    if not pollTicker then pollTicker = C_Timer.NewTicker(1, Poll) end
    if createHooked then return end
    createHooked = true
    hooksecurefunc("CreateFrame", function(_, frameName)
        if frameName and wantedFrames[frameName] then Fire(frameName) end
    end)
end

-- S.FadeRegions wants a frame; the art keys of other addons' templates are
-- sometimes a frame (PortraitContainer, Border) and sometimes a single
-- texture (InsetBg). A texture is simply made invisible.
function Sk.Fade(S, object)
    if not object then return end
    if object.GetRegions then
        S.FadeRegions(object)
    elseif object.SetAlpha then
        object:SetAlpha(0)
    end
end

-- ---------------------------------------------------------------------------
-- Standard-widget helpers. Blizzard's template names aren't visible at run
-- time, so stock widgets are recognised by their structure.
-- ---------------------------------------------------------------------------

-- InputBoxTemplate / SearchBoxTemplate. Some templates name their box art
-- <name>Left/Middle/Right instead of keying it, which S.EditBox misses.
function Sk.SkinEditBox(S, editBox)
    if not editBox then return end
    S.EditBox(editBox)
    local name = editBox:GetName()
    if name then
        for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
            local tex = _G[name .. suffix]
            if tex and tex.SetAlpha then tex:SetAlpha(0) end
        end
    end
    -- SearchBoxTemplate's magnifier is a region of the box, faded along with the art
    if editBox.searchIcon then editBox.searchIcon:SetAlpha(1) end
end

-- UIPanelButtonTemplate keys its three slices Left/Middle/Right, the
-- SharedButton*/three-slice templates Left/Center/Right.
local function IsPanelButton(frame)
    return frame:IsObjectType("Button") and frame.Left and frame.Right
        and (frame.Middle or frame.Center) and true or false
end
Sk.IsPanelButton = IsPanelButton

-- UICheckButtonTemplate and friends: the normal texture is Blizzard's
-- checkbox art (file path or atlas). Custom toggles don't match.
local function IsStockCheck(check)
    local tex = check.GetNormalTexture and check:GetNormalTexture()
    if not tex then return false end
    local path = tex.GetTexture and tex:GetTexture()
    if type(path) == "string" and path:lower():find("checkbox", 1, true) then return true end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    return type(atlas) == "string" and atlas:lower():find("checkbox", 1, true) and true or false
end
Sk.IsStockCheck = IsStockCheck

-- UIDropDownMenuTemplate (the legacy dropdown): keyed Left/Middle/Right/Text + Button.
-- Its frame is wider than the plate it draws (the art is inset on both sides,
-- the width is set per dropdown), so the flat box S.Dropdown draws around the
-- frame would stick out past the real edges. Only the plate is faded: the
-- text and the arrow button stay where the addon put them.
local function IsLegacyDropdown(frame)
    if frame.Left and frame.Middle and frame.Right and frame.Text and type(frame.Button) == "table" then
        return true
    end
    -- older / copied templates name the parts <name>Left / Middle / Right / Button
    local name = frame.GetName and frame:GetName()
    return name and _G[name .. "Left"] and _G[name .. "Middle"] and _G[name .. "Right"]
        and _G[name .. "Button"] and true or false
end

-- Removes the plate of a legacy dropdown, however its parts are reached.
local function FadeLegacyDropdown(S, frame)
    if frame.Left and frame.Middle and frame.Right then
        S.FadeRegions(frame)
        return
    end
    local name = frame:GetName()
    for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
        local part = name and _G[name .. suffix]
        if part and part.SetAlpha then part:SetAlpha(0) end
    end
end

-- What a widget is, by structure: "edit", "check", "dropdown", "legacyDropdown",
-- "tab", "button", "scroll" (a scroll bar), "scrollFrame" (a UIPanelScrollFrame), or nil
-- for anything that is not a stock widget. Second result: whether to look inside it.
function Sk.Classify(child)
    if child.IsForbidden and child:IsForbidden() then return nil, false end
    if child:IsObjectType("EditBox") then
        if child.IsMultiLine and child:IsMultiLine() then return nil, false end
        return "edit", false
    elseif child:IsObjectType("CheckButton") then
        if IsStockCheck(child) then return "check", false end
        return nil, true
    elseif child:IsObjectType("DropdownButton") or type(child.SetupMenu) == "function" then
        return "dropdown", false
    elseif child:IsObjectType("Button") and child.LeftActive and child.RightActive then
        return "tab", false                                   -- PanelTabButtonTemplate
    elseif IsPanelButton(child) then
        return "button", false
    elseif IsLegacyDropdown(child) then
        return "legacyDropdown", false
    elseif child.Track and child.Track.Thumb then
        return "scroll", false                                -- MinimalScrollBar / WowTrimScrollBar
    elseif child:IsObjectType("Slider") and child.ScrollUpButton and child.ScrollDownButton then
        return "scroll", false                                -- UIPanelScrollBarTemplate (AceGUI's)
    elseif child:IsObjectType("ScrollFrame") and child.ScrollBar and child.ScrollBar.ScrollUpButton then
        return "scrollFrame", true                            -- its scroll child still holds content
    end
    return nil, true
end

local KIND_FILTER = { legacyDropdown = "dropdown", scrollFrame = "scroll" }

-- Walks `root`'s descendants and skins the stock widgets it finds (see Sk.Classify).
-- Everything else (custom art, backdrops, icons, rows) is left alone. Never
-- descends into a widget it skinned. Every primitive is idempotent, so this is
-- safe to call again from OnShow or a refresh hook.
--
-- `only` (optional) limits the kinds: { button = true, check = true, edit = true,
-- dropdown = true, scroll = true, tab = true }. Without it every kind is skinned.
function Sk.SkinStandard(S, root, maxDepth, only)
    maxDepth = maxDepth or 6
    local function Want(kind)
        return not only or only[KIND_FILTER[kind] or kind] == true
    end

    local function Visit(frame, depth)
        for _, child in ipairs({ frame:GetChildren() }) do
            local kind, descend = Sk.Classify(child)
            if kind and Want(kind) then
                if kind == "edit" then
                    Sk.SkinEditBox(S, child)
                elseif kind == "check" then
                    S.Checkbox(child)
                    if child.Text then S.White(child.Text) end
                elseif kind == "dropdown" then
                    S.Dropdown(child)
                elseif kind == "tab" then
                    S.Tab(child)
                elseif kind == "button" then
                    S.Button(child)
                    S.StateButtonLabel(child)
                elseif kind == "legacyDropdown" then
                    FadeLegacyDropdown(S, child)
                elseif kind == "scroll" then
                    if child.Track then Sk.SkinScrollBar(S, child) else S.ScrollBar(child) end
                elseif kind == "scrollFrame" then
                    S.ScrollBar(child.ScrollBar)
                end
            end
            if descend and depth < maxDepth then Visit(child, depth + 1) end
        end
    end
    Visit(root, 1)
end

-- ---------------------------------------------------------------------------
-- FadeBackdrop: keeps a BackdropTemplate frame's own plate and edge invisible.
-- S.Shell / S.Panel fade the backdrop pieces (they are regions of the frame),
-- but every SetBackdrop / SetBackdropColor / SetBackdropBorderColor call
-- re-colours them, so a frame that re-applies its backdrop would show its old
-- edge again. The pieces are faded again after each such call. Once per frame.
-- ---------------------------------------------------------------------------
local BACKDROP_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}
local backdropFaded = setmetatable({}, { __mode = "k" })

function Sk.FadeBackdrop(frame)
    if not frame or backdropFaded[frame] then return end
    backdropFaded[frame] = true
    local function Fade()
        for _, key in ipairs(BACKDROP_PIECES) do
            local piece = frame[key]
            if piece and piece.SetAlpha then piece:SetAlpha(0) end
        end
    end
    Fade()
    for _, method in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" }) do
        Sk.SafeHook(frame, method, Fade)
    end
end
