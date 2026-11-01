local addonName, ns = ...
local M = ns.Macros
local UI, I = M.UI, M.Icons

-- ===========================================================================
-- ICON PICKER: search box + virtual scrolling grid. The grid only ever has
-- COLS x ROWS buttons; scrolling just changes which icons they show.
-- ===========================================================================

local P = {}
M.IconPicker = P

local COLS, ROWS, CELL, GAP = 10, 8, 40, 6
local AUTO = "auto"

local picker, search, status, slider, buttons
local list, defaultList, offset = {}, {}, 0
local current                       -- icon that is chosen right now (nil = auto)
local searchToken = 0
local updatingSlider = false

local function Refresh()
    local rows = math.ceil(#list / COLS)
    local maxOffset = math.max(0, rows - ROWS)
    if offset > maxOffset then offset = maxOffset end
    updatingSlider = true
    slider:SetMinMaxValues(0, maxOffset)
    slider:SetValue(offset)
    updatingSlider = false
    slider:SetShown(maxOffset > 0)

    for i = 1, COLS * ROWS do
        local b = buttons[i]
        local item = list[offset * COLS + i]
        if item then
            b.item = item
            if item == AUTO then
                b.icon:SetTexture(M.DEFAULT_ICON)
                b.tag:Show()
            else
                b.icon:SetTexture(item)
                b.tag:Hide()
            end
            b:SetSelected((item == AUTO and current == nil) or item == current)
            b:Show()
        else
            b.item = nil
            b:Hide()
        end
    end
end

local function SetStatus(count, searched)
    local state, frac = I.GetState()
    local text
    if searched then
        text = ("%d results"):format(count)
        if state ~= "done" then text = text .. ("  (indexing spells %d%%)"):format(frac * 100) end
    elseif state == "done" then
        text = "Type a spell name, a spell ID or a file ID"
    else
        text = ("Indexing spells for search... %d%%"):format(frac * 100)
    end
    status:SetText(text)
end

local function DoSearch()
    local text = search.edit:GetText()
    local results = I.Search(text)
    offset = 0
    if results then
        list = results
        SetStatus(#results, true)
    else
        list = { AUTO }
        for _, icon in ipairs(defaultList) do list[#list + 1] = icon end
        SetStatus(0, false)
    end
    Refresh()
end

local function Build(parent)
    picker = UI.Box(parent, { 0.05, 0.05, 0.07, 0.99 }, UI.BLUE)
    picker:SetSize(12 + COLS * CELL + (COLS - 1) * GAP + 10 + 10 + 12, 60 + 52 + ROWS * (CELL + GAP) + 10)
    picker:SetFrameStrata("DIALOG")
    picker:SetToplevel(true)
    picker:EnableMouse(true)
    picker:Hide()

    local title = UI.Text(picker, UI.SIZE_TITLE, UI.BLUE)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Choose icon")

    local close = UI.Button(picker, "Close", 64, 24, UI.YELLOW)
    close:SetPoint("TOPRIGHT", -10, -8)
    close:SetScript("OnClick", function() picker:Hide() end)

    search = UI.EditBox(picker, 280, 26)
    search:SetPoint("TOPLEFT", 12, -42)
    search.edit:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then return end
        searchToken = searchToken + 1
        local token = searchToken
        C_Timer.After(0.25, function()
            if token == searchToken and picker:IsShown() then DoSearch() end
        end)
    end)

    status = UI.Text(picker, UI.SIZE_SMALL, UI.GRAY)
    status:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", picker, "RIGHT", -12, 0)

    local grid = CreateFrame("Frame", nil, picker)
    grid:SetPoint("TOPLEFT", 12, -92)
    grid:SetSize(COLS * CELL + (COLS - 1) * GAP, ROWS * (CELL + GAP) - GAP)
    grid:EnableMouseWheel(true)

    slider = UI.Slider(picker, grid:GetHeight())
    slider:SetPoint("TOPLEFT", grid, "TOPRIGHT", 10, 0)
    slider:SetScript("OnValueChanged", function(_, value)
        if updatingSlider then return end
        offset = math.floor(value + 0.5)
        Refresh()
    end)
    grid:SetScript("OnMouseWheel", function(_, delta)
        local _, maxV = slider:GetMinMaxValues()
        local new = math.min(maxV, math.max(0, offset - delta * 2))
        if new ~= offset then offset = new; Refresh() end
    end)

    buttons = {}
    for i = 1, COLS * ROWS do
        local b = UI.IconButton(grid, CELL)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        b:SetPoint("TOPLEFT", col * (CELL + GAP), -row * (CELL + GAP))
        b.tag = UI.Text(b, UI.SIZE_SMALL, UI.YELLOW, "OVERLAY")
        b.tag:SetPoint("BOTTOM", 0, 3)
        b.tag:SetJustifyH("CENTER")
        b.tag:SetText("auto")
        b:SetScript("OnClick", function(self)
            local item = self.item
            if item == nil then return end
            local cb = picker.onPick
            picker:Hide()
            if cb then cb(item ~= AUTO and item or nil) end
        end)
        UI.SetTip(b, function(tip)
            local item = b.item
            if item == AUTO then
                tip:AddLine("Automatic icon", 1, 1, 0)
                tip:AddLine("With #showtooltip the game shows the icon of the spell the macro would cast.", 1, 1, 1, true)
            elseif type(item) == "number" then
                tip:AddLine("Icon " .. item, 1, 1, 0)
                local names = I.GetNames(item)
                if names then tip:AddLine((names:gsub("|", ", ")), 1, 1, 1, true) end
            else
                tip:AddLine(tostring(item), 1, 1, 1)
            end
        end)
        buttons[i] = b
    end

    I.onProgress = function(_, done)
        if not picker or not picker:IsShown() then return end
        local text = search.edit:GetText()
        if done and #M.Trim(text) >= 2 then
            DoSearch()
        else
            SetStatus(#list, #M.Trim(text) >= 2)
        end
    end
end

-- anchor: the frame to centre on (the macro window). onPick(icon | nil for automatic)
function P.Open(anchor, currentIcon, onPick)
    if not picker then Build(anchor) end
    picker.onPick = onPick
    current = currentIcon
    picker:ClearAllPoints()
    picker:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    defaultList = I.GetDefaultList()
    search.edit:SetText("")
    DoSearch()
    picker:Show()
    picker:Raise()
    I.StartIndexing()
end

function P.Close()
    if picker then picker:Hide() end
end
