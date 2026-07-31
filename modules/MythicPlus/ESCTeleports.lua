local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MODULE: MYTHIC+ -> ESC MENU DUNGEON TELEPORTS
--
-- Adds a vertical column of clickable dungeon-teleport buttons (abbreviated
-- name + icon), anchored to the Game Menu (the panel opened by pressing
-- ESC). Same look/behaviour as the equivalent feature in MDungeonTeleports'
-- Mythic+ tab, just re-anchored and re-implemented standalone here.
--
-- Clicking a button casts that dungeon's teleport spell (secure click,
-- works in combat). Icons desaturate and show a tooltip warning if the
-- spell hasn't been learned yet. A small cooldown timer overlays the icon
-- while the teleport is on cooldown.
-- ---------------------------------------------------------------------------

-- Current season (Midnight S1) Mythic+ dungeon teleports.
-- Update this list at the start of each new M+ season.
local DUNGEONS = {
    {icon = "Interface\\Icons\\achievement_dungeon_dragonacademy",        spellID = 393273,  name = "AA"},
    {icon = "Interface\\Icons\\inv_achievement_dungeon_maisarahills",     spellID = 1254559, name = "MC"},
    {icon = "Interface\\Icons\\inv_achievement_dungeon_magistersterrace", spellID = 1254572, name = "MT"},
    {icon = "Interface\\Icons\\inv_achievement_dungeon_nexuspointxenas",  spellID = 1254563, name = "NPX"},
    {icon = "Interface\\Icons\\achievement_dungeon_icecrown_pitofsaron",  spellID = 1254555, name = "POS"},
    {icon = "Interface\\Icons\\achievement_dungeon_argusdungeon",         spellID = 1254551, name = "SEAT"},
    {icon = "Interface\\Icons\\achievement_dungeon_arakkoaspires",        spellID = 159898,  name = "SR"},
    {icon = "Interface\\Icons\\inv_achievement_dungeon_windrunnerspire",  spellID = 1254400, name = "WS"},
}

local function IsEnabled()
    return CXUI_DB and CXUI_DB.escTeleportButtons
end

local buttons = {}
local container
local cooldownTicker

-- ---------------------------------------------------------------------------
-- Cooldown / learned-state helpers
-- ---------------------------------------------------------------------------
local function UpdateButtonTexture(btn)
    local known = C_SpellBook.IsSpellInSpellBook(btn.spellID, nil, true)
    btn.icon:SetDesaturated(not known)
end

local function SnapshotCooldown(btn)
    if not C_SpellBook.IsSpellInSpellBook(btn.spellID, nil, true) then
        btn.cdStart, btn.cdDuration = 0, 0
        return
    end
    local cd = C_Spell.GetSpellCooldown(btn.spellID)
    if not cd or issecretvalue(cd.duration) or issecretvalue(cd.startTime) then
        btn.cdStart, btn.cdDuration = 0, 0
        return
    end
    if cd.isEnabled and cd.duration and cd.duration > 0 and cd.startTime and cd.startTime > 0 then
        btn.cdStart, btn.cdDuration = cd.startTime, cd.duration
    else
        btn.cdStart, btn.cdDuration = 0, 0
    end
end

local function RefreshCooldownText(btn)
    if btn.cdStart == 0 then
        if btn.cdText:GetText() ~= "" then btn.cdText:SetText("") end
        return
    end
    local remaining = btn.cdStart + btn.cdDuration - GetTime()
    if remaining <= 0 then
        btn.cdText:SetText("")
        btn.cdStart, btn.cdDuration = 0, 0
        return
    end
    local text
    if remaining >= 3600 then
        text = math.floor(remaining / 3600) .. "h"
    elseif remaining >= 60 then
        text = math.floor(remaining / 60) .. "m"
    else
        text = math.floor(remaining) .. "s"
    end
    btn.cdText:SetText(text)
end

local function StartTicking()
    if cooldownTicker then return end
    cooldownTicker = C_Timer.NewTicker(1, function()
        for _, btn in ipairs(buttons) do RefreshCooldownText(btn) end
    end)
    for _, btn in ipairs(buttons) do
        UpdateButtonTexture(btn)
        SnapshotCooldown(btn)
        RefreshCooldownText(btn)
    end
end

local function StopTicking()
    if cooldownTicker then
        cooldownTicker:Cancel()
        cooldownTicker = nil
    end
end

-- ---------------------------------------------------------------------------
-- Button + container construction
-- ---------------------------------------------------------------------------
local function CreateButton(parent, data, yOffset)
    local size = 30

    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", data.spellID)
    btn.spellID = data.spellID

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture(data.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.25)

    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 0.8)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    label:SetText(data.name)

    local cdText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdText:SetPoint("CENTER")
    btn.cdText = cdText

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local info = C_Spell.GetSpellInfo(self.spellID)
        GameTooltip:SetText(info and info.name or data.name, 1, 1, 1)
        if not C_SpellBook.IsSpellInSpellBook(self.spellID, nil, true) then
            GameTooltip:AddLine("Spell not learned", 1, 0.2, 0.2)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterEvent("SPELLS_CHANGED")
    btn:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    btn:SetScript("OnEvent", function(self, event)
        if event == "CHALLENGE_MODE_COMPLETED" then
            -- Cooldown starts a moment after the vignette fires; give it a beat.
            C_Timer.After(2, function()
                UpdateButtonTexture(self); SnapshotCooldown(self); RefreshCooldownText(self)
            end)
        else
            UpdateButtonTexture(self); SnapshotCooldown(self); RefreshCooldownText(self)
        end
    end)

    btn.cdStart, btn.cdDuration = 0, 0
    return btn
end

local function BuildContainer()
    if container then return end

    container = CreateFrame("Frame", "CXUI_ESCTeleports", GameMenuFrame)
    container:SetSize(40, #DUNGEONS * 34 + 10)
    -- Hangs off the right edge of the Game Menu. Adjust the offsets here if
    -- it overlaps another addon's ESC-menu buttons on your setup.
    container:SetPoint("TOPLEFT", GameMenuFrame, "TOPRIGHT", -5, 0)

    local yOffset = -6
    for _, data in ipairs(DUNGEONS) do
        local btn = CreateButton(container, data, yOffset)
        buttons[#buttons + 1] = btn
        yOffset = yOffset - 34
    end
end

-- Called from the options checkbox so toggling takes effect immediately
-- if the Game Menu happens to already be open.
function ns.CXUI_ESCTeleports_Refresh()
    if not container then return end
    container:SetShown(IsEnabled() and GameMenuFrame:IsShown())
end

GameMenuFrame:HookScript("OnShow", function()
    if not IsEnabled() then return end
    if InCombatLockdown() then return end
    BuildContainer()
    container:Show()
    StartTicking()
end)

GameMenuFrame:HookScript("OnHide", function()
    if container then container:Hide() end
    StopTicking()
end)
