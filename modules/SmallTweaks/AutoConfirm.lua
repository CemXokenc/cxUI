local addonName, ns = ...

-- ===========================================================================
-- MODULE: SMALL TWEAKS -> AUTO CONFIRM
--
-- Auto-accepts specific StaticPopup confirmation dialogs so the player
-- doesn't have to manually click "Yes"/"Accept" every time:
--   - CONFIRM_PURCHASE_TOKEN_ITEM        (confirm purchase of an item bought
--                                          with a currency/token, e.g. a
--                                          "100 Field Accolade" vendor item)
--   - CONFIRM_MAIL_ITEM_UNREFUNDABLE     (warning that an attached item will
--                                          become non-refundable once the
--                                          mail is sent)
-- ===========================================================================

-- `which` keys that should be auto-accepted when the feature is enabled.
local WHITELIST = {
    CONFIRM_PURCHASE_TOKEN_ITEM    = true,
    CONFIRM_MAIL_ITEM_UNREFUNDABLE = true,
}

local function IsAutoConfirmEnabled()
    return CXUI_DB and CXUI_DB.autoConfirm
end

local function TryAutoConfirm(which)
    if not IsAutoConfirmEnabled() then return end
    if not WHITELIST[which] then return end

    local i = 1
    while true do
        local dialog = _G["StaticPopup" .. i]
        if not dialog then break end
        if dialog.which == which and dialog:IsShown() then
            -- Simulate a click on button1 ("Accept"/"Yes") the same way the
            -- player would - runs OnAccept with the correct data/data2 and
            -- closes the dialog through Blizzard's own code path.
            StaticPopup_OnClick(dialog, 1)
            break
        end
        i = i + 1
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    hooksecurefunc("StaticPopup_Show", function(which)
        TryAutoConfirm(which)
    end)
end)