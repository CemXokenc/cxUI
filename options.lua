local addonName, ns = ...

-- ===========================================================================
-- OPTIONS: the cxUI settings window
--
--   Home page    title + one big button per module
--   Module page  module list on the left, that module's options on the right
--                (every option = 2 rows: "[x] Name" / short description)
--
-- Everything is generated from the module registry (modules/Modules.lua):
-- add a module or feature there and it shows up here automatically.
-- ===========================================================================

-- Layout / style ------------------------------------------------------------
local FONT_BOOST      = 4                 -- menu text is 4px larger than Blizzard's defaults
local FONT            = STANDARD_TEXT_FONT
local SIZE_TITLE      = 16 + FONT_BOOST   -- GameFontNormalLarge + 4
local SIZE_NAME       = 12 + FONT_BOOST   -- option / sidebar label
local SIZE_DESC       = 10 + FONT_BOOST   -- option description
local SIZE_BTN_NAME   = 30                -- home page module button: name
local SIZE_BTN_DESC   = 20                -- home page module button: description

local BLUE   = { 0, 0.44, 0.87 }          -- |cff0070dd
local YELLOW = { 1, 1, 0 }                -- |cffffff00
local GRAY   = { 0.72, 0.72, 0.72 }

local SIDEBAR_WIDTH  = 175
local BTN_PADDING    = 15
local BTN_WIDTH_FRAC = 0.70
local BTN_GAP        = 12
local ROW_GAP        = 12
local PAGE_PAD       = 8

local function SetFont(fs, size)
    fs:SetFont(FONT, size, "")
end

local function NewText(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK")
    SetFont(fs, size)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

-- Panel ----------------------------------------------------------------------
local panel = CreateFrame("Frame", "CXUI_OptionsPanel", UIParent)
panel.name = "cxUI"

local title = NewText(panel, SIZE_TITLE, nil)
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff0070ddCem Xokenc |cffffff00UI|r")

local reloadButton = CreateFrame("Button", nil, panel, "BackdropTemplate, UIPanelButtonTemplate")
reloadButton:SetSize(140, 30)
reloadButton:SetPoint("BOTTOMLEFT", 16, 16)
reloadButton:SetText("Reload UI")
SetFont(reloadButton:GetFontString(), SIZE_NAME)
reloadButton:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
reloadButton:SetBackdropColor(0.5, 0.1, 0.1, 1)
reloadButton:SetScript("OnClick", ReloadUI)

-- Area between the title and the reload button
local function NewArea()
    local area = CreateFrame("Frame", nil, panel)
    area:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -45)
    area:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 55)
    area:Hide()
    return area
end

local homeArea = NewArea()
local moduleArea = NewArea()

local function NewScroll(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    return scroll, content
end

local function ScrollWidth(scroll)
    local w = scroll:GetWidth()
    if not w or w < 50 then w = 420 end
    return w
end

-- State ------------------------------------------------------------------------
local pages = {}          -- [moduleID] = page
local sidebarButtons = {} -- [moduleID or "home"] = button
local checkboxes = {}     -- every checkbox, for state refresh
local currentID = "home"
local homeBuilt = false
local ShowPage

-- Checkbox widgets -----------------------------------------------------------------
local function NewCheck(parent, name, reload, tooltipTitle, tooltipText)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    SetFont(check.Text, SIZE_NAME)
    check.Text:SetText(name .. (reload and " |cffff0000(Requires Reload)*|r" or ""))
    if tooltipText then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipTitle, 1, 1, 1)
            GameTooltip:AddLine(tooltipText, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return check
end

-- Every widget below returns { frame = Frame, layout = function(width) -> height }

local function BuildFeatureRow(content, feature)
    local row = CreateFrame("Frame", nil, content)
    local check = NewCheck(row, feature.name, feature.reload, feature.name, feature.info)
    check:SetPoint("TOPLEFT", 0, 0)
    check:SetScript("OnClick", function(self)
        ns:SetFeatureEnabled(feature.key, self:GetChecked() and true or false)
    end)
    checkboxes[#checkboxes + 1] = { frame = check, key = feature.key }

    local desc = NewText(row, SIZE_DESC, GRAY)
    desc:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 2)
    desc:SetText(feature.desc)

    return { frame = row, layout = function(width)
        desc:SetWidth(width - 34)
        local height = 24 + desc:GetStringHeight()
        row:SetSize(width, height)
        check:SetHitRectInsets(0, -(width - 30), 0, -(desc:GetStringHeight() + 2)) -- whole row is clickable
        return height
    end }
end

local function BuildChoiceRow(content, choice)
    local group = CreateFrame("Frame", nil, content)

    local head = NewText(group, SIZE_NAME, YELLOW)
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetText(choice.name .. ":")

    local options = {}
    for _, opt in ipairs(choice.choices) do
        local o = {}
        o.check = NewCheck(group, opt.name, false, opt.name, opt.desc)
        o.desc = NewText(group, SIZE_DESC, GRAY)
        o.desc:SetText(opt.desc)
        o.value = opt.value
        o.check:SetScript("OnClick", function(self)
            if CXUI_DB[choice.key] == opt.value then
                self:SetChecked(true) -- a radio can't be unchecked by clicking it again
                return
            end
            ns:SetChoice(choice.key, opt.value)
            for _, other in ipairs(options) do other.check:SetChecked(other.value == opt.value) end
        end)
        checkboxes[#checkboxes + 1] = { frame = o.check, key = choice.key, radioValue = opt.value }
        options[#options + 1] = o
    end

    return { frame = group, layout = function(width)
        local y = head:GetStringHeight() + 6
        for _, o in ipairs(options) do
            o.check:ClearAllPoints()
            o.check:SetPoint("TOPLEFT", group, "TOPLEFT", 12, -y)
            o.desc:ClearAllPoints()
            o.desc:SetPoint("TOPLEFT", o.check, "BOTTOMLEFT", 30, 2)
            o.desc:SetWidth(width - 46)
            o.check:SetHitRectInsets(0, -(width - 42), 0, -(o.desc:GetStringHeight() + 2))
            y = y + 24 + o.desc:GetStringHeight() + 8
        end
        group:SetSize(width, y)
        return y
    end }
end

local function BuildNote(content, text)
    local holder = CreateFrame("Frame", nil, content)
    local fs = NewText(holder, SIZE_DESC, nil)
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetText(text)
    return { frame = holder, layout = function(width)
        fs:SetWidth(width)
        local h = fs:GetStringHeight()
        holder:SetSize(width, h)
        return h
    end }
end

-- Module page ------------------------------------------------------------------------
local function BuildPage(mod)
    local scroll, content = NewScroll(moduleArea, "CXUI_Page_" .. mod.id)
    scroll:SetPoint("TOPLEFT", moduleArea, "TOPLEFT", SIDEBAR_WIDTH + 10, 0)
    scroll:SetPoint("BOTTOMRIGHT", moduleArea, "BOTTOMRIGHT", -22, 0)
    scroll:Hide()

    local items = {}

    -- Header: module name + description
    local header = CreateFrame("Frame", nil, content)
    local hTitle = NewText(header, SIZE_TITLE, BLUE)
    hTitle:SetPoint("TOPLEFT", 0, 0)
    hTitle:SetText(mod.name)
    local hDesc = NewText(header, SIZE_DESC, YELLOW)
    hDesc:SetPoint("TOPLEFT", hTitle, "BOTTOMLEFT", 0, -4)
    hDesc:SetText(mod.desc)
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.2)
    line:SetHeight(1)
    items[1] = { frame = header, layout = function(width)
        hDesc:SetWidth(width)
        local h = hTitle:GetStringHeight() + 4 + hDesc:GetStringHeight() + 8
        header:SetSize(width, h)
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
        return h
    end }

    for _, entry in ipairs(mod:GetEntries()) do
        if entry.kind == "feature" then
            items[#items + 1] = BuildFeatureRow(content, entry)
        elseif entry.kind == "choice" then
            items[#items + 1] = BuildChoiceRow(content, entry)
        elseif entry.kind == "note" then
            items[#items + 1] = BuildNote(content, entry.text)
        end
    end

    local page = { scroll = scroll, content = content }
    function page.layout()
        local width = ScrollWidth(scroll) - PAGE_PAD * 2
        local y = PAGE_PAD
        for _, item in ipairs(items) do
            item.frame:ClearAllPoints()
            item.frame:SetPoint("TOPLEFT", content, "TOPLEFT", PAGE_PAD, -y)
            y = y + item.layout(width) + ROW_GAP
        end
        content:SetSize(width + PAGE_PAD * 2, y + PAGE_PAD)
    end
    scroll:SetScript("OnSizeChanged", function() if scroll:IsShown() then page.layout() end end)
    return page
end

-- Sidebar ----------------------------------------------------------------------------------
local function BuildSidebar()
    local function AddButton(id, label, y, onClick)
        local btn = CreateFrame("Button", nil, moduleArea)
        btn:SetSize(SIDEBAR_WIDTH, 30)
        btn:SetPoint("TOPLEFT", moduleArea, "TOPLEFT", 0, -y)
        btn.text = NewText(btn, SIZE_NAME, nil)
        btn.text:SetPoint("LEFT", 10, 0)
        btn.text:SetText(label)
        btn.selected = btn:CreateTexture(nil, "BACKGROUND")
        btn.selected:SetAllPoints()
        btn.selected:SetColorTexture(0, 0.44, 0.87, 0.25)
        btn.selected:Hide()
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        btn:SetScript("OnClick", onClick)
        sidebarButtons[id] = btn
        return btn
    end

    AddButton("home", "< Home", 0, function() ShowPage("home") end)
    local y = 38
    for _, mod in ipairs(ns.modules) do
        AddButton(mod.id, mod.name, y, function() ShowPage(mod.id) end)
        y = y + 32
    end
end

-- Home page --------------------------------------------------------------------------------
local homeScroll, homeContent = NewScroll(homeArea, "CXUI_HomeScroll")
homeScroll:SetPoint("TOPLEFT", homeArea, "TOPLEFT", 0, 0)
homeScroll:SetPoint("BOTTOMRIGHT", homeArea, "BOTTOMRIGHT", -22, 0)

local homeButtons = {}

local function BuildHome()
    for _, mod in ipairs(ns.modules) do
        local btn = CreateFrame("Button", nil, homeContent, "BackdropTemplate")
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.07, 0.07, 0.09, 0.9)
        btn:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

        btn.name = NewText(btn, SIZE_BTN_NAME, BLUE)
        btn.name:SetPoint("TOPLEFT", BTN_PADDING, -BTN_PADDING)
        btn.name:SetText(mod.name)

        btn.desc = NewText(btn, SIZE_BTN_DESC, YELLOW)
        btn.desc:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -6)
        btn.desc:SetText(mod.desc)

        btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0, 0.44, 0.87, 1); self:SetBackdropColor(0.1, 0.12, 0.18, 0.95) end)
        btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.25, 0.25, 0.3, 1); self:SetBackdropColor(0.07, 0.07, 0.09, 0.9) end)
        btn:SetScript("OnClick", function() ShowPage(mod.id) end)
        homeButtons[#homeButtons + 1] = btn
    end
end

local function LayoutHome()
    local width = ScrollWidth(homeScroll)
    local btnWidth = math.floor(width * BTN_WIDTH_FRAC)
    local x = math.floor((width - btnWidth) / 2)
    local y = BTN_GAP
    for _, btn in ipairs(homeButtons) do
        btn.desc:SetWidth(btnWidth - BTN_PADDING * 2)
        btn.name:SetWidth(btnWidth - BTN_PADDING * 2)
        local height = BTN_PADDING + btn.name:GetStringHeight() + 6 + btn.desc:GetStringHeight() + BTN_PADDING
        btn:SetSize(btnWidth, height)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", homeContent, "TOPLEFT", x, -y)
        y = y + height + BTN_GAP
    end
    homeContent:SetSize(width, y)
end
homeScroll:SetScript("OnSizeChanged", function() if homeScroll:IsShown() then LayoutHome() end end)

-- Navigation ---------------------------------------------------------------------------------
local function RefreshCheckboxes()
    if not CXUI_DB then return end
    for _, cb in ipairs(checkboxes) do
        if cb.radioValue ~= nil then
            cb.frame:SetChecked(CXUI_DB[cb.key] == cb.radioValue)
        else
            cb.frame:SetChecked(CXUI_DB[cb.key] == true)
        end
    end
end

function ShowPage(id)
    if not homeBuilt then
        homeBuilt = true
        BuildHome()
        BuildSidebar()
    end
    currentID = id

    for _, page in pairs(pages) do page.scroll:Hide() end

    if id == "home" then
        moduleArea:Hide()
        homeArea:Show()
        LayoutHome()
        return
    end

    homeArea:Hide()
    moduleArea:Show()
    for bid, btn in pairs(sidebarButtons) do
        local selected = (bid == id)
        btn.selected:SetShown(selected)
        if selected then btn.text:SetTextColor(BLUE[1], BLUE[2], BLUE[3]) else btn.text:SetTextColor(1, 1, 1) end
    end

    local mod = ns.moduleByID[id]
    if not pages[id] then pages[id] = BuildPage(mod) end
    pages[id].scroll:Show()
    pages[id].layout()
    pages[id].scroll:SetVerticalScroll(0)
    RefreshCheckboxes()
end

panel:HookScript("OnShow", function()
    ShowPage(currentID)
end)

-- The Settings window doesn't always give a fresh hidden->shown transition, so
-- while the panel is visible, keep the checkboxes in sync on a slow timer.
-- (Nothing runs while the panel is closed.)
local refreshTicker
panel:HookScript("OnShow", function()
    if not refreshTicker then
        refreshTicker = C_Timer.NewTicker(1, function()
            if panel:IsShown() then RefreshCheckboxes() end
        end)
    end
end)
panel:HookScript("OnHide", function()
    if refreshTicker then refreshTicker:Cancel(); refreshTicker = nil end
end)

-- Settings API registration ---------------------------------------------------------------
local function RegisterSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
    end
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        C_Timer.After(0.5, RegisterSettings)
    end
end)
