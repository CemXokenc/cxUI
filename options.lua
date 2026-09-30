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
local SIZE_BTN_NAME   = 21                -- home page module button: name (two columns, 30 * 0.7)
local SIZE_BTN_DESC   = 14                -- home page module button: description (20 * 0.7)

-- cxUI palette: blue, yellow, white, red (+ class colours). Blizzard's own gold
-- and grey are mapped onto these (see Palettize).
local BLUE   = { 0, 0.44, 0.87 }          -- |cff0070dd
local YELLOW = { 1, 1, 0 }                -- |cffffff00
local WHITE  = { 1, 1, 1 }
local RED    = { 1, 0, 0 }                -- |cffff0000

local SIDEBAR_WIDTH  = 175
local BTN_PAD_TOP    = 5     -- inner padding of a home button (top / bottom)
local BTN_PAD_LEFT   = 10    -- inner padding of a home button (left / right)
local TITLE_MARGIN   = 20    -- space between the title and the content below it
local BTN_COLUMNS    = 2
local BTN_GAP        = 6     -- space between home buttons
local SUB_INDENT     = 16    -- sidebar submenu indent
local CHECK_MARGIN   = 3     -- space between a checkbox and its label
local CHECK_SIZE     = 26
local TEXT_INDENT    = CHECK_SIZE + CHECK_MARGIN -- where labels / descriptions start
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

-- Flat dark rectangle with a blue border on hover (module buttons, Reload UI)
local function StyleFlat(btn)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.07, 0.07, 0.09, 0.9)
    btn:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0, 0.44, 0.87, 1)
        self:SetBackdropColor(0.1, 0.12, 0.18, 0.95)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
        self:SetBackdropColor(0.07, 0.07, 0.09, 0.9)
    end)
end

local function NewFlatButton(parent, label, width, height, color)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    StyleFlat(btn)
    btn.text = NewText(btn, SIZE_DESC, color or WHITE)
    btn.text:SetPoint("CENTER")
    btn.text:SetJustifyH("CENTER")
    btn.text:SetText(label)
    return btn
end

-- Reload UI: same row as the title, right side
local reloadButton = CreateFrame("Button", nil, panel, "BackdropTemplate")
reloadButton:SetSize(110, 26)
reloadButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -13)
StyleFlat(reloadButton)
reloadButton.text = NewText(reloadButton, SIZE_NAME, YELLOW)
reloadButton.text:SetPoint("CENTER")
reloadButton.text:SetJustifyH("CENTER")
reloadButton.text:SetText("Reload UI")
reloadButton:SetScript("OnClick", ReloadUI)

-- Area below the title row
local function NewArea()
    local area = CreateFrame("Frame", nil, panel)
    area:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -11, -TITLE_MARGIN)
    area:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 10)
    area:Hide()
    return area
end

local homeArea = NewArea()
local moduleArea = NewArea()

local function NewScroll(parent, name, hideBar)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    if hideBar then
        -- invisible and unclickable; alpha (not Hide) because the template re-shows the bar itself
        local bar = scroll.ScrollBar
        if type(bar) ~= "table" then bar = _G[name .. "ScrollBar"] end
        if type(bar) == "table" then
            bar:SetAlpha(0)
            bar:EnableMouse(false)
            for _, b in ipairs({ bar.ScrollUpButton, bar.ScrollDownButton }) do
                if type(b) == "table" and b.EnableMouse then b:EnableMouse(false) end
            end
        end
    end
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
local pages = {}          -- [pageKey] = page   (pageKey = moduleID or moduleID..":"..groupID)
local sidebarButtons = {} -- [pageKey or "home"] = button
local checkboxes = {}     -- every checkbox, for state refresh
local currentID = "home"
local currentGroup = {}   -- [moduleID] = selected submenu id
local homeBuilt = false
local ShowPage


-- Sound picker ---------------------------------------------------------------------------------
local ROW_H = 28
local picker                       -- built on first use
local pickerFeature, pickerList, pickerFiltered = nil, {}, {}
local premiumWin, premiumFeature       -- Premium window (built on first use) and the feature it edits
local OpenPremiumWindow                -- defined below, next to the checkbox widgets it reuses

-- The picker's Premium button: only for features flagged `sound.premium`, and only while /cx premium is on.
local function UpdatePremiumButton()
    if not picker then return end
    local show = pickerFeature and pickerFeature.sound and pickerFeature.sound.premium and ns.Sounds.IsPremium()
    picker.premium:SetShown(show and true or false)
    if not show and premiumWin then premiumWin:Hide() end
end

local function SoundLabel(spec)
    return (spec and spec.name) or "?"
end

local function PickerRefresh()
    if not picker or not picker:IsShown() then return end
    local scroll, content = picker.scroll, picker.content
    local offset = math.floor((scroll:GetVerticalScroll() or 0) / ROW_H)
    local current = pickerFeature and pickerFeature:GetSound()
    content:SetHeight(math.max(#pickerFiltered * ROW_H, 1))
    for i, row in ipairs(picker.rows) do
        local entry = pickerFiltered[offset + i]
        if entry then
            row.entry = entry
            row.label:SetText(entry.name .. (entry.source and ("  |cffffff00[" .. entry.source .. "]|r") or ""))
            row.selected:SetShown(ns.Sounds.Same(entry, current))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(offset + i - 1) * ROW_H)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(offset + i - 1) * ROW_H)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function PickerFilter()
    local query = (picker.search:GetText() or ""):lower()
    wipe(pickerFiltered)
    -- entry 1 is always "Default" so the shipped sound can be restored
    for _, entry in ipairs(pickerList) do
        if query == "" or entry.default or entry.name:lower():find(query, 1, true) or (entry.source or ""):lower():find(query, 1, true) then
            pickerFiltered[#pickerFiltered + 1] = entry
        end
    end
    picker.count:SetText(#pickerFiltered - 1 .. " sounds")
    picker.scroll:SetVerticalScroll(0)
    PickerRefresh()
end

local function BuildPicker()
    picker = CreateFrame("Frame", "CXUI_SoundPicker", UIParent, "BackdropTemplate")
    picker:SetSize(460, 520)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetToplevel(true)
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    picker:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    picker:SetBackdropBorderColor(0, 0.44, 0.87, 1)
    picker:Hide()
    tinsert(UISpecialFrames, "CXUI_SoundPicker") -- ESC closes it

    picker.title = NewText(picker, SIZE_TITLE, BLUE)
    picker.title:SetPoint("TOPLEFT", 14, -12)

    local close = NewFlatButton(picker, "Close", 70, 26, YELLOW)
    close:SetPoint("TOPRIGHT", -12, -10)
    close:SetScript("OnClick", function() picker:Hide() end)

    picker.premium = NewFlatButton(picker, "Premium", 84, 26, BLUE)
    picker.premium:SetPoint("RIGHT", close, "LEFT", -6, 0)
    picker.premium:SetScript("OnClick", function()
        if pickerFeature then OpenPremiumWindow(pickerFeature) end
    end)
    picker.premium:Hide()
    picker:SetScript("OnHide", function() if premiumWin then premiumWin:Hide() end end)

    picker.subtitle = NewText(picker, SIZE_DESC, WHITE)
    picker.subtitle:SetPoint("TOPLEFT", picker.title, "BOTTOMLEFT", 0, -4)

    local searchLabel = NewText(picker, SIZE_DESC, YELLOW)
    searchLabel:SetPoint("TOPLEFT", picker.subtitle, "BOTTOMLEFT", 0, -12)
    searchLabel:SetText("Search:")

    picker.search = CreateFrame("EditBox", "CXUI_SoundPickerSearch", picker, "InputBoxTemplate")
    picker.search:SetSize(240, 22)
    picker.search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
    picker.search:SetAutoFocus(false)
    picker.search:SetFont(FONT, SIZE_DESC, "")
    picker.search:SetScript("OnTextChanged", PickerFilter)
    picker.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    picker.count = NewText(picker, SIZE_DESC, WHITE)
    picker.count:SetPoint("LEFT", picker.search, "RIGHT", 12, 0)

    picker.scroll, picker.content = NewScroll(picker, "CXUI_SoundPickerScroll")
    picker.scroll:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -12)
    picker.scroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -32, 12)
    picker.content:SetWidth(400)
    picker.scroll:HookScript("OnVerticalScroll", PickerRefresh)
    picker.scroll:SetScript("OnSizeChanged", function(self, w)
        picker.content:SetWidth(w or 400)
    end)

    -- Only as many rows as fit on screen; they are re-filled while scrolling.
    picker.rows = {}
    for i = 1, math.ceil(520 / ROW_H) + 1 do
        local row = CreateFrame("Frame", nil, picker.content)
        row:SetHeight(ROW_H)
        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetAllPoints()
        row.selected:SetColorTexture(0, 0.44, 0.87, 0.25)
        row.play = NewFlatButton(row, "Play", 46, 22, BLUE)
        row.play:SetPoint("LEFT", 4, 0)
        row.play:SetScript("OnClick", function()
            if type(row.entry) ~= "table" then return end
            ns.Sounds.Play(row.entry.default and pickerFeature.sound or row.entry)
        end)
        row.set = NewFlatButton(row, "Set", 46, 22, YELLOW)
        row.set:SetPoint("RIGHT", -4, 0)
        row.set:SetScript("OnClick", function()
            if type(row.entry) ~= "table" then return end
            ns.Sounds.SetChoice(pickerFeature, (not row.entry.default) and row.entry or nil)
            PickerRefresh()
        end)
        row.label = NewText(row, SIZE_DESC, WHITE)
        row.label:SetPoint("LEFT", row.play, "RIGHT", 8, 0)
        row.label:SetPoint("RIGHT", row.set, "LEFT", -8, 0)
        row.label:SetWordWrap(false)
        row.label:SetJustifyV("MIDDLE")
        picker.rows[i] = row
    end
end

local function OpenSoundPicker(feature)
    if not picker then BuildPicker() end
    pickerFeature = feature
    if premiumWin then premiumWin:Hide() end
    UpdatePremiumButton()
    picker.title:SetText("Choose sound")
    picker.subtitle:SetText(feature.name)

    pickerList = { { name = "Default (" .. SoundLabel(feature.sound) .. ")", default = true } }
    for _, entry in ipairs(ns.Sounds.GetList(feature.sound and feature.sound.filesOnly)) do
        pickerList[#pickerList + 1] = entry
    end
    picker.search:SetText("")
    picker:Show()
    picker:Raise()
    PickerFilter()
end

panel:HookScript("OnHide", function() if picker then picker:Hide() end end)

-- Checkbox widgets -----------------------------------------------------------------
-- Blizzard gold -> our yellow, Blizzard grey/white -> our white
local function Palettize(fs)
    local r, g, b = fs:GetTextColor()
    if type(r) ~= "number" then return end
    if r > 0.9 and g > 0.6 and g < 0.95 and b < 0.3 then
        fs:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
    else
        fs:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
    end
end

local function NewCheck(parent, name, reload, tooltipTitle, tooltipText)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    SetFont(check.Text, SIZE_NAME)
    Palettize(check.Text)
    check.Text:ClearAllPoints()
    check.Text:SetPoint("LEFT", check, "RIGHT", CHECK_MARGIN, 0)
    check.Text:SetText(name .. (reload and " |cffff0000(Requires Reload)*|r" or ""))
    if tooltipText then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipTitle, WHITE[1], WHITE[2], WHITE[3])
            GameTooltip:AddLine(tooltipText, YELLOW[1], YELLOW[2], YELLOW[3], true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return check
end

-- Premium window -------------------------------------------------------------------
-- Opened from the sound picker's Premium button: one checkbox per file registered in
-- modules/PremiumSounds.lua. Ticks are stored per feature (CXUI_DB.premiumPicks) and
-- take effect immediately; the feature's own sound is always part of its pool.
local function NewPremiumRow(i)
    local content = premiumWin.content
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)

    row.play = NewFlatButton(row, "Play", 46, 22, BLUE)
    row.play:SetPoint("LEFT", 4, 0)
    row.play:SetScript("OnClick", function()
        if row.file then ns.Sounds.Play(ns.Sounds.PremiumSpec(row.file)) end
    end)

    row.check = NewCheck(row, "", false)
    row.check:SetPoint("LEFT", row.play, "RIGHT", 8, 0)
    row.check.Text:SetWidth(240)
    row.check.Text:SetWordWrap(false)
    row.check:SetScript("OnClick", function(self)
        if row.file and premiumFeature then
            ns.Sounds.SetPicked(premiumFeature, row.file, self:GetChecked() and true or false)
        end
    end)

    premiumWin.rows[i] = row
    return row
end

local function BuildPremiumWindow()
    local win = CreateFrame("Frame", "CXUI_PremiumPicker", UIParent, "BackdropTemplate")
    win:SetSize(420, 380)
    win:SetPoint("TOPLEFT", picker, "TOPRIGHT", 6, 0) -- rides along with the picker
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    win:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    win:SetBackdropBorderColor(0, 0.44, 0.87, 1)
    win:Hide()
    tinsert(UISpecialFrames, "CXUI_PremiumPicker") -- ESC closes it

    local title = NewText(win, SIZE_TITLE, BLUE)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Random sounds")

    local close = NewFlatButton(win, "Close", 70, 26, YELLOW)
    close:SetPoint("TOPRIGHT", -12, -10)
    close:SetScript("OnClick", function() win:Hide() end)

    win.subtitle = NewText(win, SIZE_DESC, WHITE)
    win.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local hint = NewText(win, SIZE_DESC, YELLOW)
    hint:SetPoint("TOPLEFT", win.subtitle, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(390)
    hint:SetWordWrap(true)
    hint:SetText("Ticked sounds join the random pool together with the sound chosen for this feature.")

    win.scroll, win.content = NewScroll(win, "CXUI_PremiumPickerScroll")
    win.scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    win.scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -32, 12)
    win.content:SetWidth(340)
    win.scroll:SetScript("OnSizeChanged", function(_, w) win.content:SetWidth(w or 340) end)

    win.empty = NewText(win, SIZE_DESC, WHITE)
    win.empty:SetPoint("TOP", win.scroll, "TOP", 0, -20)
    win.empty:SetWidth(340)
    win.empty:SetJustifyH("CENTER")
    win.empty:SetText("No Premium sounds registered.\nAdd file names to modules/PremiumSounds.lua")
    win.empty:Hide()

    win.rows = {}
    premiumWin = win
end

OpenPremiumWindow = function(feature)
    if not premiumWin then BuildPremiumWindow() end
    premiumFeature = feature
    premiumWin.subtitle:SetText(feature.name)

    local files = ns.Sounds.GetPremiumFiles()
    for i, file in ipairs(files) do
        local row = premiumWin.rows[i] or NewPremiumRow(i)
        row.file = file
        row.check.Text:SetText(ns.Sounds.PremiumName(file))
        row.check:SetChecked(ns.Sounds.IsPicked(feature, file))
        row:Show()
    end
    for i = #files + 1, #premiumWin.rows do
        premiumWin.rows[i].file = nil
        premiumWin.rows[i]:Hide()
    end
    premiumWin.content:SetHeight(math.max(#files * ROW_H, 1))
    premiumWin.empty:SetShown(#files == 0)
    premiumWin:Show()
    premiumWin:Raise()
end

-- /cx premium toggled: show/hide the picker's Premium button (and close the window when it goes off)
ns.Sounds.onPremiumChanged = UpdatePremiumButton

-- Every widget below returns { frame = Frame, layout = function(width) -> height }

local function BuildFeatureRow(content, feature)
    local row = CreateFrame("Frame", nil, content)
    local check = NewCheck(row, feature.name, feature.reload, feature.name, feature.info)
    check:SetPoint("TOPLEFT", 0, 0)
    check:SetScript("OnClick", function(self)
        ns:SetFeatureEnabled(feature.key, self:GetChecked() and true or false)
    end)
    checkboxes[#checkboxes + 1] = { frame = check, key = feature.key }

    -- Features with a configurable sound: Play + Change at the right end of the name line
    local reserve = 0
    if feature.sound then
        local change = NewFlatButton(row, "Change", 66, 22, YELLOW)
        change:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2)
        local play = NewFlatButton(row, "Play", 46, 22, BLUE)
        play:SetPoint("RIGHT", change, "LEFT", -6, 0)
        -- above the checkbox, whose click area spans the whole row
        change:SetFrameLevel(check:GetFrameLevel() + 5)
        play:SetFrameLevel(check:GetFrameLevel() + 5)
        play:SetScript("OnClick", function() feature:PlaySound() end)
        change:SetScript("OnClick", function() OpenSoundPicker(feature) end)
        local function tip(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Current sound", WHITE[1], WHITE[2], WHITE[3])
            GameTooltip:AddLine(SoundLabel(feature:GetSound()), YELLOW[1], YELLOW[2], YELLOW[3], true)
            GameTooltip:Show()
        end
        for _, b in ipairs({ play, change }) do
            b:HookScript("OnEnter", tip)
            b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        reserve = 66 + 6 + 46 + 8
    end

    local desc = NewText(row, SIZE_DESC, WHITE)
    desc:SetPoint("TOPLEFT", check, "BOTTOMLEFT", TEXT_INDENT, 2)
    desc:SetText(feature.desc)

    return { frame = row, layout = function(width)
        desc:SetWidth(width - TEXT_INDENT - 4)
        local height = 24 + desc:GetStringHeight()
        row:SetSize(width, height)
        check:SetHitRectInsets(0, -(width - TEXT_INDENT - reserve), 0, -(desc:GetStringHeight() + 2)) -- whole row is clickable, minus the buttons
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
        o.desc = NewText(group, SIZE_DESC, WHITE)
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
            o.desc:SetPoint("TOPLEFT", o.check, "BOTTOMLEFT", TEXT_INDENT, 2)
            o.desc:SetWidth(width - TEXT_INDENT - 16)
            o.check:SetHitRectInsets(0, -(width - TEXT_INDENT - 12), 0, -(o.desc:GetStringHeight() + 2))
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
local function BuildPage(mod, group)
    local scroll, content = NewScroll(moduleArea, "CXUI_Page_" .. mod.id .. (group and ("_" .. group.id) or ""), true)
    scroll:SetPoint("TOPLEFT", moduleArea, "TOPLEFT", SIDEBAR_WIDTH + 10, 0)
    scroll:SetPoint("BOTTOMRIGHT", moduleArea, "BOTTOMRIGHT", 0, 0)
    scroll:Hide()

    local items = {}

    -- Header: module name + description
    local header = CreateFrame("Frame", nil, content)
    local hTitle = NewText(header, SIZE_TITLE, BLUE)
    hTitle:SetPoint("TOPLEFT", 0, 0)
    hTitle:SetText(group and (mod.name .. " \226\128\148 " .. group.name) or mod.name)
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

    for _, entry in ipairs(mod:GetEntries(group and group.id)) do
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
local function PlayerClass() return select(2, UnitClass("player")) end

local function DefaultGroup(mod)
    local mine = PlayerClass()
    for _, g in ipairs(mod.groups) do
        if g.id == mine then return g.id end
    end
    return mod.groups[1].id
end

local function BuildSidebar()
    local y = 0
    local function AddButton(key, label, indent, color, onClick)
        local btn = CreateFrame("Button", nil, moduleArea)
        btn:SetSize(SIDEBAR_WIDTH - indent, 28)
        btn:SetPoint("TOPLEFT", moduleArea, "TOPLEFT", indent, -y)
        btn.text = NewText(btn, SIZE_NAME, nil)
        btn.text:SetPoint("LEFT", 10, 0)
        btn.text:SetText(label)
        btn.color = color
        btn.selected = btn:CreateTexture(nil, "BACKGROUND")
        btn.selected:SetAllPoints()
        btn.selected:SetColorTexture(0, 0.44, 0.87, 0.25)
        btn.selected:Hide()
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        btn:SetScript("OnClick", onClick)
        sidebarButtons[key] = btn
        y = y + 30
        return btn
    end

    AddButton("home", "<- Home", 0, nil, function() ShowPage("home") end)
    y = y + 8
    for _, mod in ipairs(ns.modules) do
        AddButton(mod.id, mod.name, 0, nil, function() ShowPage(mod.id) end)
        for _, g in ipairs(mod.groups or {}) do
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[g.id]
            AddButton(mod.id .. ":" .. g.id, g.name, SUB_INDENT, c and { c.r, c.g, c.b } or nil,
                function() ShowPage(mod.id, g.id) end)
        end
    end
end

-- Home page --------------------------------------------------------------------------------
local homeScroll, homeContent = NewScroll(homeArea, "CXUI_HomeScroll", true)
homeScroll:SetPoint("TOPLEFT", homeArea, "TOPLEFT", 0, 0)
homeScroll:SetPoint("BOTTOMRIGHT", homeArea, "BOTTOMRIGHT", 0, 0)

local homeButtons = {}

local function BuildHome()
    for _, mod in ipairs(ns.modules) do
        local btn = CreateFrame("Button", nil, homeContent, "BackdropTemplate")
        StyleFlat(btn)

        btn.name = NewText(btn, SIZE_BTN_NAME, BLUE)
        btn.name:SetPoint("TOPLEFT", BTN_PAD_LEFT, -BTN_PAD_TOP)
        btn.name:SetText(mod.name)

        btn.desc = NewText(btn, SIZE_BTN_DESC, YELLOW)
        btn.desc:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -3)
        btn.desc:SetText(mod.desc)

        btn:SetScript("OnClick", function() ShowPage(mod.id) end)
        homeButtons[#homeButtons + 1] = btn
    end
end

local function LayoutHome()
    local width = ScrollWidth(homeScroll)
    local btnWidth = math.floor((width - BTN_GAP * (BTN_COLUMNS - 1)) / BTN_COLUMNS)
    local y = 0
    for first = 1, #homeButtons, BTN_COLUMNS do
        -- every button in a row gets the height of the tallest one
        local rowHeight = 0
        for i = first, math.min(first + BTN_COLUMNS - 1, #homeButtons) do
            local btn = homeButtons[i]
            btn.name:SetWidth(btnWidth - BTN_PAD_LEFT * 2)
            btn.desc:SetWidth(btnWidth - BTN_PAD_LEFT * 2)
            -- whole pixels only: a fractional height puts later rows on half pixels
            -- and the 1px top border of those buttons disappears
            local h = math.ceil(BTN_PAD_TOP + btn.name:GetStringHeight() + 3 + btn.desc:GetStringHeight() + BTN_PAD_TOP)
            if h > rowHeight then rowHeight = h end
        end
        for i = first, math.min(first + BTN_COLUMNS - 1, #homeButtons) do
            local btn = homeButtons[i]
            local column = i - first
            btn:SetSize(btnWidth, rowHeight)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", homeContent, "TOPLEFT", column * (btnWidth + BTN_GAP), -y)
        end
        y = y + rowHeight + BTN_GAP
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

function ShowPage(id, groupID)
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

    local mod = ns.moduleByID[id]
    local group
    if mod.groups then
        currentGroup[id] = groupID or currentGroup[id] or DefaultGroup(mod)
        for _, g in ipairs(mod.groups) do
            if g.id == currentGroup[id] then group = g end
        end
    end
    local key = id .. (group and (":" .. group.id) or "")

    homeArea:Hide()
    moduleArea:Show()
    for bkey, btn in pairs(sidebarButtons) do
        btn.selected:SetShown(bkey == key)
        local c = btn.color
        if type(c) == "table" then
            -- submenu item: only the background marks the selection, the class colour stays
            btn.text:SetTextColor(c[1], c[2], c[3])
        elseif bkey == key or bkey == id then
            btn.text:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
        else
            btn.text:SetTextColor(1, 1, 1)
        end
    end

    if not pages[key] then pages[key] = BuildPage(mod, group) end
    pages[key].scroll:Show()
    pages[key].layout()
    pages[key].scroll:SetVerticalScroll(0)
    RefreshCheckboxes()
end

panel:HookScript("OnShow", function()
    ShowPage(currentID, currentGroup[currentID])
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
