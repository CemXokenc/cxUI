local addonName, ns = ...

-- ===========================================================================
-- SKIN: Addon settings pages (the Blizzard AddOns tab)
-- One checkbox for every addon that keeps its settings on a page of the Game
-- Menu > Options > AddOns tab (a "canvas" page: the addon's own frame, shown
-- inside Blizzard's options window; Ace3 option pages are of this kind). On
-- those pages the stock Blizzard widgets are skinned: panel buttons, stock
-- checkboxes, edit boxes, dropdowns, tabs and scroll bars. Addons with their
-- own settings window (Plumber) or with settings built from Blizzard's own
-- controls (the "vertical layout" pages) are not affected, and nothing of
-- Blizzard's own panel is touched: EllesmereUI skins that window's frame, and
-- the controls inside its lists stay stock on purpose (taint).
--
-- How the page is found: every way of choosing a category in the panel ends in
-- SettingsPanel:SetCurrentCategory(category). The category object does not hold
-- the addon's frame directly, it is a few tables down (category -> layout ->
-- frame), so the object is searched breadth-first, shallowest frame first,
-- never through the links back to a parent category or the category set, and a
-- few getters are tried as a second chance. A category with no frame in it is
-- skipped. `/esk page` prints what was found for the page on screen.
--
-- The page is skinned when it is chosen, when it is shown, and, while the
-- options window is open, every half second (an Ace page rebuilds its widgets
-- whenever one of its options changes, and the new widgets must not come out
-- stock).
-- ===========================================================================

local Sk = ns.ESkin

local TICK = 0.5
local MAX_DEPTH = 10
local SEARCH_DEPTH = 4
local SKIP_KEYS = { parentCategory = true, categorySet = true, parent = true, owner = true, categoryList = true }
local GETTERS = { "GetFrame", "GetCanvas", "GetCanvasFrame" }

local function IsFrame(value)
    if type(value) ~= "table" or type(value.IsObjectType) ~= "function" or type(value.HookScript) ~= "function" then
        return false
    end
    local ok, isFrame = pcall(value.IsObjectType, value, "Frame")
    return ok and isFrame and not (value.IsForbidden and value:IsForbidden()) and true or false
end

local function Getter(object, panel)
    for _, name in ipairs(GETTERS) do
        if type(object[name]) == "function" then
            local ok, value = pcall(object[name], object)
            if ok and value ~= panel and IsFrame(value) then return value end
        end
    end
end

-- Returns the page frame and how it was found (for /esk page).
function Sk.FindSettingsPage(category)
    if type(category) ~= "table" then return nil end
    local panel = _G.SettingsPanel
    local seen, level = { [category] = true }, { category }
    for depth = 1, SEARCH_DEPTH do
        local nextLevel = {}
        for _, tbl in ipairs(level) do
            for key, value in pairs(tbl) do
                if type(value) == "table" and not SKIP_KEYS[key] and not seen[value] then
                    seen[value] = true
                    if IsFrame(value) then
                        if value ~= panel then return value, "field '" .. tostring(key) .. "' at depth " .. depth end
                    else
                        nextLevel[#nextLevel + 1] = value
                    end
                end
            end
        end
        level = nextLevel
    end
    local frame = Getter(category, panel)
    if frame then return frame, "getter on the category" end
    local layout = category.layout
    if not layout and type(category.GetLayout) == "function" then
        local ok, value = pcall(category.GetLayout, category)
        layout = ok and value or nil
    end
    if type(layout) == "table" then
        frame = Getter(layout, panel)
        if frame then return frame, "getter on the layout" end
    end
    return nil
end

Sk.NewSkin{
    key   = "skin_AddonSettingsPages",
    addon = "cxUI",
    name  = "Addon settings pages",
    desc  = "Blizzard widgets (buttons, edit boxes, dropdowns, tabs, scroll bars) on addon pages of the AddOns options tab",
    apply = function(S)
        Sk.WhenLoaded("Blizzard_Settings", function()
            local panel = _G.SettingsPanel
            if not panel then return end

            local current, hooked, ticker = nil, {}, nil
            Sk.currentSettingsCategory = nil

            local function SkinPage(page)
                Sk.SkinStandard(S, page, MAX_DEPTH)
            end

            local function Choose(category)
                Sk.currentSettingsCategory = category
                local page = Sk.FindSettingsPage(category)
                current = page
                if not page then return end
                if not hooked[page] then
                    hooked[page] = true
                    page:HookScript("OnShow", Sk.Safe(function() SkinPage(page) end))
                end
                SkinPage(page)
                -- Ace builds its widgets when the page is first shown
                C_Timer.After(0, function() if current == page then SkinPage(page) end end)
            end

            Sk.SafeHook(panel, "SetCurrentCategory", function(_, category) Choose(category) end)

            -- while the options window is open, keep rebuilt widgets skinned
            local function Start()
                if ticker then return end
                ticker = C_Timer.NewTicker(TICK, function()
                    if current and current:IsVisible() then SkinPage(current) end
                end)
            end
            local function Stop()
                if ticker then ticker:Cancel(); ticker = nil end
            end
            panel:HookScript("OnShow", Sk.Safe(Start))
            panel:HookScript("OnHide", Sk.Safe(Stop))
            if panel:IsShown() then Start() end
        end)
    end,
}
