local _, cxns = ...
-- Vendored from EllesmereSkin_WIM/Skin.lua, unchanged.
-- Wrapped in a function so cxUI can run it once the addon it skins has loaded
-- (see Sk.RunChunks in EllesmereSkins.lua). Its own header follows.
local chunks = cxns.ESkin.chunks
chunks.WIM = chunks.WIM or {}
table.insert(chunks.WIM, function(...)
-------------------------------------------------------------------------------
--  EllesmereSkin_WIM -- Skin.lua
--
--  Two halves:
--
--   1. A WIM skin table registered via WIM.RegisterSkin(). This handles
--      everything WIM's skin engine is capable of on its own: widget geometry,
--      fonts, button textures, tab strip, min size. Because WIM's Skinner
--      metatable-inherits any missing field from "WIM Classic", we only declare
--      what actually differs -- emoticons, client icons etc. come for free.
--
--   2. A post-hook on WIM.ApplySkinToWindow(). WIM's backdrop is a 3x3 atlas
--      sliced with SetTexCoord: rounded 64px corners that STRETCH with the
--      window. That is fundamentally incompatible with pixel-perfect. So the
--      hook flattens the atlas to solid colour (WHITE8X8 + neutral texcoords +
--      vertex colour) and draws a real 1px border via the EllesmereUI engine.
--      This is the only way to get a genuine 1px edge here; no texture can do it.
--
--  Why a hook and not just the table: RegisterSkin cannot express "solid fill
--  plus a separate 1px border frame" -- it can only point at textures. The hook
--  runs AFTER WIM has applied its own atlas, so it always wins.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local L     = ns.L
local Theme = ns.Theme
local Pixel = ns.Pixel

local WIM = _G.WIM
if not WIM then return end

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Neutral texcoords: the full white quad, no atlas slicing.
local FULL = { 0, 0, 0, 1, 1, 0, 1, 1 }

local SKIN_TITLE = L["SKIN_TITLE"]

-- Is one of OUR skins the selected one? Shared with Buttons.lua.
function ns.IsOurSkin()
    local selected = WIM.GetSelectedSkin and WIM.GetSelectedSkin()
    local title = selected and selected.title
    return title == SKIN_TITLE or title == L["SKIN_TITLE_LIGHT"]
end

-------------------------------------------------------------------------------
--  char_info formatter -- same data as WIM Classic, but muted grey instead of
--  white so the sender name stays the only bright thing in the title row.
-------------------------------------------------------------------------------
local function formatDetails(window, guild, level, race, class)
    if guild ~= "" then guild = "<" .. guild .. "> " end
    local details = {}
    if guild ~= "" then table.insert(details, guild) end
    if level ~= "" then table.insert(details, level) end
    if race  ~= "" then table.insert(details, race)  end
    if class ~= "" then table.insert(details, class) end
    return "|cff9d9d9d" .. table.concat(details, " ") .. "|r"
end

-------------------------------------------------------------------------------
--  The skin table
-------------------------------------------------------------------------------
local EllesmereSkin = {
    title   = SKIN_TITLE,
    version = "1.3.0",
    author  = "Laurent",
    website = "",

    message_window = {
        -- Flat white base; the hook vertex-colours it. Solid, never stretched.
        texture    = WHITE,
        min_width  = 260,
        min_height = 100,

        backdrop = {
            -- Corner/edge sizes are driven to 0 by the hook (the real border is
            -- a separate 1px frame), but WIM reads these before the hook runs,
            -- so keep them small and sane to avoid a one-frame flash of chunk.
            top_left     = { width = 1, height = 1, offset = {0, 0}, texture_coord = FULL },
            top_right    = { width = 1, height = 1, offset = {0, 0}, texture_coord = FULL },
            bottom_left  = { width = 1, height = 1, offset = {0, 0}, texture_coord = FULL },
            bottom_right = { width = 1, height = 1, offset = {0, 0}, texture_coord = FULL },
            top          = { tile = false, texture_coord = FULL },
            bottom       = { tile = false, texture_coord = FULL },
            left         = { tile = false, texture_coord = FULL },
            right        = { tile = false, texture_coord = FULL },
            background   = { tile = false, texture_coord = FULL },
        },

        widgets = {
            -- Square class icon. WIM's UpdateIcon drives SetTexCoord from these
            -- per-class keys, so we keep the SAME atlas it ships (the coords are
            -- inherited from WIM Classic via the metatable) but drop is_round
            -- and resize to a compact EUI-style square. The 1px border on it is
            -- added by the hook.
            class_icon = {
                width  = 26,
                height = 26,
                is_round = false,
                points = {
                    { "TOPLEFT", "window", "TOPLEFT", 6, -6 },
                },
            },

            client_icon = {
                width  = 26,
                height = 26,
                points = {
                    { "TOPLEFT", "window", "TOPLEFT", 6, -6 },
                },
            },

            -- Sender name: class colour (WIM default behaviour), not accent.
            from = {
                points = {
                    { "TOPLEFT", "window", "TOPLEFT", 38, -7 },
                },
                font        = "ChatFontNormal",
                font_color  = "ffffff",
                font_height = 13,
                font_flags  = "",
                use_class_color = true,
            },

            char_info = {
                format = formatDetails,
                points = {
                    { "TOPLEFT", "window", "TOPLEFT", 38, -22 },
                },
                font        = "ChatFontNormal",
                font_height = 10,
                font_color  = "9d9d9d",
            },

            close = {
                state_hide = {
                    NormalTexture    = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
                    PushedTexture    = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
                    HighlightTexture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
                    HighlightAlphaMode = "ADD",
                },
                state_close = {
                    NormalTexture    = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
                    PushedTexture    = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
                    HighlightTexture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
                    HighlightAlphaMode = "ADD",
                },
                -- Drawn as a pixel-art chip by Buttons.lua; the textures above
                -- are kept for WIM but never shown.
                width  = 18,
                height = 18,
                points = {
                    { "TOPRIGHT", "window", "TOPRIGHT", -5, -5 },
                },
            },

            history = {
                width  = 18,
                height = 18,
                points = {
                    { "TOPRIGHT", "window", "TOPRIGHT", -25, -5 },
                },
            },

            -- Scroll buttons share the right gutter with the shortcut bar:
            -- same 20px column (-4 .. -24), stacked above and below it.
            scroll_up = {
                width  = 20,
                height = 20,
                points = {
                    { "TOPRIGHT", "window", "TOPRIGHT", -4, -32 },
                },
            },

            scroll_down = {
                width  = 20,
                height = 20,
                points = {
                    { "BOTTOMRIGHT", "window", "BOTTOMRIGHT", -4, 30 },
                },
            },

            -- The chat well and the input box are the two "inset" surfaces.
            -- Right edge at -28: clears the 20px shortcut/scroll gutter that
            -- runs from -4 to -24, plus 4px of breathing room. The inset
            -- background bleeds 4px outward (see SkinInset), so anything less
            -- than this puts the inset border underneath the icons.
            chat_display = {
                points = {
                    { "TOPLEFT",     "window", "TOPLEFT",     12, -36 },
                    { "BOTTOMRIGHT", "window", "BOTTOMRIGHT", -28, 32 },
                },
                font = "ChatFontNormal",
            },

            -- msg_box sits BELOW the shortcut gutter (gutter bottom is +52,
            -- this box tops out at +27), so it may use the full window width.
            -- Right edge at -12 because SkinInset bleeds the background +4
            -- outward: -12+4 = -8, leaving a clean 8px gap to the window's own
            -- 1px border instead of the two edges fusing into one thick line.
            msg_box = {
                font        = "ChatFontNormal",
                font_height = 12,
                font_color  = { 1, 1, 1 },
                points = {
                    { "TOPLEFT",     "window", "BOTTOMLEFT",  12, 27 },
                    { "BOTTOMRIGHT", "window", "BOTTOMRIGHT", -12, 7 },
                },
            },

            resize = {
                width  = 16,
                height = 16,
                points = {
                    { "BOTTOMRIGHT", "window", "BOTTOMRIGHT", 0, 0 },
                },
            },

            -- Shortcut bar. IMPORTANT: with stack="DOWN", WIM sizes each button
            -- as SetHeight(frame:GetWidth()) -- the frame's WIDTH drives the
            -- button size. So this frame's width IS the icon size (20px), and
            -- chat_display must clear the whole gutter (icon + margins) or the
            -- icons render on top of the chat log.
            --
            --   window right edge ......................  0
            --   gutter outer margin ....................  -4
            --   button column (20 wide) ................  -4 .. -24
            --   chat_display right edge ................  -28  (4px breathing room)
            shortcuts = {
                stack   = "DOWN",
                spacing = 2,
                points = {
                    { "TOPLEFT",     "window", "TOPRIGHT",    -24, -54 },
                    { "BOTTOMRIGHT", "window", "BOTTOMRIGHT",  -4,  52 },
                },
            },
        },
    },

    tab_strip = {
        -- Flat slices. WIM tabs are 3-slice (left/middle/right) and each slice
        -- gets the same path, so a solid white texture tints uniformly with no
        -- stretching artefacts. Colours are applied by the hook.
        textures = {
            tab = {
                NormalTexture      = WHITE,
                PushedTexture      = WHITE,
                -- The unread-message flash drives LockHighlight(), so the
                -- highlight texture IS the flash. This is the one place the
                -- accent appears -- see PostApplyTabStrip.
                HighlightTexture   = WHITE,
                HighlightAlphaMode = "BLEND",
            },
            prev = {
                NormalTexture   = "Interface\\MoneyFrame\\Arrow-Left-Up",
                PushedTexture   = "Interface\\MoneyFrame\\Arrow-Left-Down",
                DisabledTexture = "Interface\\MoneyFrame\\Arrow-Left-Disabled",
                height = 16, width = 16,
            },
            next = {
                NormalTexture   = "Interface\\MoneyFrame\\Arrow-Right-Up",
                PushedTexture   = "Interface\\MoneyFrame\\Arrow-Right-Down",
                DisabledTexture = "Interface\\MoneyFrame\\Arrow-Right-Disabled",
                height = 16, width = 16,
            },
        },
        height = 22,
        points = {
            { "BOTTOMLEFT",  "window", "TOPLEFT",  2, 1 },
            { "BOTTOMRIGHT", "window", "TOPRIGHT", -2, 1 },
        },
        text = {
            font        = "ChatFontNormal",
            font_color  = { 0.8, 0.8, 0.8 },
            font_height = 11,
            font_flags  = "",
        },
        vertical = false,
    },
};

-- Light variant: same geometry, lighter shell. Registered as a second skin so
-- the user can pick it in WIM's skin dropdown. Inherits everything else.
local EllesmereSkin_Light = {
    title   = L["SKIN_TITLE_LIGHT"],
    author  = EllesmereSkin.author,
    version = EllesmereSkin.version,
};

-------------------------------------------------------------------------------
--  Font application. WIM's SetWidgetFont only understands font OBJECTS or
--  LibSharedMedia names -- it cannot take a raw path, which is what EUI gives
--  us. So we apply our font directly to the FontStrings after WIM is done.
-------------------------------------------------------------------------------
local function ApplyFont(obj, size)
    if not obj or not obj.SetFont then return end
    local path  = Theme.FontPath()
    local flags = Theme.FontFlags()
    if not path or path == "" then return end
    local ok = pcall(obj.SetFont, obj, path, size, flags)
    if ok and obj.SetShadowOffset then
        if Theme.FontUseShadow() then
            obj:SetShadowOffset(1, -1)
            obj:SetShadowColor(0, 0, 0, 1)
        else
            obj:SetShadowOffset(0, 0)
        end
    end
end

-------------------------------------------------------------------------------
--  Flatten one atlas texture into a solid colour quad.
-------------------------------------------------------------------------------
local function Flatten(tex, r, g, b, a)
    if not tex then return end
    tex:SetTexture(WHITE)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(r, g, b, a)
    Pixel.DisablePixelSnap(tex)
end

-------------------------------------------------------------------------------
--  Give a widget an inset look: dark fill behind it.
--
--  Idempotence rule: the guard must prevent duplicate TEXTURE CREATION, never
--  the recolour. Bailing out early on an already-skinned widget means a changed
--  colour (new version, theme switch, EUI accent change) silently never lands
--  on windows that were skinned under the old values -- the texture is created
--  once and then frozen forever. So: create at most once, but ALWAYS re-assert
--  colour and anchors on every call.
-------------------------------------------------------------------------------
local function SkinInset(widget, r, g, b, a)
    if not widget or not widget.CreateTexture then return end

    local bg = widget._eskwimBG
    if not bg then
        bg = widget:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetTexture(WHITE)
        widget._eskwimBG = bg
    end

    -- Re-asserted every call, not just on creation.
    bg:SetVertexColor(r, g, b, a)
    bg:ClearAllPoints()
    -- Bleed slightly outside the text rect so the border doesn't clip glyphs.
    bg:SetPoint("TOPLEFT",     widget, "TOPLEFT",     -4, 3)
    bg:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT",  4, -3)
    Pixel.DisablePixelSnap(bg)
end

-------------------------------------------------------------------------------
--  Tab strip colouring.
--
--  WIM builds each tab from 3 slices (left/middle/right) for normal, selected
--  and highlight states. We gave all of them WHITE8X8 in the skin table, so
--  here we just vertex-colour them:
--    normal    -> inset (recedes)
--    selected  -> shell background (reads as continuous with the window)
--    highlight -> ACCENT. LockHighlight() is what WIM's flash loop toggles on a
--                 tab with unread messages, so this is the single, sober place
--                 the accent colour appears in the whole skin.
-------------------------------------------------------------------------------
local function ColourTab(tab)
    if not tab then return end
    local ir, ig, ib, ia = Theme.Inset()
    local br, bgc, bb, ba = Theme.Background()
    local ar, ag, ab = Theme.Accent()

    for _, key in ipairs({ "left", "middle", "right" }) do
        local tx = tab[key]
        if tx and tx.SetVertexColor then
            tx:SetVertexColor(ir, ig, ib, ia)
            Pixel.DisablePixelSnap(tx)
        end
    end
    for _, key in ipairs({ "sleft", "smiddle", "sright" }) do
        local tx = tab[key]
        if tx and tx.SetVertexColor then
            tx:SetVertexColor(br, bgc, bb, ba)
            Pixel.DisablePixelSnap(tx)
        end
    end
    -- The tab is a real Button, so the flash is the NATIVE highlight texture
    -- (WIM's flash loop toggles LockHighlight/UnlockHighlight on unread tabs).
    -- Note WIM's applySkinToTab calls tab:SetHighlightTexture(path) with the
    -- path from our skin table, which REPLACES the texture object -- so we must
    -- re-fetch and re-colour it here, after that call, every time.
    local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
    if hl and hl.SetVertexColor then
        hl:SetVertexColor(ar, ag, ab, 0.55)
        Pixel.DisablePixelSnap(hl)
    end

    if tab.text then ApplyFont(tab.text, 11) end
end

local function PostApplyTabStrip(tabStrip)
    if not tabStrip or not tabStrip.tabs then return end
    local selected = WIM.GetSelectedSkin and WIM.GetSelectedSkin()
    if not selected then return end
    local title = selected.title
    if title ~= SKIN_TITLE and title ~= L["SKIN_TITLE_LIGHT"] then return end

    for i = 1, #tabStrip.tabs do
        ColourTab(tabStrip.tabs[i])
    end
end

-------------------------------------------------------------------------------
--  The main hook: runs after WIM applies its own skin to a window.
-------------------------------------------------------------------------------
local function PostApplySkin(obj)
    if not obj then return end
    -- Only touch windows while OUR skin is the selected one. WIM calls
    -- ApplySkinToWindow for every skin switch, so this must be re-checked every
    -- time or we would keep re-skinning after the user picks another skin.
    local selected = WIM.GetSelectedSkin and WIM.GetSelectedSkin()
    if not selected then return end
    local title = selected.title
    if title ~= SKIN_TITLE and title ~= L["SKIN_TITLE_LIGHT"] then
        -- Buttons are the one thing we draw OVER WIM's own widgets; hand them
        -- back their stock textures when the user switches skin.
        if ns.Buttons then ns.Buttons.UnskinWindow(obj) end
        return
    end

    local w = obj.widgets
    if not w or not w.Backdrop then return end

    local br, bg_, bb, ba = Theme.Background()
    if title == L["SKIN_TITLE_LIGHT"] then
        br, bg_, bb = 0.13, 0.13, 0.13
    end

    -- 1. Flatten the 3x3 atlas. The background becomes the shell fill; the 8
    --    edge/corner pieces are alpha'd out entirely -- the real border is the
    --    1px frame we add below.
    Flatten(w.Backdrop.bg, br, bg_, bb, ba)
    for _, key in ipairs({ "tl", "tr", "bl", "br", "t", "b", "l", "r" }) do
        local tex = w.Backdrop[key]
        if tex then
            tex:SetTexture(WHITE)
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetVertexColor(0, 0, 0, 0)
        end
    end
    -- Make the background cover the whole window: WIM anchors bg between the
    -- corner pieces, which we have just zeroed out.
    w.Backdrop.bg:ClearAllPoints()
    w.Backdrop.bg:SetAllPoints(w.Backdrop)

    -- 2. The real border: 1px, EUI engine when available.
    local dr, dg, db, da = Theme.Border()
    Pixel.CreateBorder(obj, dr, dg, db, da, 1, "OVERLAY", 7)
    Pixel.Attach(obj)

    -- 3. Square, 1px-bordered class icon, at FULL opacity.
    --
    --    Two things were washing the icon out:
    --      a) WIM parents class_icon to the Backdrop FRAME, and UpdateProps does
    --         Backdrop:SetAlpha(db.windowAlpha/100). Child textures inherit
    --         frame alpha, so the icon was being faded by the user's window
    --         transparency setting along with the shell.
    --      b) class_icon sits on the BACKGROUND layer, the same layer our
    --         flattened shell fill now occupies.
    --
    --    Fix: give the icon its own host frame, parented to the WINDOW (not the
    --    Backdrop) at full alpha and a higher frame level. SetParent on a
    --    texture keeps its texcoords, so WIM's UpdateIcon keeps driving the
    --    per-class atlas exactly as before -- we only change who it renders
    --    under.
    local icon = w.class_icon
    if icon and not obj._eskwimIconFrame then
        local host = CreateFrame("Frame", nil, obj)
        host:SetFrameLevel(w.Backdrop:GetFrameLevel() + 3)
        host:SetAlpha(1)
        host:SetPoint("TOPLEFT",     icon, "TOPLEFT",     0, 0)
        host:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)

        if icon.SetParent then
            icon:SetParent(host)
            icon:SetDrawLayer("ARTWORK", 1)
        end

        Pixel.CreateBorder(host, dr, dg, db, da, 1, "OVERLAY", 7)
        obj._eskwimIconFrame = host
    elseif icon and obj._eskwimIconFrame then
        -- LoadSkin re-runs on every skin/theme switch; re-assert the layer in
        -- case WIM reset it underneath us.
        icon:SetDrawLayer("ARTWORK", 1)
    end
    if icon then
        icon:SetAlpha(1)
        Pixel.DisablePixelSnap(icon)
    end

    -- 4. Inset surfaces.
    --    chat_display: fill only, it is the passive reading surface.
    --    msg_box: fill PLUS a real 1px border. A fill difference alone is not
    --    enough at these near-black luminances (the previous attempt at a
    --    darker fill was invisible); the border is what actually separates the
    --    two surfaces, and it is the EllesmereUI idiom -- every distinct
    --    surface in that UI is delimited by a 1px edge, not by shading alone.
    local ir, ig, ib, ia = Theme.Inset()
    SkinInset(w.chat_display, ir, ig, ib, ia)

    local qr, qg, qb, qa = Theme.InputInset()
    SkinInset(w.msg_box, qr, qg, qb, qa)

    -- The border needs its own host frame: it must trace the padded background
    -- rect (which bleeds 4px sideways / 3px vertically past the text rect), not
    -- the bare text rect, or it would cut through the glyphs.
    if w.msg_box and not obj._eskwimInputFrame then
        local box = CreateFrame("Frame", nil, obj)
        box:SetPoint("TOPLEFT",     w.msg_box, "TOPLEFT",     -4, 3)
        box:SetPoint("BOTTOMRIGHT", w.msg_box, "BOTTOMRIGHT",  4, -3)
        box:SetFrameLevel(w.msg_box:GetFrameLevel())
        Pixel.CreateBorder(box, dr, dg, db, da, 1, "OVERLAY", 7)
        Pixel.Attach(box)
        obj._eskwimInputFrame = box
    elseif obj._eskwimInputFrame then
        -- Re-assert on every skin/theme switch so a colour change lands.
        Pixel.SetBorderColor(obj._eskwimInputFrame, dr, dg, db, da)
    end

    -- 5. Action buttons: pixel-art chips (see Buttons.lua).
    if ns.Buttons then ns.Buttons.SkinWindow(obj) end

    -- 6. Fonts -- applied last so nothing overwrites them.
    ApplyFont(w.from, 13)
    ApplyFont(w.char_info, 10)
    ApplyFont(w.chat_display, (WIM.db and WIM.db.fontSize or 12) + 1)
    ApplyFont(w.msg_box, 12)
end

-------------------------------------------------------------------------------
--  Registration
-------------------------------------------------------------------------------
WIM.RegisterSkin(EllesmereSkin);
WIM.RegisterSkin(EllesmereSkin_Light);

if WIM.ApplySkinToWindow then
    hooksecurefunc(WIM, "ApplySkinToWindow", PostApplySkin)
end

-- Tab strips are skinned through a separate WIM entry point. It takes no
-- arguments and walks WIM's internal tabGroups list, which is a file-local we
-- cannot reach -- so instead of re-deriving it, we ride the same call and
-- recolour every tab strip attached to a live window.
if WIM.ApplySkinToTabs then
    hooksecurefunc(WIM, "ApplySkinToTabs", function()
        local bowl = WIM.GetWindowSoupBowl and WIM.GetWindowSoupBowl()
        if not (bowl and bowl.windows) then return end
        local seen = {}
        for i = 1, #bowl.windows do
            local entry = bowl.windows[i]
            local win = entry and entry.obj
            local strip = win and win.tabStrip
            if strip and not seen[strip] then
                seen[strip] = true
                PostApplyTabStrip(strip)
            end
        end
    end)
end

-- Re-apply on theme/scale changes so a live accent or font switch in
-- EllesmereUI propagates without a reload.
local refresher = CreateFrame("Frame")
refresher:RegisterEvent("PLAYER_LOGIN")
refresher:SetScript("OnEvent", function()
    if WIM.LoadSkin and WIM.db and WIM.db.skin then
        local sel = WIM.db.skin.selected
        if sel == SKIN_TITLE or sel == L["SKIN_TITLE_LIGHT"] then
            WIM.LoadSkin(sel)
        end
    end
end)
end)
