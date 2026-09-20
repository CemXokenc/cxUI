local addonName, ns = ...

-- ===========================================================================
-- MODULE: VENDOR & MAIL
-- Merchant window, purchases and the mailbox. One file per feature:
--   ExpandVendorWindow, BuyEmAll, AutoConfirm       (vendor / purchases)
--   RememberRecipient, FavoriteContacts             (mailbox)
-- Shared helper: waiting for the load-on-demand Blizzard mail UI.
-- ===========================================================================

local VM = ns:NewModule("VendorMail", {
    name  = "Vendor & Mail",
    desc  = "Vendor window, purchases and mailbox helpers",
    order = 8,
})

-- Calls fn() every time the mailbox opens (MAIL_SHOW) and once when the mail
-- UI finishes loading. Listens on a frame owned by feature F. The
-- ADDON_LOADED listener is dropped as soon as MailFrame exists.
function VM.WatchMail(F, onMailShow, onMailClosed)
    local ev = F:NewEventFrame()
    ev:RegisterEvent("MAIL_SHOW")
    ev:RegisterEvent("MAIL_CLOSED")
    if not _G.SendMailFrame_SendMail then ev:RegisterEvent("ADDON_LOADED") end
    ev:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 ~= "Blizzard_MailFrame" then return end
            self:UnregisterEvent("ADDON_LOADED")
            onMailShow()
        elseif event == "MAIL_SHOW" then
            onMailShow()
        elseif onMailClosed then
            onMailClosed()
        end
    end)
end
