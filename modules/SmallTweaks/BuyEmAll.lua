local addonName, ns = ...

-- ===========================================================================
-- MODULE: SMALL TWEAKS -> BUY EM ALL
--
-- Replaces the default Shift-Click "buy multiple" popup at vendors with a
-- proper Max/Stack purchase window: buy the largest amount that fits in your
-- bags (or that you can afford), buy in preset stack increments, type an
-- exact amount, or fine-tune with arrow buttons -- all without spamming
-- Shift-Click.
--
-- Ported as closely as possible from the standalone "BuyEmAll" addon by
-- Jordy141 (https://www.curseforge.com/wow/addons/buyemall), rebuilt here as
-- a pure-Lua frame (no separate XML file) and folded into CXUI_DB so it can
-- be toggled from the cxUI options panel like every other Small Tweak.
-- English only -- the original's other locales weren't ported.
-- ===========================================================================

local strmatch, floor, ceil, min = string.match, math.floor, math.ceil, math.min

local function IsEnabled()
    return CXUI_DB and CXUI_DB.buyEmAll
end

-- Strings shown on the window itself (buttons, tooltips, confirmation popup).
local L = {
    MAX          = "Max",
    STACK        = "Stack",
    CONFIRM      = "Are you sure you want to buy\n %d \195\151 %s?",
    STACK_PURCH  = "Stack purchase",
    STACK_SIZE   = "Stack size",
    PARTIAL      = "Partial stack",
    MAX_PURCH    = "Maximum purchase",
    FIT          = "You can fit",
    AFFORD       = "You can afford",
    AVAILABLE    = "Vendor has",
}

-- BEA holds all the purchase-window state, the same way the original
-- addon's "self" (its BuyEmAll global table) did.
local BEA = {}

------------------------------------------------------------
-- Frame construction (replaces BuyEmAll.xml)
------------------------------------------------------------

local frame = CreateFrame("FRAME", "CXUI_BuyEmAllFrame", UIParent)
frame:Hide()
frame:SetToplevel(true)
frame:SetFrameStrata("HIGH")
frame:EnableMouse(true)
frame:EnableKeyboard(true)
frame:SetSize(230, 134)

local topTex = frame:CreateTexture(nil, "BACKGROUND")
topTex:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame2")
topTex:SetSize(230, 14)
topTex:SetPoint("TOP")
topTex:SetTexCoord(0, 0.671875, 0, 0.109375)

local bottomTex = frame:CreateTexture(nil, "BACKGROUND")
bottomTex:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame2")
bottomTex:SetSize(230, 20)
bottomTex:SetPoint("BOTTOM")
bottomTex:SetTexCoord(0, 0.671875, 0.59375, 0.75)

local backTex = frame:CreateTexture(nil, "BACKGROUND")
backTex:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame2")
backTex:SetPoint("TOPLEFT", topTex, "BOTTOMLEFT", 0, 0)
backTex:SetPoint("BOTTOMRIGHT", bottomTex, "TOPRIGHT", 0, 0)
backTex:SetTexCoord(0, 0.671875, 0.109375, 0.59375)

local moneyTex = frame:CreateTexture(nil, "BORDER")
moneyTex:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame")
moneyTex:SetSize(121, 33)
moneyTex:SetPoint("TOP", 1, -14)
moneyTex:SetTexCoord(0.10546875, 0.578125, 0.109375, 0.3671875)

local amountText = frame:CreateFontString("CXUI_BuyEmAllText", "BORDER", "GameFontHighlight")
amountText:SetJustifyH("RIGHT")
amountText:SetPoint("RIGHT", moneyTex, "RIGHT", -12, 2)

-- Left/Right nudge arrows.
local leftButton = CreateFrame("Button", "CXUI_BuyEmAllLeftButton", frame)
leftButton:SetSize(16, 16)
leftButton:SetPoint("TOPRIGHT", moneyTex, "TOP", -60, -8)
leftButton:SetNormalTexture("Interface\\MoneyFrame\\Arrow-Left-Up")
leftButton:SetPushedTexture("Interface\\MoneyFrame\\Arrow-Left-Down")
leftButton:SetDisabledTexture("Interface\\MoneyFrame\\Arrow-Left-Disabled")

local rightButton = CreateFrame("Button", "CXUI_BuyEmAllRightButton", frame)
rightButton:SetSize(16, 16)
rightButton:SetPoint("TOPLEFT", moneyTex, "TOP", 63, -8)
rightButton:SetNormalTexture("Interface\\MoneyFrame\\Arrow-Right-Up")
rightButton:SetPushedTexture("Interface\\MoneyFrame\\Arrow-Right-Down")
rightButton:SetDisabledTexture("Interface\\MoneyFrame\\Arrow-Right-Disabled")

-- Okay / Cancel.
local okayButton = CreateFrame("Button", "CXUI_BuyEmAllOkayButton", frame, "UIPanelButtonTemplate")
okayButton:SetSize(78, 24)
okayButton:SetPoint("RIGHT", frame, "BOTTOM", -3, 30)
okayButton:SetText(OKAY or "Okay")

local cancelButton = CreateFrame("Button", "CXUI_BuyEmAllCancelButton", frame, "UIPanelButtonTemplate")
cancelButton:SetSize(78, 24)
cancelButton:SetPoint("LEFT", frame, "BOTTOM", 5, 30)
cancelButton:SetText(CANCEL or "Cancel")

-- Stack / Max (with tooltips).
local stackButton = CreateFrame("Button", "CXUI_BuyEmAllStackButton", frame, "UIPanelButtonTemplate")
stackButton:SetSize(78, 24)
stackButton:SetPoint("BOTTOM", okayButton, "TOP", 0, 2)
stackButton:SetText(L.STACK)
stackButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local maxButton = CreateFrame("Button", "CXUI_BuyEmAllMaxButton", frame, "UIPanelButtonTemplate")
maxButton:SetSize(78, 24)
maxButton:SetPoint("BOTTOM", cancelButton, "TOP", 0, 2)
maxButton:SetText(L.MAX)

-- Currency row (gold/silver/copper, or up to 3 alternate-currency icons).
local currencyFrame = CreateFrame("Frame", "CXUI_BuyEmAllCurrencyFrame", frame)
currencyFrame:SetSize(204, 24)
currencyFrame:SetPoint("TOP", 2, -45)

local currTex, currAmt = {}, {}
local currXOffsets = { 48, 116, 184 }
local amtXOffsets = { -2, 66, 134 }
for i = 1, 3 do
    local tex = currencyFrame:CreateTexture(nil, "ARTWORK")
    tex:SetSize(16, 16)
    tex:SetPoint("LEFT", currXOffsets[i], 0)
    currTex[i] = tex

    local amt = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    amt:SetSize(52, 20)
    amt:SetPoint("LEFT", amtXOffsets[i], 0)
    currAmt[i] = amt
end

local function ClearCurrencyDisplay()
    for i = 1, 3 do
        currTex[i]:SetTexture(nil)
        currAmt[i]:SetText()
    end
end

------------------------------------------------------------
-- Fallback popup for the rare case Blizzard doesn't hand back an item
-- link (so we can't build a proper Max/Stack window at all).
------------------------------------------------------------

BEA.ConfirmNoItemLink = 0
StaticPopupDialogs["CXUI_BUYEMALL_CONFIRM2"] = {
    preferredIndex = 3,
    text = L.CONFIRM,
    button1 = YES,
    button2 = NO,
    OnAccept = function(dialog) BuyMerchantItem(BEA.ConfirmNoItemLink) end,
    timeout = 0,
    hideOnEscape = true,
}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

function BEA:ItemIsUnique(itemIDOrLink)
    if string.find(itemIDOrLink, "|Hitem:") ~= nil then
        itemIDOrLink = tonumber(string.match(itemIDOrLink, "|Hitem:(%d+):"))
    end

    local tooltip = C_TooltipInfo.GetItemByID(itemIDOrLink)
    for _, line in ipairs(tooltip.lines) do
        if line.leftText == "Unique" then
            return true
        end
    end

    return false
end

function BEA:HasBagEquippedInSlot(slotID)
    local inventorySlotId = GetInventorySlotInfo("Bag" .. (slotID - 1) .. "Slot")
    return GetInventoryItemID("player", inventorySlotId) ~= nil
end

function BEA:GetFreeBagSpace(itemID)
    local canFit = 0
    local itemType = GetItemFamily(itemID)
    local stackSize = select(8, GetItemInfo(itemID))

    for currentBag = 0, 4 do
        local freeSpace, bagType = C_Container.GetContainerNumFreeSlots(currentBag)
        if bagType == 0 or (BEA:HasBagEquippedInSlot(currentBag) and (bagType == itemType or bit.band(itemType, bagType) == bagType)) then
            canFit = canFit + (freeSpace * stackSize)

            local totalBagSlots = C_Container.GetContainerNumSlots(currentBag)
            for currentSlot = 1, totalBagSlots do
                local itemInfo = C_Container.GetContainerItemInfo(currentBag, currentSlot)
                if itemInfo ~= nil and itemInfo.itemID == itemID then
                    local itemCount = itemInfo.stackCount or 0
                    canFit = canFit + (stackSize - itemCount)
                end
            end
        end
    end

    return canFit, stackSize
end

------------------------------------------------------------
-- Merchant click hook
------------------------------------------------------------

local origMerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
MerchantItemButton_OnModifiedClick = function(clickFrame, button)
    if not IsEnabled() then
        origMerchantItemButton_OnModifiedClick(clickFrame, button)
        return
    end
    BEA:MerchantItemButton_OnModifiedClick(clickFrame, button)
end

local origMerchantFrame_OnHide = MerchantFrame:GetScript("OnHide")
MerchantFrame:SetScript("OnHide", function(...)
    frame:Hide()
    if origMerchantFrame_OnHide then
        return origMerchantFrame_OnHide(...)
    end
end)

function BEA:MerchantItemButton_OnModifiedClick(clickFrame, button)
    self.itemIndex = clickFrame:GetID()

    if (MerchantFrame.selectedTab == 1)
            and IsShiftKeyDown()
            and not IsControlKeyDown()
            and not (C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(GetMerchantItemLink(self.itemIndex)) and (button == "RightButton"))
            and not ChatFrame1EditBox:HasFocus() then

        self.NPCName = UnitName("npc")
        self.AltCurrencyMode = false
        self.AtVendor = true

        local info = C_MerchantFrame.GetItemInfo(self.itemIndex)
        if not info then return end

        local name = info.name
        local price = info.price
        local quantity = info.stackCount
        local numAvailable = info.numAvailable
        local hasExtendedCostInfo = info.hasExtendedCost

        self.itemName = name
        self.price = price
        self.preset = quantity
        self.available = numAvailable

        self.itemLink = GetMerchantItemLink(self.itemIndex)

        if self.itemLink == nil then
            self.ConfirmNoItemLink = self.itemIndex
            StaticPopup_Show("CXUI_BUYEMALL_CONFIRM2", quantity, self.itemName)
            return
        end

        -- Buying a currency with a currency.
        if strmatch(self.itemLink, "currency") and (self.price <= 0 or self.price == nil) then
            local totalMax = C_CurrencyInfo.GetCurrencyInfoFromLink(self.itemLink).maxQuantity
            self.fit = (totalMax <= 0 and 10000000 or totalMax)
            self.stack = self.preset
            self:AltCurrencyHandling(self.itemIndex, clickFrame)
            return
        end

        if strmatch(self.itemLink, "item") then
            self.itemID = tonumber(strmatch(self.itemLink, "item:(%d+):"))
            local bagMax, stack = self:GetFreeBagSpace(self.itemID)
            self.stack = stack
            self.fit = bagMax
            self.partialFit = self.fit % stack
        elseif strmatch(self.itemLink, "currency") then
            self.stack = self.preset
            local totalMax = C_CurrencyInfo.GetCurrencyInfoFromLink(self.itemLink).maxQuantity
            self.fit = (totalMax == 0 and 10000000 or totalMax - C_CurrencyInfo.GetCurrencyInfoFromLink(self.itemLink).quantity)
            self.partialFit = 0
        end

        if hasExtendedCostInfo == true and (self.price <= 0 or self.price == nil) then
            self:AltCurrencyHandling(self.itemIndex, clickFrame)
            return
        end

        currTex[1]:SetTexture("Interface\\MONEYFRAME\\UI-GoldIcon")
        currTex[2]:SetTexture("Interface\\MONEYFRAME\\UI-SilverIcon")
        currTex[3]:SetTexture("Interface\\MONEYFRAME\\UI-CopperIcon")

        if self.itemID ~= nil and BEA:ItemIsUnique(self.itemLink) then
            self.afford = 1
        elseif self.price <= 0 or self.price == nil then
            self.afford = self.fit
        else
            self.afford = floor(GetMoney() / ceil(self.price / self.preset))
        end

        self.max = min(self.fit, self.afford)
        if numAvailable > -1 then
            self.max = min(self.max, numAvailable)
        end
        if self.max == 0 then
            return
        elseif self.max == 1 then
            MerchantItemButton_OnClick(clickFrame, "LeftButton")
            return
        end

        self.defaultStack = quantity
        self.split = 1

        self:SetStackClick()
        self:Show(clickFrame)
    else
        origMerchantItemButton_OnModifiedClick(clickFrame, button)
    end
end

function BEA:AltCurrencyHandling(itemIndex, clickFrame)
    self.AltCurrencyMode = true

    self.NumAltCurrency = GetMerchantItemCostInfo(itemIndex)

    self.AltCurrTex = {}
    self.AltCurrPrice = {}
    self.AltCurrAfford = {}

    if self.NumAltCurrency <= 0 then
        self.afford = self.fit
    else
        for i = 1, self.NumAltCurrency do
            local altCurrTex, altCurrPrice, altCurrLink = GetMerchantItemCostItem(itemIndex, i)
            self.AltCurrTex[i] = altCurrTex
            self.AltCurrPrice[i] = altCurrPrice

            if strmatch(altCurrLink, "currency") then
                self.AltCurrAfford[i] = floor(C_CurrencyInfo.GetCurrencyInfoFromLink(altCurrLink).quantity / self.AltCurrPrice[i]) * self.preset
            else
                self.AltCurrAfford[i] = floor((GetItemCount(tonumber(strmatch(altCurrLink, "item:(%d+):")), true)) / self.AltCurrPrice[i]) * self.preset
            end
        end
        self.afford = self.AltCurrAfford[1]
    end

    if self.itemID ~= nil and BEA:ItemIsUnique(self.itemLink) then
        self.afford = 1
    elseif self.NumAltCurrency > 1 then
        for i = 2, self.NumAltCurrency do
            self.afford = min(self.afford, self.AltCurrAfford[i] or 999999)
        end
    end

    self.max = min(self.fit, self.afford)

    if self.available > -1 then
        self.max = min(self.max, self.available * self.preset)
    end

    if self.max == 0 then
        return
    elseif self.max == 1 then
        MerchantItemButton_OnClick(clickFrame, "LeftButton")
        return
    end

    self.defaultStack = self.preset
    self.split = self.defaultStack

    self.partialFit = self.fit % self.stack
    self:SetStackClick()

    self.NPCName = UnitName("npc")
    local itemInfo = C_MerchantFrame.GetItemInfo(self.itemIndex)
    self.ItemName = itemInfo and itemInfo.name or nil

    self:Show(clickFrame)
end

function BEA:Show(clickFrame)
    self.typing = false
    leftButton:Disable()
    rightButton:Enable()

    stackButton:Enable()
    if self.max < self.stackClick then
        stackButton:Disable()
    end

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", clickFrame, "TOPLEFT", 0, 0)

    frame:Show()
    self:UpdateDisplay()
end

------------------------------------------------------------
-- Purchasing
------------------------------------------------------------

function BEA:VerifyPurchase(amount)
    amount = amount or self.split

    if self.AltCurrencyMode == true then
        amount = self:AltCurrRounding(amount)
    end

    if amount > 0 then
        self:DoPurchase(amount)
    end
end

-- Purchase loop: BuyMerchantItem only supports buying one stack at a time,
-- so repeated purchases are spaced out on a short timer instead of firing
-- every one in the same frame (which the server would just drop).
local framePurchAmount, frameNumLoops, frameLeftover = 0, 0, 0
local frameItemIndex
local purchaseLoopFrame = CreateFrame("Frame")
local sinceLastUpdate = 0

local function OnPurchaseUpdate(_, elapsed)
    sinceLastUpdate = sinceLastUpdate + elapsed
    if sinceLastUpdate >= 0.5 then
        if frameNumLoops == 0 and frameLeftover == 0 then
            purchaseLoopFrame:SetScript("OnUpdate", nil)
            return
        end
        if frameNumLoops == 0 and frameLeftover ~= 0 then
            BuyMerchantItem(frameItemIndex, frameLeftover)
            frameLeftover = 0
        elseif frameNumLoops > 0 then
            BuyMerchantItem(frameItemIndex, framePurchAmount)
            frameNumLoops = frameNumLoops - 1
        end
        sinceLastUpdate = 0
    end
end

function BEA:DoPurchase(amount)
    frame:Hide()
    local numLoops, purchAmount, leftover

    if strmatch(self.itemLink, "currency") then
        BuyMerchantItem(self.itemIndex, amount)
        return
    end

    if amount <= self.stack then
        purchAmount = amount
        numLoops = 1
        leftover = 0
    else
        purchAmount = self.stack
        numLoops = floor(amount / self.stack)
        if (amount % self.stack) > 0 then
            leftover = amount % self.stack
        else
            leftover = 0
        end
    end

    framePurchAmount = purchAmount
    frameNumLoops = numLoops
    frameLeftover = leftover
    frameItemIndex = self.itemIndex

    purchaseLoopFrame:SetScript("OnUpdate", OnPurchaseUpdate)
end

function BEA:AltCurrRounding(purchase)
    local singleCost = false
    local amount = purchase
    for i = 1, self.NumAltCurrency do
        if self.AltCurrPrice[i] == 1 then
            singleCost = true
        end
    end

    if singleCost and purchase % self.preset ~= 0 then
        amount = purchase + (self.preset - (purchase % self.preset))
    end

    return amount
end

------------------------------------------------------------
-- Display / input
------------------------------------------------------------

function BEA:UpdateDisplay()
    leftButton:Enable()
    rightButton:Enable()
    maxButton:Enable()
    if self.split == self.max then
        rightButton:Disable()
        maxButton:Disable()
    end
    if self.AltCurrencyMode == false and self.split == 1 then
        leftButton:Disable()
    end
    if self.AltCurrencyMode == true and self.split == self.preset then
        leftButton:Disable()
    end

    self:SetStackClick()
    stackButton:Enable()
    if self.max < self.stackClick then
        stackButton:Disable()
    end

    local purchase = self.split

    if self.AltCurrencyMode == false then
        local cost = ceil(purchase * (self.price / self.defaultStack))
        local gold = floor(cost / 10000)
        local silver = floor((cost / 100) % 100)
        local copper = floor(cost % 100)

        currAmt[1]:SetText(gold)
        currAmt[2]:SetText(silver)
        currAmt[3]:SetText(copper)
    elseif #self.AltCurrPrice >= 1 then
        local amount = self:AltCurrRounding(purchase)
        self.AltNumPurchases = amount / self.preset

        currAmt[1]:SetText(self.AltNumPurchases * self.AltCurrPrice[1])
        currTex[1]:SetTexture(self.AltCurrTex[1])
        currAmt[2]:SetText(self.AltNumPurchases * (self.AltCurrPrice[2] or 0))
        currTex[2]:SetTexture(self.AltCurrTex[2])
        if self.AltCurrPrice[2] == nil then currAmt[2]:SetText() end
        currAmt[3]:SetText(self.AltNumPurchases * (self.AltCurrPrice[3] or 0))
        currTex[3]:SetTexture(self.AltCurrTex[3])
        if self.AltCurrPrice[2] == nil then currAmt[3]:SetText() end
    end

    amountText:SetText(self.split)
end

function BEA:SetStackClick()
    local increase = (self.partialFit == 0 and self.stack or self.partialFit) - (self.split % self.stack)
    self.stackClick = self.split + (increase == 0 and self.stack or increase)
end

function BEA:DeStackClick()
    local decrease = tonumber(amountText:GetText())
    if decrease <= self.stack then
        self.split = 1
        self:UpdateDisplay()
    else
        self.split = decrease - self.stack
        self:UpdateDisplay()
    end
end

function BEA:Left_Click()
    if self.AltCurrencyMode == false then
        self.split = self.split - 1
        self:UpdateDisplay()
    else
        self.split = self.split - self.preset
        self:UpdateDisplay()
    end
end

function BEA:Right_Click()
    if self.AltCurrencyMode == false then
        self.split = self.split + 1
        self:UpdateDisplay()
    else
        self.split = self.split + self.preset
        self:UpdateDisplay()
    end
end

leftButton:SetScript("OnClick", function() BEA:Left_Click() end)
rightButton:SetScript("OnClick", function() BEA:Right_Click() end)

okayButton:SetScript("OnClick", function()
    local amount = tonumber(amountText:GetText())
    BEA:VerifyPurchase(amount)
end)

cancelButton:SetScript("OnClick", function()
    frame:Hide()
end)

stackButton:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
        BEA.split = BEA.stackClick
        BEA:UpdateDisplay()
        if stackButton:IsEnabled() then
            BEA:OnEnter(stackButton)
        else
            GameTooltip:Hide()
        end
    elseif button == "RightButton" then
        BEA:DeStackClick()
        BEA:UpdateDisplay()
        if stackButton:IsEnabled() then
            BEA:OnEnter(stackButton)
        else
            GameTooltip:Hide()
        end
    end
end)

maxButton:SetScript("OnClick", function()
    BEA.split = BEA.max
    BEA:UpdateDisplay()
end)

frame:SetScript("OnChar", function(_, text)
    BEA:OnChar(text)
end)

frame:SetScript("OnKeyDown", function(_, key)
    BEA:OnKeyDown(key)
end)

frame:SetScript("OnHide", function()
    BEA:OnHide()
end)

function BEA:OnChar(text)
    if text < "0" or text > "9" then
        return
    end

    if self.typing == false then
        self.typing = true
        self.split = 0
    end

    local input = (self.split * 10) + text

    if input == self.split then
        if self.split == 0 then
            self.split = 1
        end
        self:UpdateDisplay()
        return
    end
    if input <= self.max then
        self.split = input
    elseif input > self.max then
        self.split = self.max
    elseif input <= 0 then
        self.split = 1
    end
    self:UpdateDisplay()
end

function BEA:OnKeyDown(key)
    if key == "BACKSPACE" or key == "DELETE" then
        if self.typing == false or self.split == 1 then
            return
        end

        self.split = floor(self.split / 10)
        if self.split <= 1 then
            self.split = 1
            self.typing = false
        end

        self:UpdateDisplay()
    elseif key == "ENTER" then
        self:VerifyPurchase()
    elseif key == "ESCAPE" then
        frame:Hide()
    elseif key == "LEFT" or key == "DOWN" then
        BEA:Left_Click()
    elseif key == "RIGHT" or key == "UP" then
        BEA:Right_Click()
    elseif key == "PRINTSCREEN" then
        Screenshot()
    end
end

------------------------------------------------------------
-- Tooltips
------------------------------------------------------------

BEA.lines = {
    stack = {
        label = L.STACK_PURCH,
        field = "stackClick",
        { label = L.STACK_SIZE, field = "stack" },
        { label = L.PARTIAL, field = "partialFit" },
    },
    max = {
        label = L.MAX_PURCH,
        field = "max",
        { label = L.AFFORD, field = "afford" },
        { label = L.FIT, field = "fit" },
        {
            label = L.AVAILABLE,
            field = "available",
            Hide = function()
                return BEA.available <= 1
            end,
        },
    },
}

function BEA:OnEnter(hoverFrame)
    local lines = self.lines[hoverFrame == maxButton and "max" or "stack"]

    lines.amount = self[lines.field]
    for _, line in ipairs(lines) do
        line.amount = self[line.field]
    end

    self:CreateTooltip(hoverFrame, lines)
end

function BEA:CreateTooltip(hoverFrame, lines)
    GameTooltip:SetOwner(hoverFrame, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(lines.label .. "|cFFFFFFFF - |r" .. GREEN_FONT_COLOR_CODE .. lines.amount .. "|r")

    for _, line in ipairs(lines) do
        if not (line.Hide and line.Hide()) then
            local color = line.amount == lines.amount and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
            GameTooltip:AddDoubleLine(line.label, line.amount, 1, 1, 1, color.r, color.g, color.b)
        end
    end

    GameTooltip:Show()
end

function BEA:OnLeave()
    GameTooltip:Hide()
end

stackButton:SetScript("OnEnter", function() BEA:OnEnter(stackButton) end)
stackButton:SetScript("OnLeave", function() BEA:OnLeave() end)
maxButton:SetScript("OnEnter", function() BEA:OnEnter(maxButton) end)
maxButton:SetScript("OnLeave", function() BEA:OnLeave() end)

function BEA:OnHide()
    ClearCurrencyDisplay()
end

ClearCurrencyDisplay()
