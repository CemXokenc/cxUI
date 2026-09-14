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
-- cell to remove it.
-- ===========================================================================

local BUTTON_SIZE   = 36  -- same as original addon's CONTACT_BUTTON_SIZE
local BUTTON_GAP    = 3   -- same as original addon's CONTACT_BUTTON_MARGIN
local COLUMNS       = 2
local MAX_CONTACTS  = 20

local DEFAULT_ICON       = "Interface\\Icons\\INV_Misc_GroupLooking" -- same default icon as original addon
local EMPTY_SLOT_TEXTURE = 4701874 -- interface/containerframe/bagsitemslot2x, same empty-slot look as original addon

local function IsEnabled()
    return CXUI_DB.favoriteContacts
end

local function GetList()
    CXUI_DB.favoriteContactsList = CXUI_DB.favoriteContactsList or {}
    return CXUI_DB.favoriteContactsList
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
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        if name then name = name:trim() end
        if name and name ~= "" then
            local list = GetList()
            if #list < MAX_CONTACTS then
                table.insert(list, name)
                if ns.CXUI_FavoriteContacts_Refresh then ns.CXUI_FavoriteContacts_Refresh() end
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
            GameTooltip:AddLine("Right-Click: remove", 0.6, 0.6, 0.6, true)
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
                StaticPopup_Show("CXUI_FAVCONTACT_REMOVE", self.name, nil, { index = self.index })
            else
                UseContact(self.name)
            end
        elseif self.isAdd then
            StaticPopup_Show("CXUI_FAVCONTACT_ADD")
        end
    end)

    buttons[index] = button
    return button
end

local function UpdateCell(index, name, isAdd)
    local button = CreateCell(index)
    button.index = index
    button.name = name
    button.isAdd = isAdd

    if name then
        button.icon:SetTexture(DEFAULT_ICON)
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
        RepositionOpenMailFrame(0)
        return
    end

    EnsureContainer()

    local list = GetList()
    local cellCount = math.min(#list + 1, MAX_CONTACTS)
    local rows = math.ceil(cellCount / COLUMNS)

    for i = 1, cellCount do
        if i <= #list then
            UpdateCell(i, list[i], false)
        else
            UpdateCell(i, nil, true)
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
        return
    end
    -- ADDON_LOADED(Blizzard_MailFrame) or MAIL_SHOW
    if MailFrame then
        ns.CXUI_FavoriteContacts_Refresh()
    end
end)