local addonName, ns = ...

-- ===========================================================================
-- SOUNDS: POTION REMINDER
-- Plays a sound when your potion comes off cooldown again. Raids and active
-- Mythic+ keys only.
--
-- How it works:
--   * The potion is learned from what you actually drink: UNIT_SPELLCAST_SUCCEEDED
--     for the player is matched against the use-spells of the potions in your
--     bags (map rebuilt on BAG_UPDATE_DELAYED). The last potion used is the one
--     tracked, and it is remembered across /reload (CXUI_DB.potionReminderItem).
--     /cxpotion item <itemID or link> pins a specific item by hand.
--   * Its cooldown is polled with C_Container.GetItemCooldown. The sound fires
--     on the "cooldown running" -> "ready" edge only, so it never plays just
--     because you have a potion in your bags.
--
-- Quiet window: for 5 s after anything that resets cooldowns / brings you back
-- (resurrection, release, encounter end = kill or wipe, key start, zone-in)
-- nothing is played; a cooldown that finishes in that window is swallowed.
-- Nothing is played while you are dead either.
--
-- Alongside the sound, "POTION READY" flashes on screen (same style as Execute Alert).
-- ===========================================================================

local S = ns:GetModule("Sounds")

local F = S:NewFeature{
    key  = "potionReminder",
    name = "Potion Reminder",
    desc = "Plays a sound when your potion is ready again (raids and Mythic+ only).",
    info = "Learns which potion you use and plays a sound the moment its cooldown ends. Only works inside raids and active Mythic+ keys. Stays silent for 5 seconds after a resurrection, an encounter end (kill/wipe) or a key start, because cooldowns reset then. Use /cxpotion for status or to pin an item.",
    sound = { kind = "kit", value = SOUNDKIT.ALARM_CLOCK_WARNING_3 or SOUNDKIT.READY_CHECK, name = "Potion Ready" },
}

local QUIET_TIME    = 5    -- seconds of silence after a cooldown-reset event
local POLL_INTERVAL = 0.5
local MIN_CD        = 2.0  -- cooldowns shorter than this are the GCD, not the potion

local ITEM_CLASS_CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local ITEM_SUB_POTION       = (Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Potion) or 1

local alertText
local alertFadeGen = 0

local spellToItem = {}   -- potion use-spellID -> itemID
local itemID             -- tracked potion
local armed = false      -- true once we have seen the tracked potion on cooldown
local quietUntil = 0

local function Debug(...)
    if CXUI_PotionDebug then print("|cff33ccff[cxUI Potion]|r", ...) end
end

local function InQuietWindow()
    return GetTime() < quietUntil
end

local function StartQuietWindow(reason)
    quietUntil = GetTime() + QUIET_TIME
    Debug("quiet window:", reason)
end

-- Raid, or a Mythic+ key that is actually running.
local function InValidContent()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    if instanceType == "raid" then return true end
    if instanceType == "party" and C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        return C_ChallengeMode.GetActiveChallengeMapID() ~= nil
    end
    return false
end

local function ScanBags()
    local maxBag = (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 1)
    for bag = 0, maxBag do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then
                local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
                if classID == ITEM_CLASS_CONSUMABLE and subClassID == ITEM_SUB_POTION then
                    local _, spellID = C_Item.GetItemSpell(id)
                    if spellID then spellToItem[spellID] = id end
                end
            end
        end
    end
end

-- Returns start, duration or nil when the value cannot be read.
local function ReadCooldown(id)
    local ok, start, duration = pcall(C_Container.GetItemCooldown, id)
    if not ok or start == nil or duration == nil then return end
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return end
    return start, duration
end

local function SetTracked(id)
    itemID = id
    armed = false
    CXUI_DB.potionReminderItem = id
end

local function FlashText()
    alertFadeGen = alertFadeGen + 1
    local myGen = alertFadeGen
    alertText:Show()
    UIFrameFadeIn(alertText, 0.1, alertText:GetAlpha(), 1)
    F:After(1.5, function()
        if alertFadeGen ~= myGen then return end -- superseded by a newer flash
        UIFrameFadeOut(alertText, 0.6, alertText:GetAlpha(), 0)
        F:After(0.6, function()
            if alertFadeGen == myGen then alertText:Hide() end
        end)
    end)
end

local function Poll()
    if not itemID then return end

    local start, duration = ReadCooldown(itemID)
    if not start then return end

    local onCooldown = duration > MIN_CD and (start + duration - GetTime()) > 0.05
    if onCooldown then
        armed = true
        return
    end
    if not armed then return end

    -- cooldown ended
    armed = false
    if InQuietWindow() then Debug("ready, but inside quiet window -> silent"); return end
    if UnitIsDeadOrGhost("player") then Debug("ready, but dead -> silent"); return end
    if not InValidContent() then Debug("ready, but not raid/key -> silent"); return end

    Debug("potion ready -> sound")
    F:PlaySound()
    FlashText()
end

local function OnEvent(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if issecretvalue and issecretvalue(spellID) then return end
        local id = spellID and spellToItem[spellID]
        if id then
            if CXUI_DB.potionReminderPinned then return end -- pinned item wins
            SetTracked(id)
            Debug("tracking potion item", id)
        end

    elseif event == "BAG_UPDATE_DELAYED" then
        ScanBags()

    elseif event == "PLAYER_ENTERING_WORLD" then
        StartQuietWindow("entering world")
        ScanBags()

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        StartQuietWindow("alive/unghost")

    elseif event == "ENCOUNTER_END" or event == "CHALLENGE_MODE_START" or event == "RESURRECT_REQUEST" then
        StartQuietWindow(event)
    end
end

function F:OnEnable()
    if not alertText then
        alertText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        alertText:SetFont((alertText:GetFont()), 32, "OUTLINE")
        alertText:SetTextColor(0.2, 1, 0.4, 1)
        alertText:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
        alertText:SetText("POTION READY")
        alertText:SetAlpha(0)
        alertText:Hide()
    end

    itemID = CXUI_DB.potionReminderItem
    armed = false
    StartQuietWindow("enable")
    ScanBags()

    local ev = self:NewEventFrame()
    ev:SetScript("OnEvent", OnEvent)
    for _, e in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "ENCOUNTER_END",
        "CHALLENGE_MODE_START", "RESURRECT_REQUEST", "BAG_UPDATE_DELAYED",
    }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

    self:NewTicker(POLL_INTERVAL, Poll)
end

function F:OnDisable()
    armed = false
    alertFadeGen = alertFadeGen + 1
    if alertText then alertText:SetAlpha(0); alertText:Hide() end
end

SLASH_CXPOTION1 = "/cxpotion"
SlashCmdList["CXPOTION"] = function(msg)
    msg = (msg or ""):trim()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "debug" then
        CXUI_PotionDebug = not CXUI_PotionDebug
        ns.Print("Potion debug", CXUI_PotionDebug and "ON" or "OFF")

    elseif cmd == "item" then
        if arg == "" or arg:lower() == "auto" then
            CXUI_DB.potionReminderPinned = nil
            ns.Print("Potion: auto (tracks the last potion you used)")
            return
        end
        local id = tonumber(arg) or tonumber(arg:match("item:(%d+)"))
        if not id then ns.Print("Usage: /cxpotion item <itemID | item link | auto>"); return end
        CXUI_DB.potionReminderPinned = true
        SetTracked(id)
        ns.Print("Potion pinned to item", id, "(" .. (C_Item.GetItemNameByID(id) or "?") .. ")")

    elseif cmd == "test" then
        F:PlaySound()
        if alertText then FlashText() else ns.Print("Enable the feature first to preview the text") end

    else
        local start, duration = itemID and ReadCooldown(itemID)
        ns.Print("Potion Reminder:", F:IsOn() and "on" or "off")
        print("  tracked item:", itemID and (itemID .. " " .. (C_Item.GetItemNameByID(itemID) or "")) or "none yet (drink a potion)",
            CXUI_DB.potionReminderPinned and "[pinned]" or "[auto]")
        print("  cooldown:", start and (duration > MIN_CD and ("%.0fs left"):format(math.max(0, start + duration - GetTime())) or "ready") or "unknown")
        print("  valid content (raid/key):", InValidContent() and "yes" or "no", "| quiet window:", InQuietWindow() and "yes" or "no")
        print("  usage: /cxpotion item <id|link|auto> | test | debug")
    end
end
