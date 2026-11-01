local addonName, ns = ...

-- ===========================================================================
-- MODULE: MACROS
-- A replacement for the Mega Macro idea: macros are stored in our own
-- SavedVariable (CXUI_MacroDB), split into General / Class / Spec / Character
-- (+ an Archive that is never bound), and the ones that belong to the current
-- character are copied into the game's native macro slots. Native slots are
-- permanent "vessels" (tagged "#NNN" on the first line), so action-bar buttons
-- keep pointing at the same slot while its content changes with your spec.
--
-- Files (load order matters, see cxUI.toc):
--   Macros.lua        this file: module registration + shared constants
--   Store.lua         database access, class / spec helpers
--   Slots.lua         native macro slot engine (scan / create / edit / sync)
--   Highlight.lua     macro syntax colouring
--   Icons.lua         icon lists + spell-name index for icon search
--   UI.lua            small flat widget helpers (cxUI look)
--   IconPicker.lua    icon picker window
--   Import.lua        Mega Macro import + adopting untagged native macros
--   Window.lua        the macro window (scope tabs, class / spec strips, editor)
--   MacroManager.lua  the feature: events + slash commands
-- ===========================================================================

ns:NewModule("Macros", {
    name  = "Macros",
    desc  = "General / class / spec / character macros with a browsable window",
    order = 10,
})

ns.Macros = ns.Macros or {}
local M = ns.Macros

M.NAME_MAX        = 32     -- longest name we store (what you see in the window)
M.NATIVE_NAME_MAX = 18     -- what is written to the game's macro slot (same cut Mega Macro used)
M.BODY_MAX     = 250       -- 255 minus the "#NNN\n" tag
M.NATIVE_MAX   = 255
M.DEFAULT_ICON = 134400    -- the question mark: with #showtooltip the game shows the real icon

-- Tab order. `first` is the id offset (macro id = first + slot); ids are the same
-- as Mega Macro's, so existing "#NNN" tags in your native macros keep working.
M.scopes = {
    { key = "general", label = "General",   first = 0,   count = 60, bound = true  },
    { key = "class",   label = "Class",     first = 60,  count = 30, bound = true  },
    { key = "spec",    label = "Spec",      first = 90,  count = 30, bound = true  },
    { key = "char",    label = "Character", first = 120, count = 30, bound = true, perChar = true },
    { key = "archive", label = "Archive",   first = nil, count = 60, bound = false },
}
M.scopeByKey = {}
for _, sc in ipairs(M.scopes) do M.scopeByKey[sc.key] = sc end

-- Highest id that lives in the account-wide native space (ids above are per-character).
M.ACCOUNT_IDS = 120
