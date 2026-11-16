local addonName, ns = ...

-- ===========================================================================
-- ELLESMEREUI SKINS: FIX ADDON ISSUES (master checkbox)
-- Applies every fix defined in Compat.lua, whether or not the addon it is
-- for has a skin checkbox ticked.
-- ===========================================================================

local ES = ns:GetModule("EllesmereSkins")
local Sk = ns.ESkin

local F = ES:NewFeature{
    key    = "fixAddonIssues",
    name   = "Fix addon issues",
    desc   = "Restores API functions that patch 12.1 removed and works around known addon bugs.",
    info   = "Each fix only acts when it is needed, so it is safe to leave on.",
    reload = true,
    group  = "fixes",
    order  = 1,
}

function F:OnEnable()
    for _, id in ipairs(Sk.fixOrder) do Sk.ApplyFix(id) end
end

-- What it covers (shown under the checkbox)
for i, id in ipairs(Sk.fixOrder) do
    local note = ES:NewNote("|cffaaaaaa- " .. Sk.fixes[id].text .. "|r", 1 + i)
    note.group = "fixes"
end
