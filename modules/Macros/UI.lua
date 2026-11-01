local addonName, ns = ...
local M = ns.Macros

-- ===========================================================================
-- UI: tiny flat widget helpers in the cxUI look (blue / yellow / white / red,
-- 1px borders, WHITE8X8 fills). Same style as the Sound Picker in options.lua.
-- ===========================================================================

local UI = {}
M.UI = UI

local FONT = STANDARD_TEXT_FONT
UI.FONT       = FONT
UI.SIZE       = 13
UI.SIZE_SMALL = 11
UI.SIZE_TITLE = 18

UI.BLUE   = { 0, 0.44, 0.87 }
UI.YELLOW = { 1, 1, 0 }
UI.WHITE  = { 1, 1, 1 }
UI.RED    = { 1, 0, 0 }
UI.GRAY   = { 0.6, 0.6, 0.66 }

local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
UI.BACKDROP = BACKDROP

local BORDER = { 0.25, 0.25, 0.30 }

function UI.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK")
    fs:SetFont(FONT, size or UI.SIZE, "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    local c = color or UI.WHITE
    fs:SetTextColor(c[1], c[2], c[3])
    return fs
end

-- A flat bordered frame.
function UI.Box(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP)
    bg, border = bg or { 0.08, 0.08, 0.11, 0.95 }, border or BORDER
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    f:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    return f
end

-- Tooltip: fn(GameTooltip) fills it.
function UI.SetTip(frame, fn)
    frame.tipFn = fn
    if frame.tipHooked then return end
    frame.tipHooked = true
    frame:HookScript("OnEnter", function(self)
        if not self.tipFn then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        self.tipFn(GameTooltip)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Flat button. :SetSelected(bool) shows the blue "chosen" look.
function UI.Button(parent, label, w, h, color)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(BACKDROP)
    b.text = UI.Text(b, UI.SIZE, color or UI.WHITE)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label or "")
    b.selected, b.hover = false, false

    function b:UpdateLook()
        if self.selected then
            self:SetBackdropColor(0.06, 0.15, 0.28, 0.98)
            self:SetBackdropBorderColor(UI.BLUE[1], UI.BLUE[2], UI.BLUE[3], 1)
        elseif self.hover and self:IsEnabled() then
            self:SetBackdropColor(0.11, 0.13, 0.19, 0.98)
            self:SetBackdropBorderColor(UI.BLUE[1], UI.BLUE[2], UI.BLUE[3], 1)
        else
            self:SetBackdropColor(0.08, 0.08, 0.11, 0.95)
            self:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1)
        end
    end
    function b:SetSelected(v) self.selected = v and true or false; self:UpdateLook() end
    function b:SetLabel(t) self.text:SetText(t) end

    b:SetScript("OnEnter", function(s) s.hover = true; s:UpdateLook() end)
    b:SetScript("OnLeave", function(s) s.hover = false; s:UpdateLook() end)
    b:SetScript("OnDisable", function(s) s.text:SetAlpha(0.35); s:UpdateLook() end)
    b:SetScript("OnEnable", function(s) s.text:SetAlpha(1); s:UpdateLook() end)
    b:UpdateLook()
    return b
end

-- Single-line input in a flat box. Returns the box; the EditBox is box.edit.
function UI.EditBox(parent, w, h, maxLetters)
    local box = UI.Box(parent)
    box:SetSize(w, h)
    local eb = CreateFrame("EditBox", nil, box)
    eb:SetPoint("TOPLEFT", 6, -2)
    eb:SetPoint("BOTTOMRIGHT", -6, 2)
    eb:SetAutoFocus(false)
    eb:SetFont(FONT, UI.SIZE, "")
    eb:SetTextColor(1, 1, 1)
    if maxLetters then eb:SetMaxLetters(maxLetters) end
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    eb:HookScript("OnEditFocusGained", function() box:SetBackdropBorderColor(UI.BLUE[1], UI.BLUE[2], UI.BLUE[3], 1) end)
    eb:HookScript("OnEditFocusLost", function() box:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1) end)
    box.edit = eb
    return box
end

-- Thin vertical slider used as a scroll bar. Value 0 = top.
function UI.Slider(parent, height)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("VERTICAL")
    s:SetSize(10, height)
    s:SetBackdrop(BACKDROP)
    s:SetBackdropColor(0.05, 0.05, 0.07, 1)
    s:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(UI.BLUE[1], UI.BLUE[2], UI.BLUE[3], 1)
    thumb:SetSize(8, 28)
    s:SetThumbTexture(thumb)
    s:SetMinMaxValues(0, 0)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:SetValue(0)
    return s
end

-- Square icon button (slot / class / spec): .icon texture, flat border, :SetSelected().
function UI.IconButton(parent, size)
    local b = UI.Button(parent, "", size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return b
end

-- Class icon on a texture (atlas, with the old sprite sheet as fallback).
function UI.SetClassIcon(tex, classFile)
    local atlas = "classicon-" .. classFile:lower()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(atlas)
    else
        tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
        local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
        if c then tex:SetTexCoord(unpack(c)) end
    end
end
