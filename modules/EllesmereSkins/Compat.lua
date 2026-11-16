local addonName, ns = ...

-- ===========================================================================
-- ELLESMEREUI SKINS: FIXES
-- Each fix is idempotent and steps aside when it isn't needed (the function
-- is already there, the addon isn't installed, the addon got patched).
-- Fixes run when "Fix addon issues" is ticked, or when a skin checkbox of an
-- addon that needs them is ticked (see `fixes = {...}` in Skins/<Addon>.lua).
-- ===========================================================================

local Sk = ns.ESkin

-- ---------------------------------------------------------------------------
-- MouseIsOver
-- Patch 12.1 removed it with no deprecated wrapper. Rematch calls it from 14
-- places (the journal window opens blank), M33kAuras' options, BtWQuests and
-- BattlePetBattleUITweaks call it too. The 12.0.7 implementation was a plain
-- pass-through to region:IsMouseOver.
-- ---------------------------------------------------------------------------
Sk.DefineFix("MouseIsOver",
    "MouseIsOver() was removed in 12.1: Rematch, M33kAuras options, BtWQuests, BattlePetBattleUITweaks",
    function()
        if type(_G.MouseIsOver) == "function" then return end
        _G.MouseIsOver = function(region, topOffset, bottomOffset, leftOffset, rightOffset)
            return region:IsMouseOver(topOffset, bottomOffset, leftOffset, rightOffset)
        end
    end)

-- ---------------------------------------------------------------------------
-- GetItemInfoInstant
-- The bare global is gone; the function lives in C_Item. CollectionLog calls
-- the global in dozens of places and has no fallback (its Appearance sets tab
-- throws). Other addons that capture it into a local at load are unaffected
-- either way.
-- ---------------------------------------------------------------------------
Sk.DefineFix("GetItemInfoInstant",
    "GetItemInfoInstant() global is gone: CollectionLog (Appearance sets tab)",
    function()
        if type(_G.GetItemInfoInstant) == "function" then return end
        if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
            _G.GetItemInfoInstant = C_Item.GetItemInfoInstant
        end
    end)

-- ---------------------------------------------------------------------------
-- Rematch: NPC names hidden inside instances
-- In dungeons, delves and scenarios the client hands addons the first line of
-- a unit tooltip as a SECRET string. Rematch reads an NPC's name that way and
-- calls name:len() on it, which throws from inside rematch.frame:Configure
-- (it lays out every panel in one pass), so one unreadable name blanks the
-- whole window. GetNpcName is wrapped in a pcall; on failure Rematch's own
-- "Unknown (npc id N)" wording is returned and nothing is cached, so the name
-- resolves normally once the player leaves the instance.
-- ---------------------------------------------------------------------------
Sk.DefineFix("RematchHiddenNames",
    "Rematch: window blanked by NPC names the client hides inside instances",
    function()
        Sk.WhenLoaded("Rematch", function()
            local rematch = _G.Rematch
            local targetInfo = rematch and rematch.targetInfo
            local original = targetInfo and targetInfo.GetNpcName
            if type(original) ~= "function" or not _G.issecretvalue then return end
            if targetInfo.cxUIWrappedNpcName then return end
            targetInfo.cxUIWrappedNpcName = true

            local pcall, type, tonumber, format, GetTime = pcall, type, tonumber, format, GetTime
            local UNKNOWN = _G.UNKNOWN or "Unknown"
            local REFUSED_FOR = 5   -- seconds a refused name is remembered, so a refresh doesn't rescan every row
            local refusedAt = {}

            local function fallbackName(npcID)
                local id = npcID
                if type(id) == "string" then id = tonumber(id:match("target:(%d+)")) end
                if type(id) ~= "number" then return UNKNOWN end
                local L = rematch.localization
                local pattern = (L and L["%s (npc id %d)"]) or "%s (npc id %d)"
                local name = format(pattern, UNKNOWN, id)
                local subnames = rematch.targetData and rematch.targetData.subnames
                local sub = subnames and subnames[id]
                if sub then name = name .. format(" (%s)", sub) end
                return name
            end

            targetInfo.GetNpcName = function(self, npcID, noDisplay)
                local when = refusedAt[npcID]
                if when and GetTime() - when < REFUSED_FOR then return fallbackName(npcID) end
                local ok, name = pcall(original, self, npcID, noDisplay)
                if ok then
                    refusedAt[npcID] = nil
                    return name
                end
                refusedAt[npcID] = GetTime()
                return fallbackName(npcID)
            end
        end)
    end)

-- ---------------------------------------------------------------------------
-- PetTracker: the Rivals tab next to Rematch's journal
-- PetTracker adds a "Rivals" tab to the Collections journal (through
-- SecureTabs-2.0: PetTrackerRivalsJournal.PanelTab). Its page is laid over the
-- journal and collides with Rematch's panels, so with Rematch installed the
-- tab is hidden (the rest of PetTracker is untouched). The journal is built
-- when the Collections window first loads, so the tab is looked for again then.
-- ---------------------------------------------------------------------------
local function HideRivalsTab()
    local journal = _G.PetTrackerRivalsJournal
    local tab = journal and journal.PanelTab
    if not tab then return false end
    tab:Hide()
    if not tab.cxUIKeepHidden then
        tab.cxUIKeepHidden = true
        hooksecurefunc(tab, "Show", function(self) self:Hide() end)
    end
    return true
end

Sk.DefineFix("HidePetTrackerRivals",
    "PetTracker: its Rivals tab collides with Rematch's journal and is hidden",
    function()
        if not (C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Rematch")) then return end
        local function Look(triesLeft)
            if HideRivalsTab() or triesLeft <= 0 then return end
            C_Timer.After(0.5, function() Look(triesLeft - 1) end)
        end
        Look(10)                                        -- already built (Collections was loaded at login)
        Sk.WhenLoaded("Blizzard_Collections", function() Look(20) end)  -- or built when it first opens
    end)
