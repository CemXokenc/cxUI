local _, cxns = ...
-- Vendored from EllesmereSkin_WIM/Theme.lua, unchanged.
-- Wrapped in a function so cxUI can run it once the addon it skins has loaded
-- (see Sk.RunChunks in EllesmereSkins.lua). Its own header follows.
local chunks = cxns.ESkin.chunks
chunks.WIM = chunks.WIM or {}
table.insert(chunks.WIM, function(...)
-------------------------------------------------------------------------------
--  EllesmereSkin_WIM -- Theme.lua
--
--  The soft-dependency layer. Every colour / font the skin needs is resolved
--  HERE and nowhere else, through one of two backends:
--
--    "bridged"    -> EllesmereUI is loaded. Tokens are read LIVE from it, so the
--                    skin tracks the user's accent theme, font choice and
--                    outline mode automatically, with zero duplication.
--    "standalone" -> EllesmereUI is absent. Tokens fall back to the exact
--                    values EllesmereUI ships as defaults (lifted from its
--                    WindowEngine Theme table + DEFAULT_ACCENT_*), so the
--                    window looks identical to a bridged install running the
--                    default profile.
--
--  Nothing else in this addon may hardcode a colour or a font path.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Theme = {}
ns.Theme = Theme

-- Are we bridged to a live EllesmereUI? -------------------------------------
-- Checked lazily (not at file-parse time): load order between two addons that
-- don't depend on each other is not guaranteed, and EUI resolves its own accent
-- at PLAYER_LOGIN, so an early snapshot could catch a pre-theme value.
local function EUI()
    return _G.EllesmereUI
end

function Theme.IsBridged()
    return EUI() ~= nil
end

-------------------------------------------------------------------------------
--  Standalone fallback constants.
--  These mirror EllesmereUI's shipped defaults 1:1:
--    accent : DEFAULT_ACCENT_R/G/B      = 12/255, 210/255, 157/255  (#0CD29D)
--    bg     : WindowEngine Theme.bg*    = 0.08, 0.08, 0.08, 0.92
--    inset  : WindowEngine Theme.inset* = 0.04, 0.04, 0.04, 0.85
--    border : WindowEngine Theme.brd*   = 0.20, 0.20, 0.20, 1.00
-------------------------------------------------------------------------------
local FALLBACK = {
    accR = 12/255, accG = 210/255, accB = 157/255,
    bgR   = 0.08, bgG   = 0.08, bgB   = 0.08, bgA   = 0.92,
    insR  = 0.04, insG  = 0.04, insB  = 0.04, insA  = 0.85,
    brdR  = 0.20, brdG  = 0.20, brdB  = 0.20, brdA  = 1.00,
}
Theme.FALLBACK = FALLBACK

-- Accent -- tracks EUI's live theme (preset / class / custom) when bridged. ---
function Theme.Accent()
    local E = EUI()
    if E then
        local c = E.ACCENT_COLOR or E.ELLESMERE_GREEN
        if c and c.r then
            return c.r, c.g, c.b
        end
    end
    return FALLBACK.accR, FALLBACK.accG, FALLBACK.accB
end

-- Panel background (the message window shell). -------------------------------
function Theme.Background()
    return FALLBACK.bgR, FALLBACK.bgG, FALLBACK.bgB, FALLBACK.bgA
end

-- Nested inset (chat_display well) -- darker than the shell. ----------------
function Theme.Inset()
    return FALLBACK.insR, FALLBACK.insG, FALLBACK.insB, FALLBACK.insA
end

-- Input well (msg_box). Deliberately LIGHTER than the chat log, not darker.
--
-- Going darker was the intuitive choice and it failed: against a ~0.05
-- luminance log, a darker fill lands near-black and the two surfaces read as
-- one continuous void. Lifting the input box above the log gives the eye an
-- actual step, and matches how EllesmereUI treats editable surfaces -- the
-- thing you type into is the active surface, so it comes forward rather than
-- receding. The 1px border (applied in the hook) does most of the separating
-- work; this fill just supports it.
function Theme.InputInset()
    return 0.14, 0.14, 0.14, 0.95
end

-- Border colour. -------------------------------------------------------------
function Theme.Border()
    return FALLBACK.brdR, FALLBACK.brdG, FALLBACK.brdB, FALLBACK.brdA
end

-------------------------------------------------------------------------------
--  Action buttons (close / history / scroll / shortcut bar).
--  Each button is a flat "chip": a fill one step above the chat log, a 1px
--  border, and a pixel-art glyph. At rest everything is neutral grey; hover
--  lights the glyph AND the border with the accent, the same way EllesmereUI
--  highlights its own controls.
-------------------------------------------------------------------------------
function Theme.ButtonFill()      return 0.11, 0.11, 0.11, 0.95 end
function Theme.ButtonFillHover() return 0.16, 0.16, 0.16, 0.95 end
function Theme.ButtonFillDown()  return 0.06, 0.06, 0.06, 0.95 end

function Theme.Glyph()           return 0.78, 0.78, 0.78, 1 end
function Theme.GlyphDisabled()   return 0.32, 0.32, 0.32, 1 end

-- Destructive action (shift-hover on close = end the conversation). Muted red,
-- not pure, so it sits in the same palette as the accent.
function Theme.Danger()          return 0.90, 0.30, 0.30 end

-------------------------------------------------------------------------------
--  Fonts. When bridged we ask EUI for the path/flags under our own module key
--  ("wim"), which means the user can override the font for WIM alone from the
--  EllesmereUI font options page and we pick it up for free.
-------------------------------------------------------------------------------
local MODULE_KEY = "wim"

function Theme.FontPath()
    local E = EUI()
    if E and E.GetFontPath then
        local ok, path = pcall(E.GetFontPath, MODULE_KEY)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end
    -- Standalone: prefer EUI's default face if the media happens to be present
    -- (user has the UI installed but disabled), else Blizzard's standard font.
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function Theme.FontFlags()
    local E = EUI()
    if E and E.GetFontOutlineFlag then
        local ok, flag = pcall(E.GetFontOutlineFlag, MODULE_KEY)
        if ok and type(flag) == "string" then
            return flag
        end
    end
    return ""
end

function Theme.FontUseShadow()
    local E = EUI()
    if E and E.GetFontUseShadow then
        local ok, v = pcall(E.GetFontUseShadow, MODULE_KEY)
        if ok then return v and true or false end
    end
    return Theme.FontFlags() == ""
end
end)
