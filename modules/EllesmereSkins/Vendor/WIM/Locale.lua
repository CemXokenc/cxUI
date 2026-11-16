local _, cxns = ...
-- Vendored from EllesmereSkin_WIM/Locale.lua, unchanged.
-- Wrapped in a function so cxUI can run it once the addon it skins has loaded
-- (see Sk.RunChunks in EllesmereSkins.lua). Its own header follows.
local chunks = cxns.ESkin.chunks
chunks.WIM = chunks.WIM or {}
table.insert(chunks.WIM, function(...)
-------------------------------------------------------------------------------
--  EllesmereSkin_WIM -- Locale.lua
--  FR / EN strings. Kept tiny on purpose: a skin has almost no user-facing text.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local L = {}
ns.L = L

-- enUS / default -------------------------------------------------------------
L["SKIN_TITLE"]       = "EllesmereUI"
L["SKIN_TITLE_LIGHT"] = "EllesmereUI - Light"
L["SKIN_NOTES"]       = "Pixel-perfect EllesmereUI style for WIM."
L["EUI_DETECTED"]     = "EllesmereUI detected -- using its live theme and border engine."
L["EUI_STANDALONE"]   = "EllesmereUI not found -- using built-in standalone theme."
L["APPLY_HINT"]       = "Select the '%s' skin in WIM options (/wim -> Skin).";

-- frFR -----------------------------------------------------------------------
if GetLocale() == "frFR" then
    L["SKIN_NOTES"]     = "Style EllesmereUI pixel-perfect pour WIM."
    L["EUI_DETECTED"]   = "EllesmereUI detecte -- utilisation de son theme et de son moteur de bordures."
    L["EUI_STANDALONE"] = "EllesmereUI introuvable -- utilisation du theme autonome integre."
    L["APPLY_HINT"]     = "Selectionnez le skin '%s' dans les options de WIM (/wim -> Skin).";
end

-- Fall back to the key itself for anything missing, so a typo shows up as the
-- key rather than a nil concat error.
setmetatable(L, { __index = function(_, k) return k end })
end)
