local _, cxns = ...
-- Vendored from EllesmereSkin_WIM/Buttons.lua, unchanged.
-- Wrapped in a function so cxUI can run it once the addon it skins has loaded
-- (see Sk.RunChunks in EllesmereSkins.lua). Its own header follows.
local chunks = cxns.ESkin.chunks
chunks.WIM = chunks.WIM or {}
table.insert(chunks.WIM, function(...)
-------------------------------------------------------------------------------
--  EllesmereSkin_WIM -- Buttons.lua
--
--  Pixel-art skin for WIM's action buttons: close, history, scroll up/down and
--  every button of the shortcut bar (location, invite, guild, friend, ignore).
--
--  WIM only lets a skin point buttons at textures, and the ones it ships are
--  Blizzard bevelled art + full-colour spell icons -- nothing like EllesmereUI.
--  So instead of fighting the texture slots, each button gets a "chip" child
--  frame drawn entirely from WHITE8X8:
--
--    * flat fill + 1px border (same engine as the window border)
--    * a glyph drawn from a tiny bitmap (see GLYPHS), laid out on the TRUE
--      physical pixel grid so every cell is an exact multiple of a screen
--      pixel -- crisp pixel art at any UI scale, never a blurry stretch
--    * hover = accent glyph + accent border; pushed = darker fill and the glyph
--      nudged 1px; disabled = dimmed glyph
--
--  WIM's own Normal/Pushed/Highlight textures are kept (WIM re-sets them all
--  the time, e.g. the close button swaps on Shift every frame) but are alpha'd
--  out by a post-hook on each setter, so whatever WIM does, they never show.
--
--  The chip is a plain Frame with mouse disabled: GetMouseFocus() still
--  returns the WIM button itself, which WIM's close-button OnUpdate relies on.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Theme = ns.Theme
local Pixel = ns.Pixel

local WIM = _G.WIM
if not WIM then return end

local Buttons = {}
ns.Buttons = Buttons

local WHITE = "Interface\\Buttons\\WHITE8X8"
local floor, max, min = math.floor, math.max, math.min

-------------------------------------------------------------------------------
--  Glyphs. Every glyph fits a 5x5 grid so all buttons share ONE cell size and
--  read as a single pixel-art family. '#' = lit cell.
-------------------------------------------------------------------------------
local GRID = 5

local GLYPHS = {
    -- close (Shift held: ends the conversation)
    close = {
        "#...#",
        ".#.#.",
        "..#..",
        ".#.#.",
        "#...#",
    },
    -- hide to minimap (WIM's default click on the close button)
    hide = {
        "#####",
    },
    up = {
        "..#..",
        ".###.",
        "#####",
    },
    down = {
        "#####",
        ".###.",
        "..#..",
    },
    -- clock = history
    history = {
        ".###.",
        "#.#.#",
        "#.###",
        "#...#",
        ".###.",
    },
    -- map pin = player location
    location = {
        ".###.",
        "##.##",
        "#####",
        ".###.",
        "..#..",
    },
    -- plus = invite to party
    invite = {
        "..#..",
        "..#..",
        "#####",
        "..#..",
        "..#..",
    },
    -- banner = invite to guild
    guild = {
        "#####",
        "#####",
        "#####",
        "##.##",
        "#...#",
    },
    -- heart = add friend
    friend = {
        ".#.#.",
        "#####",
        "#####",
        ".###.",
        "..#..",
    },
    -- no-entry sign = ignore
    ignore = {
        ".###.",
        "##..#",
        "#.#.#",
        "#..##",
        ".###.",
    },
}

-- Shortcut ids WIM registers out of the box. Third-party shortcuts are not in
-- here and fall back to their own icon, cropped and framed.
local SHORTCUT_GLYPH = {
    location = "location",
    invite   = "invite",
    guild    = "guild",
    friend   = "friend",
    ignore   = "ignore",
}

-- Weak registry of every chip, for the global re-layout on UI scale changes.
local chips = setmetatable({}, { __mode = "k" })

local function IsOurs()
    return ns.IsOurSkin and ns.IsOurSkin()
end

-------------------------------------------------------------------------------
--  Stock textures: kept, but invisible while our skin is active.
-------------------------------------------------------------------------------
local STOCK_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }

local function SetStockAlpha(btn, a)
    for _, getter in ipairs(STOCK_GETTERS) do
        local tex = btn[getter] and btn[getter](btn)
        if tex then tex:SetAlpha(a) end
    end
end

-------------------------------------------------------------------------------
--  Glyph layout -- whole physical pixels only.
-------------------------------------------------------------------------------
local function ColourCells(chip)
    local c = chip._glyphColor
    if not c then return end
    for i = 1, #chip.cells do
        chip.cells[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    end
end

local function LayoutChip(chip)
    local cells = chip.cells
    local used = 0
    local glyph = chip._glyphKey and GLYPHS[chip._glyphKey]
    local px = Pixel.OnePixel(chip)
    local w, h = chip:GetSize()

    if glyph and px and px > 0 and w and w > 0 and h and h > 0 then
        local wPx = floor(w / px + 0.5)
        local hPx = floor(h / px + 0.5)
        -- Cell size in screen pixels: the 5x5 grid fills ~60% of the chip.
        local k = max(1, floor(min(wPx, hPx) * 0.6 / GRID))
        local rows, cols = #glyph, #glyph[1]
        local ox = floor((wPx - cols * k) / 2)
        local oy = floor((hPx - rows * k) / 2)
        if chip._down then ox, oy = ox + 1, oy + 1 end

        for r = 1, rows do
            local line = glyph[r]
            local c = 1
            while c <= cols do
                if line:sub(c, c) == "#" then
                    -- Merge a horizontal run into a single texture.
                    local s = c
                    while c <= cols and line:sub(c, c) == "#" do c = c + 1 end
                    used = used + 1
                    local tx = cells[used]
                    if not tx then
                        tx = chip:CreateTexture(nil, "ARTWORK")
                        tx:SetTexture(WHITE)
                        cells[used] = tx
                    end
                    tx:ClearAllPoints()
                    tx:SetPoint("TOPLEFT", chip, "TOPLEFT",
                                (ox + (s - 1) * k) * px, -(oy + (r - 1) * k) * px)
                    tx:SetSize((c - s) * k * px, k * px)
                    tx:Show()
                else
                    c = c + 1
                end
            end
        end
    end

    for i = used + 1, #cells do cells[i]:Hide() end
    ColourCells(chip)

    -- Fallback icon (third-party shortcut): inset 1px inside the border.
    if chip.icon and chip.icon:IsShown() and px then
        chip.icon:ClearAllPoints()
        chip.icon:SetPoint("TOPLEFT",     chip, "TOPLEFT",      px, -px)
        chip.icon:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", -px,  px)
    end
end

-------------------------------------------------------------------------------
--  Chip creation (once per button) and state refresh (every change).
-------------------------------------------------------------------------------
local Refresh -- forward

local function GetChip(btn)
    local chip = btn._eskwimChip
    if chip then return chip end

    chip = CreateFrame("Frame", nil, btn)
    chip:SetAllPoints(btn)
    chip:EnableMouse(false)

    chip.bg = chip:CreateTexture(nil, "BACKGROUND", nil, -8)
    chip.bg:SetTexture(WHITE)
    chip.bg:SetAllPoints(chip)
    Pixel.DisablePixelSnap(chip.bg)

    chip.cells = {}

    local dr, dg, db, da = Theme.Border()
    Pixel.CreateBorder(chip, dr, dg, db, da, 1, "OVERLAY", 7)

    chip:SetScript("OnSizeChanged", LayoutChip)
    chip:SetScript("OnShow", LayoutChip)

    btn._eskwimChip = chip
    chips[chip] = btn

    -- State tracking. HookScript, never SetScript: WIM owns these scripts.
    btn:HookScript("OnEnter",     function(self) self._eskwimHover = true;  Refresh(self) end)
    btn:HookScript("OnLeave",     function(self) self._eskwimHover = false; self._eskwimDown = false; Refresh(self) end)
    btn:HookScript("OnMouseDown", function(self) self._eskwimDown = true;   Refresh(self) end)
    btn:HookScript("OnMouseUp",   function(self) self._eskwimDown = false;  Refresh(self) end)

    -- WIM re-sets these constantly (close button: every Shift toggle).
    for _, setter in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture" }) do
        hooksecurefunc(btn, setter, function(self) Refresh(self) end)
    end
    -- Scroll buttons are enabled/disabled as the log scrolls.
    if btn.Enable and btn.Disable and not btn._eskwimShortcut then
        hooksecurefunc(btn, "Enable",  function(self) Refresh(self) end)
        hooksecurefunc(btn, "Disable", function(self) Refresh(self) end)
    end

    return chip
end

Refresh = function(btn)
    local chip = btn._eskwimChip
    if not chip then return end

    if not IsOurs() then
        chip:Hide()
        SetStockAlpha(btn, 1)
        if btn.icon then btn.icon:SetAlpha(1) end
        return
    end

    SetStockAlpha(btn, 0)
    chip:Show()

    local key = btn._eskwimGlyphFn and btn._eskwimGlyphFn(btn) or btn._eskwimGlyph
    local enabled = not btn.IsEnabled or btn:IsEnabled()
    local hover = btn._eskwimHover and enabled
    local down = btn._eskwimDown and enabled

    -- Glyph vs fallback icon.
    local useIcon = (not key) and btn._eskwimIconPath ~= nil
    if btn.icon then btn.icon:SetAlpha(0) end
    if useIcon then
        if not chip.icon then
            chip.icon = chip:CreateTexture(nil, "ARTWORK")
            chip.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        chip.icon:SetTexture(btn._eskwimIconPath)
        chip.icon:SetDesaturated(not hover)
        chip.icon:SetAlpha(enabled and 1 or 0.4)
        chip.icon:Show()
    elseif chip.icon then
        chip.icon:Hide()
    end

    -- Fill.
    local fr, fg, fb, fa
    if down then
        fr, fg, fb, fa = Theme.ButtonFillDown()
    elseif hover then
        fr, fg, fb, fa = Theme.ButtonFillHover()
    else
        fr, fg, fb, fa = Theme.ButtonFill()
    end
    chip.bg:SetVertexColor(fr, fg, fb, fa)

    -- Glyph + border colour.
    local gr, gg, gb, ga
    local danger = key == "close"
    if not enabled then
        gr, gg, gb, ga = Theme.GlyphDisabled()
    elseif danger then
        gr, gg, gb = Theme.Danger(); ga = 1
    elseif hover then
        gr, gg, gb = Theme.Accent(); ga = 1
    else
        gr, gg, gb, ga = Theme.Glyph()
    end
    chip._glyphColor = { gr, gg, gb, ga }

    if hover or (danger and enabled) then
        Pixel.SetBorderColor(chip, gr, gg, gb, 1)
    else
        local dr, dg, db, da = Theme.Border()
        Pixel.SetBorderColor(chip, dr, dg, db, da)
    end

    -- Only re-layout when the glyph or pressed offset actually changed.
    if chip._glyphKey ~= key or chip._down ~= down or chip._needsLayout then
        chip._glyphKey = key
        chip._down = down
        chip._needsLayout = nil
        LayoutChip(chip)
    else
        ColourCells(chip)
    end
end

local function SkinButton(btn, glyph, glyphFn)
    if not btn then return end
    btn._eskwimGlyph = glyph
    btn._eskwimGlyphFn = glyphFn
    local chip = GetChip(btn)
    chip._needsLayout = true
    Refresh(btn)
end

-------------------------------------------------------------------------------
--  Shortcut bar.
--
--  The button -> shortcut id mapping lives in a file-local table inside WIM's
--  ShortcutBar module, out of reach. What we CAN see is the icon path WIM
--  feeds each button (skin.buttons.icons[id]), so we record it through a hook
--  on the icon's SetTexture and reverse-look it up in the active skin's icon
--  map. Unknown paths (third-party shortcuts) keep their icon as a fallback.
-------------------------------------------------------------------------------
local function ShortcutIdFromPath(path)
    if not path then return nil end
    local skin = WIM.GetSelectedSkin and WIM.GetSelectedSkin()
    local sc = skin and skin.message_window and skin.message_window.widgets
               and skin.message_window.widgets.shortcuts
    local icons = sc and sc.buttons and sc.buttons.icons
    if not icons then return nil end
    -- Known ids only: the icons table inherits WIM Classic's via __index, so
    -- index it directly rather than pairs()-ing a table that may be empty.
    local want = tostring(path):lower()
    for id in pairs(SHORTCUT_GLYPH) do
        local p = icons[id]
        if p and tostring(p):lower() == want then return id end
    end
    return nil
end

local function SkinShortcutButton(btn)
    if not btn then return end
    btn._eskwimShortcut = true
    if btn.icon and not btn._eskwimIconHooked then
        btn._eskwimIconHooked = true
        hooksecurefunc(btn.icon, "SetTexture", function(_, path)
            btn._eskwimIconPath = path
            if btn._eskwimChip then
                local id = ShortcutIdFromPath(path)
                btn._eskwimGlyph = id and SHORTCUT_GLYPH[id] or nil
                Refresh(btn)
            end
        end)
    end
    local id = ShortcutIdFromPath(btn._eskwimIconPath)
    SkinButton(btn, id and SHORTCUT_GLYPH[id] or nil)
end

local function SkinShortcutBar(bar)
    if not bar or not bar.buttons then return end

    if not bar._eskwimHooked then
        bar._eskwimHooked = true
        -- UpdateSkin creates any missing buttons and re-sets every texture;
        -- ride it so late-created buttons get skinned too.
        hooksecurefunc(bar, "UpdateSkin", function(self)
            for i = 1, #self.buttons do SkinShortcutButton(self.buttons[i]) end
        end)
        -- First pass: the icon paths were set before our hooks existed, so
        -- install the hooks, then let WIM re-set everything once.
        for i = 1, #bar.buttons do SkinShortcutButton(bar.buttons[i]) end
        bar:UpdateSkin()
        return
    end

    for i = 1, #bar.buttons do SkinShortcutButton(bar.buttons[i]) end
end

-------------------------------------------------------------------------------
--  Public: called from Skin.lua's ApplySkinToWindow post-hook.
-------------------------------------------------------------------------------
local function CloseGlyph(btn)
    -- curTextureIndex: 1 = hide (default click), 2 = close (Shift held).
    return btn.curTextureIndex == 2 and "close" or "hide"
end

function Buttons.SkinWindow(obj)
    local w = obj and obj.widgets
    if not w then return end

    SkinButton(w.close, nil, CloseGlyph)
    SkinButton(w.history, "history")
    SkinButton(w.scroll_up, "up")
    SkinButton(w.scroll_down, "down")
    SkinShortcutBar(w.shortcuts)

    -- Window scale (WIM option) changes the effective scale without resizing
    -- anything, so OnSizeChanged never fires: re-layout on UpdateProps.
    if obj.UpdateProps and not obj._eskwimPropsHooked then
        obj._eskwimPropsHooked = true
        hooksecurefunc(obj, "UpdateProps", function(self)
            Buttons.RelayoutWindow(self)
        end)
    end
end

-- Another skin was selected: give every button back its stock look.
function Buttons.UnskinWindow(obj)
    local w = obj and obj.widgets
    if not w then return end
    for _, key in ipairs({ "close", "history", "scroll_up", "scroll_down" }) do
        if w[key] then Refresh(w[key]) end
    end
    if w.shortcuts and w.shortcuts.buttons then
        for i = 1, #w.shortcuts.buttons do Refresh(w.shortcuts.buttons[i]) end
    end
end

function Buttons.RelayoutWindow(obj)
    for chip, btn in pairs(chips) do
        if btn and (btn == obj or btn:GetParent() == obj
                    or (btn.parentWindow == obj)) and chip:IsShown() then
            LayoutChip(chip)
        end
    end
end

-- UI scale / resolution change: physical pixel size changed everywhere.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:SetScript("OnEvent", function()
    -- Pixel.lua recalculates on the same events; run after it.
    C_Timer.After(0, function()
        for chip in pairs(chips) do
            if chip:IsShown() then LayoutChip(chip) end
        end
    end)
end)
end)
