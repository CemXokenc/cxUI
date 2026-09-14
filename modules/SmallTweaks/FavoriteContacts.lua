local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: FAVORITE CONTACTS
-- Concept ported from eXochron's standalone "Favorite Contacts" addon, but
-- rewritten from scratch as a single lightweight file with no external
-- libraries (no AceGUI/LibStub) and no separate settings UI. Visually it
-- matches the original addon's button look (same size/margin, same default
-- contact icon, same empty-slot texture): a small panel of cells appears
-- next to the mailbox. Click a filled cell to instantly fill in that
-- recipient; click an empty cell to add a new one; right-click a filled
-- cell for a context menu (change icon / delete).
-- ===========================================================================

local BUTTON_SIZE   = 36  -- same as original addon's CONTACT_BUTTON_SIZE
local BUTTON_GAP    = 3   -- same as original addon's CONTACT_BUTTON_MARGIN
local COLUMNS       = 2
local MAX_CONTACTS  = 20

local DEFAULT_ICON       = "INV_Misc_GroupLooking" -- same default icon as original addon
local EMPTY_SLOT_TEXTURE = 4701874 -- interface/containerframe/bagsitemslot2x, same empty-slot look as original addon

-- Icon choices offered in the picker: the default + the main gathering/
-- crafting professions (no Cooking/Fishing/Archaeology/First Aid).
local ICON_CHOICES = {
    DEFAULT_ICON,
    "Trade_Alchemy",                -- Alchemy
    "Trade_BlacksmithING",          -- Blacksmithing
    "Trade_Engraving",              -- Enchanting
    "Trade_Engineering",            -- Engineering
    "Trade_Herbalism",              -- Herbalism
    "INV_Inscription_Tradeskill01", -- Inscription
    "INV_Misc_Gem_02",              -- Jewelcrafting
    "Trade_LeatherWorking",         -- Leatherworking
    "Trade_Mining",                 -- Mining
    "INV_Misc_Pelt_Wolf_01",        -- Skinning
    "Trade_Tailoring",              -- Tailoring
}

local function IsEnabled()
    return CXUI_DB.favoriteContacts
end

-- Returns the saved contact list, migrating old plain-string entries
-- (from before per-contact icons existed) into { name = ..., icon = ... }.
local function GetList()
    CXUI_DB.favoriteContactsList = CXUI_DB.favoriteContactsList or {}
    local list = CXUI_DB.favoriteContactsList
    for i, entry in ipairs(list) do
        if type(entry) == "string" then
            list[i] = { name = entry, icon = DEFAULT_ICON }
        end
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Popups: add / remove a contact
-- ---------------------------------------------------------------------------
StaticPopupDialogs["CXUI_FAVCONTACT_ADD"] = {
    text = "Enter character name (Name or Name-Realm):",
    button1 = SAVE or "Save",
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 48,
    OnShow = function(self)
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = self.EditBox:GetText()
        if name then name = name:trim() end
        if name and name ~= "" then
            local list = GetList()
            if #list < MAX_CONTACTS then
                local index = #list + 1
                table.insert(list, { name = name, icon = DEFAULT_ICON })
                if ns.CXUI_FavoriteContacts_Refresh then ns.CXUI_FavoriteContacts_Refresh() end
                -- Let the player immediately pick an icon for the new contact.
                if data and data.button and ns.CXUI_FavoriteContacts_ShowIconPicker then
                    ns.CXUI_FavoriteContacts_ShowIconPicker(data.button, index)
                end
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent().button1:Click()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["CXUI_FAVCONTACT_REMOVE"] = {
    text = "Remove '%s' from Favorite Contacts?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        local list = GetList()
        table.remove(list, data.index)
        if ns.CXUI_FavoriteContacts_Refresh then ns.CXUI_FavoriteContacts_Refresh() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ---------------------------------------------------------------------------
-- Behaviour: clicking a filled cell fills the recipient and jumps to it
-- ---------------------------------------------------------------------------
local function UseContact(name)
    if not (MailFrame and MailFrame:IsShown()) then return end
    MailFrameTab_OnClick(nil, 2) -- switch to "Send Mail" tab
    SendMailNameEditBox:SetText(name)
    local handler = SendMailNameEditBox:GetScript("OnTextChanged")
    if handler then handler(SendMailNameEditBox, name) end
    SendMailSubjectEditBox:SetFocus()
end

-- ---------------------------------------------------------------------------
-- Icon picker: a small popup grid of icon buttons anchored below whichever
-- cell was clicked. Reused for both "add" (pick icon for a new contact) and
-- the right-click context menu's "Change Icon" option.
-- ---------------------------------------------------------------------------
local ICON_PICKER_COLUMNS = 4
local ICON_BUTTON_SIZE    = 30
local ICON_BUTTON_GAP     = 4

local iconPicker
local iconPickerTargetIndex

local function ApplyIconChoice(iconName)
    local list = GetList()
    local entry = list[iconPickerTargetIndex]
    if entry then
        entry.icon = iconName
        if ns.CXUI_FavoriteContacts_Refresh then ns.CXUI_FavoriteContacts_Refresh() end
    end
    if iconPicker then iconPicker:Hide() end
end

local function CreateIconPicker()
    local frame = CreateFrame("Frame", "CXUI_FavoriteContactsIconPicker", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.95)

    local rows = math.ceil(#ICON_CHOICES / ICON_PICKER_COLUMNS)
    local width = ICON_PICKER_COLUMNS * (ICON_BUTTON_SIZE + ICON_BUTTON_GAP) + ICON_BUTTON_GAP
    local height = rows * (ICON_BUTTON_SIZE + ICON_BUTTON_GAP) + ICON_BUTTON_GAP + 16
    frame:SetSize(width, height)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 4, 4)
    close:SetSize(20, 20)

    for i, iconName in ipairs(ICON_CHOICES) do
        local btn = CreateFrame("Button", nil, frame, "ActionButtonTemplate")
        btn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
        btn:SetNormalTexture(0)
        btn:SetPushedTexture(0)
        if btn:GetHighlightTexture() then
            btn:GetHighlightTexture():SetAllPoints(btn)
        end
        btn.icon:SetTexture("Interface\\Icons\\" .. iconName)
        btn.icon:SetTexCoord(0, 1, 0, 1)
        btn.icon:Show()

        local column = (i - 1) % ICON_PICKER_COLUMNS
        local row = math.floor((i - 1) / ICON_PICKER_COLUMNS)
        btn:SetPoint("TOPLEFT",
            ICON_BUTTON_GAP + column * (ICON_BUTTON_SIZE + ICON_BUTTON_GAP),
            -(ICON_BUTTON_GAP + 16 + row * (ICON_BUTTON_SIZE + ICON_BUTTON_GAP)))

        btn:SetScript("OnClick", function() ApplyIconChoice(iconName) end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(iconName)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    frame:Hide()
    return frame
end

function ns.CXUI_FavoriteContacts_ShowIconPicker(anchorButton, index)
    if not iconPicker then
        iconPicker = CreateIconPicker()
    end
    iconPickerTargetIndex = index
    iconPicker:ClearAllPoints()
    iconPicker:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -4)
    iconPicker:Show()
end

-- ---------------------------------------------------------------------------
-- Right-click context menu (change icon / delete), using the same modern
-- Menu API the original addon used.
-- ---------------------------------------------------------------------------
local function GenerateContactContextMenu(ownerRegion, rootDescription, index)
    local list = GetList()
    local entry = list[index]
    if not entry then return end

    rootDescription:CreateButton("Change Icon", function()
        ns.CXUI_FavoriteContacts_ShowIconPicker(ownerRegion, index)
    end)
    rootDescription:CreateButton(DELETE, function()
        StaticPopup_Show("CXUI_FAVCONTACT_REMOVE", entry.name, nil, { index = index })
    end)
    rootDescription:CreateButton(CANCEL, function() end)
end

local function OpenContactContextMenu(button)
    local menuDescription = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
    Menu.PopulateDescription(GenerateContactContextMenu, button, menuDescription, button.index)
    local anchor = CreateAnchor("TOPLEFT", button, "BOTTOMLEFT", 0, 0)
    Menu.GetManager():OpenMenu(button, menuDescription, anchor)
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
local container
local buttons = {}

local function CreateCell(index)
    local button = buttons[index]
    if button then return button end

    button = CreateFrame("Button", nil, container, "ActionButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetNormalTexture(0)
    button:SetPushedTexture(0)
    if button:GetHighlightTexture() then
        button:GetHighlightTexture():SetAllPoints(button)
    end

    button:SetScript("OnEnter", function(self)
        if self.name then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.name)
            GameTooltip:AddLine("Left-Click: use this recipient", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Right-Click: change icon / remove", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        elseif self.isAdd then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Add a favorite contact")
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if self.name then
            if mouseButton == "RightButton" then
                OpenContactContextMenu(self)
            else
                UseContact(self.name)
            end
        elseif self.isAdd then
            StaticPopup_Show("CXUI_FAVCONTACT_ADD", nil, nil, { button = self })
        end
    end)

    buttons[index] = button
    return button
end

local function UpdateCell(index, name, iconName, isAdd)
    local button = CreateCell(index)
    button.index = index
    button.name = name
    button.isAdd = isAdd

    if name then
        button.icon:SetTexture("Interface\\Icons\\" .. (iconName or DEFAULT_ICON))
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
    elseif isAdd then
        button.icon:SetTexture(EMPTY_SLOT_TEXTURE)
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
    end
    button.icon:Show()

    local column = (index - 1) % COLUMNS
    local row = math.floor((index - 1) / COLUMNS)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", (BUTTON_SIZE + BUTTON_GAP) * column, -(BUTTON_SIZE + BUTTON_GAP) * row)
    button:Show()
end

local function RepositionOpenMailFrame(extraWidth)
    if not OpenMailFrame or not InboxFrame then return end
    OpenMailFrame:ClearAllPoints()
    if extraWidth and extraWidth > 0 then
        OpenMailFrame:SetPoint("TOPLEFT", InboxFrame, "TOPRIGHT", extraWidth + BUTTON_GAP, 0)
    else
        OpenMailFrame:SetPoint("TOPLEFT", InboxFrame, "TOPRIGHT", 0, 0)
    end
    if UpdateUIPanelPositions then UpdateUIPanelPositions(OpenMailFrame) end
end

local function EnsureContainer()
    if container then return container end

    container = CreateFrame("Frame", "CXUI_FavoriteContactsPanel", MailFrame)
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(MailFrame:GetFrameLevel() + 10)
    container:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", BUTTON_GAP, -28)

    return container
end

function ns.CXUI_FavoriteContacts_Refresh()
    if not IsEnabled() then
        if container then container:Hide() end
        if iconPicker then iconPicker:Hide() end
        RepositionOpenMailFrame(0)
        return
    end

    EnsureContainer()

    local list = GetList()
    local cellCount = math.min(#list + 1, MAX_CONTACTS)
    local rows = math.ceil(cellCount / COLUMNS)

    for i = 1, cellCount do
        if i <= #list then
            local entry = list[i]
            UpdateCell(i, entry.name, entry.icon, false)
        else
            UpdateCell(i, nil, nil, true)
        end
    end
    for i = cellCount + 1, #buttons do
        buttons[i]:Hide()
    end

    local width = COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * BUTTON_GAP
    local height = rows * BUTTON_SIZE + math.max(rows - 1, 0) * BUTTON_GAP
    container:SetSize(width, height)

    if MailFrame:IsShown() then
        container:Show()
    end

    RepositionOpenMailFrame(width + BUTTON_GAP)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MAIL_CLOSED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_MailFrame" then
        return
    end
    if event == "MAIL_CLOSED" then
        if container then container:Hide() end
        if iconPicker then iconPicker:Hide() end
        return
    end
    -- ADDON_LOADED(Blizzard_MailFrame) or MAIL_SHOW
    if MailFrame then
        ns.CXUI_FavoriteContacts_Refresh()
    end
end)