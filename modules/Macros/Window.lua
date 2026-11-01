local addonName, ns = ...
local M = ns.Macros
local UI = M.UI
local S = M.Slots

-- ===========================================================================
-- WINDOW
--   [General][Class][Spec][Character][Archive]        <- scope tabs
--   [class icons .................]                    <- Class / Spec tabs
--   [spec buttons]                                      <- Spec tab
--   [character names]                                   <- Character tab
--   slot grid (left)              editor (right)
-- Everything you browse can be edited; only what belongs to the character you
-- are playing right now is also written to the native macro slots.
-- ===========================================================================

local W = {}
M.Window = W

local COLS, CELL, GAP = 8, 40, 6
local GRID_W   = COLS * CELL + (COLS - 1) * GAP            -- 362
local EDITOR_H = 362
local WIN_W    = 800
local INNER_W  = WIN_W - 24                                  -- 776
local EDITOR_W = INNER_W - GRID_W - 18                       -- 396
local BODY_H   = 190
local TAB_W    = 118

local frame, tabs, strips, grid, editor, footer
local classButtons, specButtons, charButtons, slotButtons = {}, {}, {}, {}
local nameBox, bodyEdit, bodyHL, bodyCaret, bodyHint, counter, iconBtn
local btn = {}                       -- save, revert, delete, copy, cut, paste, import, adopt
local banner, header, statusLine

local state = {
    scope = "general", classFile = nil, specID = nil, guid = nil,
    slot = nil, dirty = false, editIcon = nil, clip = nil, confirmDelete = false,
}

-- ---------------------------------------------------------------------------
-- State helpers
-- ---------------------------------------------------------------------------
local function CurrentKey()
    local s = state.scope
    if s == "class" then return state.classFile
    elseif s == "spec" then return state.specID
    elseif s == "char" then return state.guid end
    return nil
end

local function NeedsKey() local s = state.scope; return s == "class" or s == "spec" or s == "char" end

local function KeyReady() return (not NeedsKey()) or CurrentKey() ~= nil end

local function ClassByFile(file)
    for _, c in ipairs(M.GetClassList()) do if c.file == file then return c end end
end

local function SpecsOfState()
    local c = ClassByFile(state.classFile)
    return c and M.GetSpecList(c.id) or {}
end

local function PickDefaultSpec(ctx)
    local specs = SpecsOfState()
    if state.classFile == ctx.classFile and ctx.specID then
        for _, s in ipairs(specs) do if s.id == ctx.specID then return s.id end end
    end
    return specs[1] and specs[1].id or nil
end

local function EnsureState()
    local ctx = M.GetContext()
    state.classFile = state.classFile or ctx.classFile
    state.guid = state.guid or ctx.guid
    if not state.specID then state.specID = PickDefaultSpec(ctx) end
    return ctx
end

local function SetStatus(text, color)
    if not statusLine then return end
    color = color or UI.GRAY
    statusLine:SetTextColor(color[1], color[2], color[3])
    statusLine:SetText(text or "")
end

local function Record() return state.slot and KeyReady() and M.GetRecord(state.scope, CurrentKey(), state.slot) or nil end

-- ---------------------------------------------------------------------------
-- Editor buttons / header
-- ---------------------------------------------------------------------------
local function ScopeSubject()
    local s = state.scope
    if s == "class" then local c = ClassByFile(state.classFile); return c and c.name or "?"
    elseif s == "spec" then
        for _, sp in ipairs(SpecsOfState()) do if sp.id == state.specID then return sp.name end end
        return "?"
    elseif s == "char" then
        local e = M.DB().char[state.guid]; return e and e.name or "?"
    end
    return M.scopeByKey[s].label
end

local function IsActiveBrowse(ctx)
    local sc = M.scopeByKey[state.scope]
    return sc.bound and KeyReady() and S.IsActive(state.scope, CurrentKey(), ctx or M.GetContext())
end

local function UpdateHeader()
    if not header then return end
    local sc = M.scopeByKey[state.scope]
    local subject = ScopeSubject()
    local line = (sc.label == subject) and sc.label or (sc.label .. " - " .. subject)
    if state.slot then line = line .. "  |  slot " .. state.slot end
    local tag
    if not sc.bound then tag = "|cff9999aastorage only|r"
    elseif IsActiveBrowse() then tag = "|cff00ff00active|r"
    else tag = "|cff9999aanot active (editing only)|r" end
    header:SetText(line .. "   " .. tag)
end

local function UpdateButtons()
    if not frame then return end
    local rec = Record()
    btn.save:SetEnabled(state.dirty)
    btn.revert:SetEnabled(state.dirty)
    btn.delete:SetEnabled(rec ~= nil)
    btn.copy:SetEnabled(rec ~= nil)
    btn.cut:SetEnabled(rec ~= nil)
    btn.paste:SetEnabled(state.clip ~= nil and rec == nil and KeyReady())
    if not state.confirmDelete then btn.delete:SetLabel("Delete") end
    UpdateHeader()
end

local function MarkDirty()
    if not state.dirty then
        state.dirty = true
        state.confirmDelete = false
        UpdateButtons()
    end
end

-- ---------------------------------------------------------------------------
-- Grid
-- ---------------------------------------------------------------------------
local function RefreshGrid()
    if not frame then return end
    local sc = M.scopeByKey[state.scope]
    local key = CurrentKey()
    local bucket = KeyReady() and M.GetBucket(state.scope, key, false) or nil
    local ctx = M.GetContext()
    local active = IsActiveBrowse(ctx)
    for i = 1, #slotButtons do
        local b = slotButtons[i]
        if i <= sc.count then
            b:Show()
            local rec = bucket and bucket[i]
            if rec then
                local icon = rec.icon
                if not icon and active then
                    local idx = S.GetNativeIndex(sc.first + i)
                    if idx then icon = select(2, GetMacroInfo(idx)) end
                end
                b.icon:SetTexture(icon or M.DEFAULT_ICON)
                b.icon:SetAlpha(active and 1 or 0.5)
                b.label:SetText(rec.name)
                b.text:SetText("")
            else
                b.icon:SetColorTexture(0.1, 0.1, 0.14, 1)
                b.icon:SetAlpha(1)
                b.label:SetText("")
                b.text:SetText(KeyReady() and "+" or "")
                b.text:SetTextColor(0.5, 0.5, 0.58)
            end
            b:SetSelected(i == state.slot)
        else
            b:Hide()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Editor load / save
-- ---------------------------------------------------------------------------
local function LoadEditor()
    local rec = Record()
    nameBox.edit:SetText(rec and rec.name or "")
    bodyEdit:SetText(rec and rec.body or "")
    state.editIcon = rec and rec.icon or nil
    iconBtn.icon:SetTexture(state.editIcon or M.DEFAULT_ICON)
    state.dirty = false
    state.confirmDelete = false
    UpdateButtons()
end

local function SaveCurrent()
    if not state.slot or not state.dirty then return end
    if not KeyReady() then state.dirty = false; return end
    local scope, key, slot = state.scope, CurrentKey(), state.slot
    local name = M.Trim(nameBox.edit:GetText())
    local body = bodyEdit:GetText()
    state.dirty = false

    if name == "" and M.Trim(body) == "" then
        M.SetRecord(scope, key, slot, nil)
    else
        if name == "" then name = "Macro" end
        M.SetRecord(scope, key, slot, { name = M.Utf8Sub(name, M.NAME_MAX), icon = state.editIcon, body = body })
    end
    local result = S.ApplySlot(scope, key, slot)
    if result == "queued" then
        SetStatus("In combat: the macro will be written to your action slots when combat ends.", UI.YELLOW)
    elseif result == "applied" then
        SetStatus("Saved and applied.", UI.GRAY)
    else
        SetStatus("Saved.", UI.GRAY)
    end
    RefreshGrid()
    UpdateButtons()
end

local function SelectSlot(slot)
    SaveCurrent()
    state.slot = slot
    LoadEditor()
    RefreshGrid()
end

local function FirstUsedSlot()
    local sc = M.scopeByKey[state.scope]
    local bucket = KeyReady() and M.GetBucket(state.scope, CurrentKey(), false)
    if bucket then
        for i = 1, sc.count do if bucket[i] then return i end end
    end
    return 1
end

-- ---------------------------------------------------------------------------
-- Strips (class / spec / character) and layout
-- ---------------------------------------------------------------------------
local function Flow(items, startY, gap)
    local x, y, rowH = 0, startY, 0
    for _, b in ipairs(items) do
        local w = b:GetWidth()
        if x > 0 and x + w > INNER_W then
            x = 0
            y = y - rowH - gap
            rowH = 0
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", strips, "TOPLEFT", x, y)
        x = x + w + gap
        rowH = math.max(rowH, b:GetHeight())
    end
    return -y + rowH
end

local function EnsureStripButtons()
    if #classButtons == 0 then
        for _, c in ipairs(M.GetClassList()) do
            local b = UI.IconButton(strips, 34)
            UI.SetClassIcon(b.icon, c.file)
            b.class = c
            b.me = b:CreateTexture(nil, "OVERLAY")
            b.me:SetColorTexture(1, 1, 0, 1)
            b.me:SetSize(8, 3)
            b.me:SetPoint("BOTTOM", 0, 1)
            b:SetScript("OnClick", function(self)
                SaveCurrent()
                state.classFile = self.class.file
                state.specID = PickDefaultSpec(M.GetContext())
                state.slot = nil
                W.Rebuild(true)
            end)
            UI.SetTip(b, function(tip)
                local r, g, bl = M.ClassColor(c.file)
                tip:AddLine(c.name, r, g, bl)
                if c.file == M.GetContext().classFile then tip:AddLine("Your class", 1, 1, 0) end
            end)
            classButtons[#classButtons + 1] = b
        end
    end
    while #specButtons < 5 do
        local b = UI.Button(strips, "", 140, 30)
        b.sicon = b:CreateTexture(nil, "ARTWORK")
        b.sicon:SetSize(24, 24)
        b.sicon:SetPoint("LEFT", 4, 0)
        b.sicon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", b.sicon, "RIGHT", 6, 0)
        b.text:SetPoint("RIGHT", -6, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b.me = b:CreateTexture(nil, "OVERLAY")
        b.me:SetColorTexture(1, 1, 0, 1)
        b.me:SetSize(3, 14)
        b.me:SetPoint("RIGHT", -1, 0)
        b:SetScript("OnClick", function(self)
            SaveCurrent()
            state.specID = self.spec.id
            state.slot = nil
            W.Rebuild(true)
        end)
        specButtons[#specButtons + 1] = b
    end
end

local function Layout()
    EnsureStripButtons()
    local ctx = M.GetContext()
    for _, b in ipairs(classButtons) do b:Hide() end
    for _, b in ipairs(specButtons) do b:Hide() end
    for _, b in ipairs(charButtons) do b:Hide() end

    local h = 0
    local scope = state.scope
    if scope == "class" or scope == "spec" then
        local shown = {}
        for _, b in ipairs(classButtons) do
            b:Show()
            b:SetSelected(b.class.file == state.classFile)
            b.icon:SetAlpha(b.class.file == state.classFile and 1 or 0.55)
            b.me:SetShown(b.class.file == ctx.classFile)
            shown[#shown + 1] = b
        end
        h = Flow(shown, 0, 4)
    end
    if scope == "spec" then
        local shown = {}
        for i, spec in ipairs(SpecsOfState()) do
            local b = specButtons[i]
            if b then
                b.spec = spec
                b.sicon:SetTexture(spec.icon)
                b:SetLabel(spec.name)
                b:SetSelected(spec.id == state.specID)
                b.me:SetShown(spec.id == ctx.specID)
                b:Show()
                shown[#shown + 1] = b
            end
        end
        -- second row under the class icons
        local x = 0
        for _, b in ipairs(shown) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", strips, "TOPLEFT", x, -(h + 6))
            x = x + b:GetWidth() + 4
        end
        if #shown > 0 then h = h + 6 + shown[1]:GetHeight() end
    end
    if scope == "char" then
        local list = M.GetCharacterList()
        local shown = {}
        for i, c in ipairs(list) do
            local b = charButtons[i]
            if not b then
                b = UI.Button(strips, "", 150, 26)
                b.text:SetWordWrap(false)
                b.text:SetWidth(138)
                b:SetScript("OnClick", function(self)
                    SaveCurrent()
                    state.guid = self.guid
                    state.slot = nil
                    W.Rebuild(true)
                end)
                charButtons[i] = b
            end
            b.guid = c.guid
            local r, g, bl = M.ClassColor(c.class or "")
            b.text:SetTextColor(r, g, bl)
            b:SetLabel(c.name .. (c.guid == ctx.guid and "  *" or ""))
            b:SetSelected(c.guid == state.guid)
            b:Show()
            shown[#shown + 1] = b
        end
        h = #shown > 0 and Flow(shown, 0, 4) or 0
    end

    strips:SetHeight(math.max(h, 1))
    local stripGap = h > 0 and 12 or 0
    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", strips, "BOTTOMLEFT", 0, -stripGap)
    editor:ClearAllPoints()
    editor:SetPoint("TOPLEFT", strips, "BOTTOMLEFT", GRID_W + 18, -stripGap)
    frame:SetHeight(86 + math.max(h, 1) + stripGap + EDITOR_H + 56)
end

local function RefreshTabs()
    for _, t in ipairs(tabs) do t:SetSelected(t.scope == state.scope) end
end

local function RefreshTools()
    local managingReason = M.ManagingReason and M.ManagingReason()
    banner:SetText(managingReason and ("|cffff0000" .. managingReason .. "|r") or "")
    btn.import:SetShown(_G.MegaMacroGlobalData ~= nil)
    local untagged = (not InCombatLockdown()) and M.CountUntagged() or 0
    btn.adopt:SetShown(untagged > 0 and not M.IsAddOnLoaded("MegaMacro"))
    btn.adopt:SetLabel(("Adopt %d native"):format(untagged))
end

function W.Rebuild(selectFirst)
    if not frame or not frame:IsShown() then return end
    EnsureState()
    Layout()
    RefreshTabs()
    if selectFirst or not state.slot then state.slot = FirstUsedSlot() end
    RefreshGrid()
    LoadEditor()
    RefreshTools()
end

-- Called after a sync / import. Keeps unsaved edits by saving them first.
function W.Refresh()
    if not frame or not frame:IsShown() then return end
    SaveCurrent()
    W.Rebuild(false)
end

-- ---------------------------------------------------------------------------
-- Building the frame
-- ---------------------------------------------------------------------------
local function BuildBody(parent)
    local box = UI.Box(parent)
    box:SetSize(EDITOR_W, BODY_H)

    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    scroll:EnableMouseWheel(true)

    local viewH = BODY_H - 12
    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFont(UI.FONT, 13, "")
    eb:SetTextColor(1, 1, 1, 0)          -- the real text is invisible; the coloured copy below is drawn instead
    eb:SetTextInsets(0, 0, 0, 0)
    eb:SetSpacing(2)
    eb:SetMaxLetters(M.BODY_MAX)
    eb:SetSize(EDITOR_W - 12, viewH)
    scroll:SetScrollChild(eb)

    local hl = eb:CreateFontString(nil, "ARTWORK")
    hl:SetFont(UI.FONT, 13, "")
    hl:SetSpacing(2)
    hl:SetJustifyH("LEFT")
    hl:SetJustifyV("TOP")
    hl:SetPoint("TOPLEFT")
    hl:SetPoint("TOPRIGHT")

    -- own caret: does not depend on how the client colours its native one
    local caret = eb:CreateTexture(nil, "OVERLAY")
    caret:SetColorTexture(1, 1, 1, 0.9)
    caret:SetSize(1, 14)
    caret:Hide()
    local blink, focused = 0, false

    local hint = UI.Text(box, 13, { 0.4, 0.4, 0.46 })
    hint:SetPoint("TOPLEFT", 6, -6)
    hint:SetText("#showtooltip\n/cast [@mouseover,help,nodead] Spell; Other Spell")

    local count = UI.Text(parent, UI.SIZE_SMALL, UI.GRAY)

    local function Update(self, userInput)
        local text = self:GetText()
        hl:SetText(M.Highlight(text))
        eb:SetHeight(math.max(viewH, hl:GetStringHeight() + 6))
        local len = strlenutf8 and strlenutf8(text) or #text
        count:SetText(("%d/%d"):format(len, M.BODY_MAX))
        count:SetTextColor(len >= M.BODY_MAX and 1 or 0.6, len >= M.BODY_MAX and 0 or 0.6, len >= M.BODY_MAX and 0 or 0.66)
        hint:SetShown(text == "" and not focused)
        if userInput then MarkDirty() end
    end
    eb:SetScript("OnTextChanged", Update)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnCursorChanged", function(_, x, y, _, h)
        caret:ClearAllPoints()
        caret:SetPoint("TOPLEFT", eb, "TOPLEFT", x, y)
        caret:SetHeight(h > 0 and h or 14)
        blink = 0
        -- keep the caret inside the visible part
        local top, bottom = -y, -y + h
        local cur = scroll:GetVerticalScroll()
        if top < cur then scroll:SetVerticalScroll(top)
        elseif bottom > cur + viewH then scroll:SetVerticalScroll(bottom - viewH) end
    end)
    eb:SetScript("OnEditFocusGained", function()
        focused = true; caret:Show(); hint:Hide()
        box:SetBackdropBorderColor(UI.BLUE[1], UI.BLUE[2], UI.BLUE[3], 1)
    end)
    eb:SetScript("OnEditFocusLost", function()
        focused = false; caret:Hide()
        hint:SetShown(eb:GetText() == "")
        box:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)
    end)
    eb:SetScript("OnUpdate", function(_, elapsed)
        if not focused then return end
        blink = blink + elapsed
        caret:SetAlpha((blink % 1) < 0.55 and 1 or 0)
    end)
    scroll:SetScript("OnMouseDown", function() eb:SetFocus() end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, eb:GetHeight() - viewH)
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 26)))
    end)

    bodyEdit, bodyHL, bodyCaret, bodyHint, counter = eb, hl, caret, hint, count
    return box
end

local function BuildEditor()
    editor = CreateFrame("Frame", nil, frame)
    editor:SetSize(EDITOR_W, EDITOR_H)

    header = UI.Text(editor, UI.SIZE, UI.YELLOW)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("RIGHT", editor, "RIGHT", 0, 0)
    header:SetWordWrap(false)

    iconBtn = UI.IconButton(editor, 44)
    iconBtn:SetPoint("TOPLEFT", 0, -26)
    iconBtn.icon:SetTexture(M.DEFAULT_ICON)
    iconBtn:SetScript("OnClick", function()
        if not KeyReady() then return end
        M.IconPicker.Open(frame, state.editIcon, function(icon)
            state.editIcon = icon
            iconBtn.icon:SetTexture(icon or M.DEFAULT_ICON)
            MarkDirty()
        end)
    end)
    UI.SetTip(iconBtn, function(tip)
        tip:AddLine("Click to choose an icon", 1, 1, 0)
        tip:AddLine(state.editIcon and ("Icon " .. tostring(state.editIcon)) or "Automatic (#showtooltip)", 1, 1, 1)
    end)

    local nameLabel = UI.Text(editor, UI.SIZE_SMALL, UI.GRAY)
    nameLabel:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, 0)
    nameLabel:SetText("Name")
    nameBox = UI.EditBox(editor, EDITOR_W - 54, 28, M.NAME_MAX)
    nameBox:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, -16)
    nameBox.edit:HookScript("OnTextChanged", function(_, userInput) if userInput then MarkDirty() end end)

    local bodyLabel = UI.Text(editor, UI.SIZE_SMALL, UI.GRAY)
    bodyLabel:SetPoint("TOPLEFT", 0, -80)
    bodyLabel:SetText("Macro text")

    local bodyBox = BuildBody(editor)
    bodyBox:SetPoint("TOPLEFT", 0, -96)
    counter:SetPoint("BOTTOMRIGHT", bodyBox, "TOPRIGHT", 0, 3)

    local function Row(y, defs)
        local x = 0
        for _, d in ipairs(defs) do
            local b = UI.Button(editor, d.label, 88, 26, d.color)
            b:SetPoint("TOPLEFT", x, y)
            b:SetScript("OnClick", d.fn)
            btn[d.key] = b
            x = x + 94
        end
    end

    Row(-296, {
        { key = "save", label = "Save", color = UI.YELLOW, fn = function() SaveCurrent() end },
        { key = "revert", label = "Revert", fn = function() LoadEditor(); SetStatus("") end },
        { key = "delete", label = "Delete", color = UI.RED, fn = function(self)
            if not Record() then return end
            if not state.confirmDelete then
                state.confirmDelete = true
                btn.delete:SetLabel("Sure?")
                C_Timer.After(3, function()
                    if state.confirmDelete then state.confirmDelete = false; btn.delete:SetLabel("Delete") end
                end)
                return
            end
            state.confirmDelete = false
            local scope, key, slot = state.scope, CurrentKey(), state.slot
            M.SetRecord(scope, key, slot, nil)
            local result = S.ApplySlot(scope, key, slot)
            SetStatus(result == "queued" and "Deleted. The action slot is cleared after combat." or "Deleted.", UI.GRAY)
            LoadEditor()
            RefreshGrid()
        end },
    })

    local function SetClip(cut)
        SaveCurrent()
        local rec = Record()
        if not rec then return end
        state.clip = { rec = M.CopyRecord(rec), cut = cut, scope = state.scope, key = CurrentKey(), slot = state.slot }
        SetStatus(("%s \"%s\": open another slot (any tab, class or spec) and press Paste."):format(cut and "Cut" or "Copied", rec.name), UI.YELLOW)
        UpdateButtons()
    end

    Row(-328, {
        { key = "copy", label = "Copy", fn = function() SetClip(false) end },
        { key = "cut",  label = "Cut",  fn = function() SetClip(true) end },
        { key = "paste", label = "Paste", color = UI.YELLOW, fn = function()
            SaveCurrent()
            local clip = state.clip
            if not clip or Record() or not KeyReady() then return end
            M.SetRecord(state.scope, CurrentKey(), state.slot, M.CopyRecord(clip.rec))
            local result = S.ApplySlot(state.scope, CurrentKey(), state.slot)
            if clip.cut then
                M.SetRecord(clip.scope, clip.key, clip.slot, nil)
                S.ApplySlot(clip.scope, clip.key, clip.slot)
                state.clip = nil
            end
            SetStatus(result == "queued" and "Pasted. It is written to the action slots after combat." or "Pasted.", UI.GRAY)
            LoadEditor()
            RefreshGrid()
        end },
    })
end

local function BuildGrid()
    grid = CreateFrame("Frame", nil, frame)
    grid:SetSize(GRID_W, EDITOR_H)
    for i = 1, 60 do
        local b = UI.IconButton(grid, CELL)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        b:SetPoint("TOPLEFT", col * (CELL + GAP), -row * (CELL + GAP))
        b.text:SetFont(UI.FONT, 20, "")
        b.label = UI.Text(b, 9, UI.WHITE, "OVERLAY")
        b.label:SetFont(UI.FONT, 9, "OUTLINE")
        b.label:SetPoint("BOTTOMLEFT", 2, 3)
        b.label:SetPoint("BOTTOMRIGHT", -2, 3)
        b.label:SetJustifyH("CENTER")
        b.label:SetWordWrap(false)
        b.slot = i
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick", function(self) SelectSlot(self.slot) end)
        b:SetScript("OnDragStart", function(self)
            local sc = M.scopeByKey[state.scope]
            local rec = KeyReady() and M.GetRecord(state.scope, CurrentKey(), self.slot)
            if not rec or not IsActiveBrowse() or InCombatLockdown() then return end
            SaveCurrent()
            local idx = S.GetNativeIndex(sc.first + self.slot)
            if idx then PickupMacro(idx) end
        end)
        UI.SetTip(b, function(tip)
            local sc = M.scopeByKey[state.scope]
            local rec = KeyReady() and M.GetRecord(state.scope, CurrentKey(), b.slot)
            if not rec then
                tip:AddLine("Empty slot " .. b.slot, 0.7, 0.7, 0.75)
                return
            end
            tip:AddLine(rec.name, 1, 1, 1)
            local n = 0
            for line in (rec.body .. "\n"):gmatch("(.-)\n") do
                n = n + 1
                if n > 6 then tip:AddLine("...", 0.6, 0.6, 0.66); break end
                tip:AddLine(line, 0.6, 0.8, 1, true)
            end
            if IsActiveBrowse() then
                tip:AddLine("Drag to an action bar", 1, 1, 0)
            elseif sc.bound then
                tip:AddLine("Not active: switch to this class / spec / character to use it", 0.7, 0.7, 0.75, true)
            end
        end)
        slotButtons[i] = b
    end
end

local function Build()
    frame = UI.Box(UIParent, { 0.05, 0.05, 0.07, 0.98 }, UI.BLUE)
    _G.CXUI_MacroWindow = frame
    frame:SetSize(WIN_W, 640)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:Hide()
    tinsert(UISpecialFrames, "CXUI_MacroWindow")

    local pos = M.DB().ui.pos
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER")
    end

    -- title bar (drag handle)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(38)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local p, _, rp, x, y = frame:GetPoint()
        M.DB().ui.pos = { p, rp, x, y }
    end)

    local title = UI.Text(bar, UI.SIZE_TITLE, UI.BLUE)
    title:SetPoint("LEFT", 14, 0)
    title:SetText("cx|cffffff00Macros|r")

    local close = UI.Button(bar, "Close", 64, 24, UI.YELLOW)
    close:SetPoint("RIGHT", -10, 0)
    close:SetScript("OnClick", function() frame:Hide() end)

    banner = UI.Text(bar, UI.SIZE_SMALL, UI.RED)
    banner:SetPoint("RIGHT", close, "LEFT", -12, 0)
    banner:SetPoint("LEFT", title, "RIGHT", 16, 0)
    banner:SetJustifyH("RIGHT")
    banner:SetWordWrap(false)

    -- scope tabs
    tabs = {}
    for i, sc in ipairs(M.scopes) do
        local t = UI.Button(frame, sc.label, TAB_W, 28)
        t:SetPoint("TOPLEFT", 12 + (i - 1) * (TAB_W + 4), -42)
        t.scope = sc.key
        t:SetScript("OnClick", function(self)
            SaveCurrent()
            state.scope = self.scope
            state.slot = nil
            W.Rebuild(true)
        end)
        tabs[i] = t
    end

    strips = CreateFrame("Frame", nil, frame)
    strips:SetPoint("TOPLEFT", 12, -80)
    strips:SetSize(INNER_W, 1)

    BuildGrid()
    BuildEditor()

    -- footer: status text (left), tools (right)
    statusLine = UI.Text(frame, UI.SIZE_SMALL, UI.GRAY)
    statusLine:SetPoint("BOTTOMLEFT", 14, 18)
    statusLine:SetPoint("RIGHT", frame, "RIGHT", -300, 0)
    statusLine:SetWordWrap(false)

    btn.import = UI.Button(frame, "Import Mega Macro", 140, 24, UI.YELLOW)
    btn.import:SetPoint("BOTTOMRIGHT", -12, 12)
    btn.import:SetScript("OnClick", function() M.ImportMegaMacro(); W.Rebuild(true) end)
    UI.SetTip(btn.import, function(tip)
        tip:AddLine("Copies your Mega Macro macros into cxUI", 1, 1, 0)
        tip:AddLine("Nothing in Mega Macro is changed. Run it on every character, then disable Mega Macro.", 1, 1, 1, true)
    end)

    btn.adopt = UI.Button(frame, "Adopt native", 130, 24, UI.YELLOW)
    btn.adopt:SetPoint("RIGHT", btn.import, "LEFT", -6, 0)
    btn.adopt:SetScript("OnClick", function() M.AdoptNative(); W.Rebuild(true) end)
    UI.SetTip(btn.adopt, function(tip)
        tip:AddLine("Native macros that cxUI does not manage yet", 1, 1, 0)
        tip:AddLine("Moves them into General / Character. Bar buttons keep working.", 1, 1, 1, true)
    end)

    frame:SetScript("OnHide", function()
        SaveCurrent()
        M.IconPicker.Close()
    end)
    frame:SetScript("OnShow", function() W.Rebuild(true) end)
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------
function W.Show()
    if not frame then Build() end
    if frame:IsShown() then frame:Raise() else frame:Show() end
end

function W.Hide() if frame then frame:Hide() end end

function W.Toggle()
    if frame and frame:IsShown() then frame:Hide() else W.Show() end
end

function W.IsShown() return frame and frame:IsShown() or false end

function M.NotifyChanged() W.Refresh() end
