local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- MODULE: SMALL TWEAKS -> EXPAND VENDOR WINDOW
--
-- Expands the merchant (vendor) item grid from Blizzard's default
-- 2 columns x 5 rows (10 items per page) to 5 columns x 10 rows
-- (50 items per page), so far fewer "next page" clicks are needed on
-- vendors with large inventories.
--
-- Ported as closely as possible from Krowi_ExtendedVendorUI's own
-- MerchantItemsContainer.lua + MerchantFrame.lua (grid, frame-resize, and
-- backdrop re-anchor logic), just with a fixed 5x10 layout and a single
-- on/off switch instead of Krowi's own options system, filters, search
-- box, bulk purchase, and token banner (none of that is needed here).
--
-- IMPORTANT: Blizzard reuses the exact same MerchantItem1..N frames for
-- BOTH the sell tab and the Buyback tab (just filled with different data
-- depending on which tab is selected), and has a SEPARATE, single
-- "MerchantBuyBackItem" frame for the sell tab's quick-rebuy-last-sold-item
-- shortcut -- that one needs its own re-anchor too, or it's left sitting
-- wherever Blizzard's default (now-wrong) position puts it.
-- ---------------------------------------------------------------------------

local DEFAULT_NUM_COLUMNS = 2
local DEFAULT_NUM_ROWS    = 5
local NUM_COLUMNS         = 5
local NUM_ROWS            = 10

local BUYBACK_NUM_COLUMNS = 2
local BUYBACK_NUM_ROWS    = 6

local FIRST_OFFSET_X    = 11
local FIRST_OFFSET_Y    = -69
local OFFSET_X          = 12
local OFFSET_MERCHANT_Y = 8
local OFFSET_BUYBACK_Y  = 15

local itemWidth, itemHeight = MerchantItem1:GetSize()
local originalWidth, originalHeight = MerchantFrame:GetSize()

local function IsEnabled()
    return CXUI_DB and CXUI_DB.expandVendorWindow
end

------------------------------------------------------------
-- Item slot frames
-- Blizzard's XML pre-creates MerchantItem1-12 (2x6 -- enough for its own
-- default Buyback grid). Anything beyond that is created on demand from
-- the same template, exactly like the built-in slots, so Blizzard's own
-- update code (which just indexes _G["MerchantItem"..i]) keeps working
-- unmodified.
------------------------------------------------------------

local itemSlotTable = {}
for i = 1, 12 do
    itemSlotTable[i] = _G["MerchantItem" .. i]
end

local function GetItemSlot(index)
    if itemSlotTable[index] then return itemSlotTable[index] end
    local frame = CreateFrame("Frame", "MerchantItem" .. index, MerchantFrame, "MerchantItemTemplate")
    itemSlotTable[index] = frame
    return frame
end

-- Pre-create every slot the expanded grid could ever need, up front and
-- out of combat, instead of creating frames the first time a vendor with
-- enough items happens to be opened.
for i = 1, NUM_COLUMNS * NUM_ROWS do
    GetItemSlot(i):Hide()
end

------------------------------------------------------------
-- Grid drawing (shared by both tabs) -- unconditional, exactly like
-- Krowi's own DrawItemSlots: every slot in the numRows x numColumns grid
-- gets positioned and shown, and everything past that is hidden. Blizzard
-- itself is responsible for populating/clearing each slot's item data;
-- this only ever handles where the slot sits on screen.
------------------------------------------------------------

local function DrawItemSlot(index, row, column, offsetY)
    local slot = GetItemSlot(index)
    local x = FIRST_OFFSET_X + (column - 1) * (OFFSET_X + itemWidth)
    local y = FIRST_OFFSET_Y - (row - 1) * (offsetY + itemHeight)
    slot:ClearAllPoints()
    slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", x, y)
    slot:Show()
end

-- Row-major fill (left to right, then next row down), matching the order
-- Blizzard's own vendor/buyback item lists are already in.
local function DrawGrid(numColumns, numRows, offsetY)
    for row = 1, numRows do
        for column = 1, numColumns do
            local index = (row - 1) * numColumns + column
            DrawItemSlot(index, row, column, offsetY)
        end
    end
    for i = numColumns * numRows + 1, #itemSlotTable do
        itemSlotTable[i]:Hide()
    end
end

local function SetMerchantFrameSize(numColumns, numRows)
    local extraColumns = numColumns - DEFAULT_NUM_COLUMNS
    local extraRows = numRows - DEFAULT_NUM_ROWS
    local width = originalWidth + extraColumns * (OFFSET_X + itemWidth)
    local height = originalHeight + extraRows * (OFFSET_MERCHANT_Y + itemHeight)
    MerchantFrame:SetSize(width, height)
end

------------------------------------------------------------
-- Backdrop / inset chrome
-- Blizzard's dark backdrop behind the item icons (MerchantFrameInset) and
-- the money/repair button row are anchored with fixed offsets that don't
-- follow the frame when it's made wider/taller, leaving bare unbordered
-- black space and misplaced buttons once the grid is expanded. Re-anchor
-- them to the live frame edges instead, so they always match -- whether
-- the tweak is currently on or off. Ported from Krowi_ExtendedVendorUI.
------------------------------------------------------------

MerchantMoneyInset:ClearAllPoints()
MerchantMoneyInset:SetPoint("BOTTOMRIGHT", MerchantFrame, -6, 8)
MerchantMoneyInset:SetPoint("LEFT", MerchantFrame, 4, 0)
MerchantMoneyInset:SetHeight(22)

local buttonsInset = CreateFrame("Frame", "CXUI_MerchantButtonsInset", MerchantFrame, "InsetFrameTemplate")
buttonsInset:SetPoint("BOTTOMLEFT", MerchantMoneyInset, "TOPLEFT", 0, 4)
buttonsInset:SetSize(185, 52)

local buybackInset = CreateFrame("Frame", "CXUI_MerchantBuybackInset", MerchantFrame, "InsetFrameTemplate")
buybackInset:SetPoint("TOPLEFT", buttonsInset, "TOPRIGHT", 4, 0)
buybackInset:SetPoint("BOTTOMLEFT", buttonsInset, "BOTTOMRIGHT", 4, 0)
buybackInset:SetWidth(149)

local function UpdateRepairButtons()
    MerchantRepairItemButton:ClearAllPoints()
    MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -8, 0)
    MerchantRepairAllButton:ClearAllPoints()
    MerchantRepairAllButton:SetPoint("LEFT", buttonsInset, 52, -1)
    MerchantGuildBankRepairButton:ClearAllPoints()
    MerchantGuildBankRepairButton:SetPoint("LEFT", MerchantRepairAllButton, "RIGHT", 8, 0)
    if MerchantSellAllJunkButton then
        MerchantSellAllJunkButton:ClearAllPoints()
        MerchantSellAllJunkButton:SetPoint("LEFT", MerchantGuildBankRepairButton, "RIGHT", 8, 0)
    end
end
hooksecurefunc("MerchantFrame_UpdateRepairButtons", UpdateRepairButtons)

MerchantPrevPageButton:ClearAllPoints()
MerchantPrevPageButton:SetPoint("BOTTOMLEFT", MerchantFrameInset, 5, 2)
MerchantNextPageButton:ClearAllPoints()
MerchantNextPageButton:SetPoint("BOTTOMRIGHT", MerchantFrameInset, -3, 2)
MerchantPageText:ClearAllPoints()
MerchantPageText:SetPoint("BOTTOM", buttonsInset, "TOP", 0, 17)

if BuybackBG then
    BuybackBG:ClearAllPoints()
    BuybackBG:SetPoint("TOPLEFT", MerchantFrameInset)
    BuybackBG:SetPoint("BOTTOMRIGHT", MerchantFrameInset)
end

-- Blizzard's own "quick rebuy the item you just sold" shortcut. It's a
-- single separate frame (not part of itemSlotTable), shown only on the
-- sell tab, normally anchored at a fixed spot that no longer lines up
-- once the window is resized -- re-anchor it into the same buyback inset
-- area Krowi uses, and toggle it with the tab exactly like Krowi does.
local function DrawMerchantBuyBackItem(show)
    if not MerchantBuyBackItem then return end
    if show then
        MerchantBuyBackItem:ClearAllPoints()
        MerchantBuyBackItem:SetPoint("LEFT", buybackInset, 7, 0)
        MerchantBuyBackItem:Show()
    else
        MerchantBuyBackItem:Hide()
    end
end

------------------------------------------------------------
-- Tab hooks -- each one draws/hides ITS OWN grid on top of whatever the
-- other tab last left behind, so nothing from the previous tab lingers.
------------------------------------------------------------

local function ApplySellTabLayout()
    if IsEnabled() then
        MERCHANT_ITEMS_PER_PAGE = NUM_COLUMNS * NUM_ROWS
        SetMerchantFrameSize(NUM_COLUMNS, NUM_ROWS)
        DrawGrid(NUM_COLUMNS, NUM_ROWS, OFFSET_MERCHANT_Y)
    else
        MERCHANT_ITEMS_PER_PAGE = DEFAULT_NUM_COLUMNS * DEFAULT_NUM_ROWS
        SetMerchantFrameSize(DEFAULT_NUM_COLUMNS, DEFAULT_NUM_ROWS)
        DrawGrid(DEFAULT_NUM_COLUMNS, DEFAULT_NUM_ROWS, OFFSET_MERCHANT_Y)
    end

    MerchantFrameInset:ClearAllPoints()
    MerchantFrameInset:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT")
    MerchantFrameInset:SetPoint("RIGHT", MerchantFrame, "RIGHT", -6, 0)
    MerchantFrameInset:SetPoint("BOTTOM", buttonsInset, "TOP", 0, 4)
    buttonsInset:Show()
    buybackInset:Show()
    DrawMerchantBuyBackItem(true)
end
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", ApplySellTabLayout)

local function ApplyBuybackTabLayout()
    -- Buyback tab always uses Blizzard's own default 2x6 grid and the
    -- window's original size -- this tweak only concerns the sell side.
    MerchantFrame:SetSize(originalWidth, originalHeight)
    DrawGrid(BUYBACK_NUM_COLUMNS, BUYBACK_NUM_ROWS, OFFSET_BUYBACK_Y)

    MerchantFrameInset:ClearAllPoints()
    MerchantFrameInset:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT")
    MerchantFrameInset:SetPoint("RIGHT", MerchantFrame, "RIGHT", -6, 0)
    MerchantFrameInset:SetPoint("BOTTOM", MerchantMoneyInset, "TOP", 0, 3)
    buttonsInset:Hide()
    buybackInset:Hide()
    DrawMerchantBuyBackItem(false)
end
hooksecurefunc("MerchantFrame_UpdateBuybackInfo", ApplyBuybackTabLayout)

------------------------------------------------------------
-- MERCHANT_ITEMS_PER_PAGE has to already be correct *before* Blizzard's own
-- MerchantFrame_UpdateMerchantInfo runs (it decides how many items to
-- display this pass), so set it once as soon as saved settings are ready --
-- toggling the checkbox mid-session still requires a UI reload to fully
-- take effect for that reason.
------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    MERCHANT_ITEMS_PER_PAGE = IsEnabled() and (NUM_COLUMNS * NUM_ROWS) or (DEFAULT_NUM_COLUMNS * DEFAULT_NUM_ROWS)
    self:UnregisterEvent("ADDON_LOADED")
end)